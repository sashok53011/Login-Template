/// Shared helpers for the /api/ai-config routes.
///
/// IMPORTANT: PocketBase executes route handlers in an isolated context, so a
/// handler cannot see the top-level scope of the file that registered it
/// (`ReferenceError: <name> is not defined`). Everything shared therefore lives
/// in this module and is pulled in with require() from *inside* each handler.
///
/// Storage layout:
///   <pb_data>/ai-config/catalogue.json     provider catalogue
///   <pb_data>/ai-config/<userId>.json      one file per user: enable flags
///
/// The catalogue holds two kinds of entry:
///
///   origin: "admin"  added by a superuser — every user sees it
///   origin: "user"   proposed by a user — only its author and the superuser
///                    see it, until an administrator publishes it as "admin"
///
/// A regular user can therefore add a provider without being able to impose it
/// on everyone: it is reported to the administrator together with the author's
/// name, and every definition travels without secrets — API keys stay on the
/// device in flutter_secure_storage.

const CATALOGUE_VERSION = 2;

const STATUS_ACTIVE = "active";
const STATUS_DEAD = "dead";

const ORIGIN_ADMIN = "admin";
const ORIGIN_USER = "user";

/// Model of the ids: they end up in file names and in URLs.
const ID_PATTERN = /[^A-Za-z0-9_.-]/g;

function configDir() {
  const override = $os.getenv("PB_AI_CONFIG_DIR");
  if (override) {
    return override;
  }
  // PocketBase runs with its own directory as the working directory
  // (systemd WorkingDirectory=...), so this resolves to <pb_dir>/pb_data.
  return $os.getwd() + "/pb_data/ai-config";
}

function cataloguePath() {
  return configDir() + "/catalogue.json";
}

function flagsPath(userId) {
  return configDir() + "/" + safeId(userId) + ".json";
}

function safeId(value) {
  return asText(value).replace(ID_PATTERN, "_").slice(0, 64);
}

function fileExists(path) {
  try {
    $os.stat(path);
    return true;
  } catch (err) {
    return false;
  }
}

function readJson(path) {
  if (!fileExists(path)) {
    return null;
  }
  try {
    return JSON.parse(toString($os.readFile(path)));
  } catch (err) {
    $app.logger().warn("ai-config: unreadable file", "path", path, "error", err);
    return null;
  }
}

function writeJson(path, value) {
  const dir = configDir();
  try {
    $os.mkdirAll(dir, 0o755);
  } catch (err) {
    // already exists
  }
  $os.writeFile(path, JSON.stringify(value, null, 2), 0o600);
}

function asText(value) {
  return typeof value === "string" ? value : "";
}

function asInt(value) {
  const n = typeof value === "number" ? value : parseInt(value, 10);
  return isNaN(n) || n < 0 ? 0 : Math.floor(n);
}

function asStatus(value) {
  return value === STATUS_DEAD ? STATUS_DEAD : STATUS_ACTIVE;
}

function asOrigin(value) {
  return value === ORIGIN_USER ? ORIGIN_USER : ORIGIN_ADMIN;
}

/// Keeps only known, non-secret fields. `api_key` and anything unknown are
/// dropped, so a hand-written request cannot smuggle a secret into a file.
function sanitize(raw) {
  if (!raw || typeof raw !== "object") {
    return null;
  }

  const provider = {
    id: safeId(raw.id),
    name: asText(raw.name).slice(0, 120),
    url: asText(raw.url).slice(0, 300),
    model: asText(raw.model).slice(0, 200),
    fallbackPriority: asInt(raw.fallbackPriority),
    loginUrl: asText(raw.loginUrl).slice(0, 300),
    getApiKeyUrl: asText(raw.getApiKeyUrl).slice(0, 300),
    logoUrl: asText(raw.logoUrl).slice(0, 300),
    logoAsset: asText(raw.logoAsset).slice(0, 60),
    status: asStatus(raw.status),
    origin: asOrigin(raw.origin),
    authorId: asText(raw.authorId).slice(0, 64),
    authorName: asText(raw.authorName).slice(0, 120),
    createdAt: asText(raw.createdAt),
  };

  if (!provider.id || !provider.name) {
    return null;
  }

  return provider;
}

function sortProviders(list) {
  list.sort(function (a, b) {
    if (a.fallbackPriority !== b.fallbackPriority) {
      return a.fallbackPriority - b.fallbackPriority;
    }
    return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
  });
  return list;
}

// --------------------------------------------------------------- catalogue

function emptyCatalogue() {
  return { version: CATALOGUE_VERSION, updated: "", providers: [] };
}

function readCatalogue() {
  const parsed = readJson(cataloguePath());
  if (!parsed || !Array.isArray(parsed.providers)) {
    return emptyCatalogue();
  }

  const providers = [];
  const seen = {};
  for (const raw of parsed.providers) {
    const provider = sanitize(raw);
    if (provider && !seen[provider.id]) {
      seen[provider.id] = true;
      providers.push(provider);
    }
  }

  return {
    version: CATALOGUE_VERSION,
    updated: asText(parsed.updated),
    providers: sortProviders(providers),
  };
}

/// Replaces the catalogue. Superuser only — enforced by the route.
function writeCatalogueDoc(providers) {
  const doc = {
    version: CATALOGUE_VERSION,
    updated: new Date().toISOString(),
    providers: sortProviders(providers),
  };
  writeJson(cataloguePath(), doc);
  return doc;
}

function writeCatalogue(incoming, actor) {
  const current = readCatalogue();
  const currentById = {};
  for (const provider of current.providers) {
    currentById[provider.id] = provider;
  }

  const rawProviders =
    incoming && Array.isArray(incoming.providers) ? incoming.providers : [];

  const providers = [];
  const seen = {};
  for (const raw of rawProviders) {
    const provider = sanitize(raw);
    if (!provider || seen[provider.id]) {
      continue;
    }
    seen[provider.id] = true;

    // The administrator's client never receives the internal author id, so it
    // is restored here from what is already stored. Publishing an entry clears
    // the author mark.
    const existing = currentById[provider.id];
    if (existing) {
      if (provider.origin === ORIGIN_USER) {
        provider.authorId = existing.authorId || provider.authorId;
        provider.authorName = existing.authorName || provider.authorName;
        provider.createdAt = existing.createdAt || provider.createdAt;
      } else {
        provider.authorId = "";
        provider.authorName = "";
      }
    }

    providers.push(provider);
  }

  // Whatever is gone compared to what was stored goes to the bin.
  const removed = [];
  for (const provider of current.providers) {
    if (!seen[provider.id]) {
      removed.push(provider);
    }
  }

  writeCatalogueDoc(providers);
  pushToTrash(removed, actor);

  return readCatalogue();
}

// --------------------------------------------------------------- the bin

/// How many removed providers are kept. The oldest fall off the end.
const TRASH_LIMIT = 200;

function trashPath() {
  return configDir() + "/trash.json";
}

/// Newest first.
function readTrash() {
  const parsed = readJson(trashPath());
  if (!parsed || !Array.isArray(parsed.items)) {
    return [];
  }

  const items = [];
  for (const item of parsed.items) {
    if (item && item.provider && item.provider.id) {
      items.push(item);
    }
  }
  return items;
}

function writeTrash(items) {
  const capped = items.slice(0, TRASH_LIMIT);
  writeJson(trashPath(), {
    version: CATALOGUE_VERSION,
    updated: new Date().toISOString(),
    items: capped,
  });
  return capped;
}

/// Moves removed providers into the bin. An id can only sit there once, so
/// deleting the same provider again just refreshes its record.
function pushToTrash(providers, actor) {
  if (!providers || !providers.length) {
    return readTrash();
  }

  const ids = {};
  for (const provider of providers) {
    ids[provider.id] = true;
  }

  const kept = [];
  for (const item of readTrash()) {
    if (!ids[item.provider.id]) {
      kept.push(item);
    }
  }

  const now = new Date().toISOString();
  const fresh = [];
  for (const provider of providers) {
    fresh.push({
      provider: provider,
      deletedAt: now,
      deletedBy: asText(actor && actor.id),
      deletedByName: asText(actor && actor.name),
      source: provider.origin === ORIGIN_USER ? "proposal" : "admin",
    });
  }

  return writeTrash(fresh.concat(kept));
}

/// Puts a binned provider back under the same id and marks it working again:
/// restoring something means we consider it alive.
function restoreFromTrash(id) {
  const target = safeId(id);

  const items = readTrash();
  let entry = null;
  const rest = [];
  for (const item of items) {
    if (!entry && item.provider.id === target) {
      entry = item;
      continue;
    }
    rest.push(item);
  }

  if (!entry) {
    return { restored: false, reason: "В корзине такой записи нет." };
  }

  writeTrash(rest);

  const catalogue = readCatalogue();
  for (const provider of catalogue.providers) {
    if (provider.id === target) {
      return {
        restored: false,
        reason: "Провайдер уже есть в каталоге — запись убрана из корзины.",
      };
    }
  }

  const provider = sanitize(entry.provider);
  if (!provider) {
    return { restored: false, reason: "Запись в корзине повреждена." };
  }
  provider.status = STATUS_ACTIVE;

  writeCatalogueDoc(catalogue.providers.concat([provider]));
  return { restored: true, provider: provider };
}

/// Drops one entry from the bin for good.
function purgeTrash(id) {
  const target = safeId(id);
  const items = readTrash();

  const rest = [];
  for (const item of items) {
    if (item.provider.id !== target) {
      rest.push(item);
    }
  }

  writeTrash(rest);
  return { removed: items.length - rest.length };
}

function purgeAllTrash() {
  const removed = readTrash().length;
  writeTrash([]);
  return { removed: removed };
}

// ------------------------------------------------------------- user flags

function readFlags(userId) {
  const parsed = readJson(flagsPath(userId));
  if (!parsed) {
    return {};
  }

  const flags = {};

  if (parsed.enabled && typeof parsed.enabled === "object") {
    for (const id of Object.keys(parsed.enabled)) {
      flags[id] = parsed.enabled[id] === true;
    }
    return flags;
  }

  // Previous format: the file held whole provider definitions.
  if (Array.isArray(parsed.providers)) {
    for (const item of parsed.providers) {
      if (item && typeof item.id === "string") {
        flags[item.id] = item.enabled === true;
      }
    }
  }

  return flags;
}

function writeFlags(userId, flags) {
  const doc = {
    version: CATALOGUE_VERSION,
    updated: new Date().toISOString(),
    enabled: flags || {},
  };
  writeJson(flagsPath(userId), doc);
  return doc;
}

function clearFlags(userId) {
  const path = flagsPath(userId);
  if (fileExists(path)) {
    $os.remove(path);
  }
  return { version: CATALOGUE_VERSION, updated: "", enabled: {} };
}

// ------------------------------------------------------- regular user write

/// True when a regular user is allowed to change the definition itself.
function isOwnProposal(provider, userId) {
  return (
    provider.origin === ORIGIN_USER &&
    asText(provider.authorId) === asText(userId)
  );
}

/// Applies what a regular user is allowed to change:
///
/// * the enable flags of any entry they can see;
/// * a brand new provider — stored as their own proposal, reported to the
///   administrator with the author's name and never imposed on other users;
/// * edits and deletions of their own proposals.
///
/// Everything else (an administrator's entry, another user's proposal, any
/// secret) is ignored.
function applyUserWrite(userId, userName, incoming) {
  const catalogue = readCatalogue();

  const byId = {};
  for (const provider of catalogue.providers) {
    byId[provider.id] = provider;
  }

  const rawProviders =
    incoming && Array.isArray(incoming.providers) ? incoming.providers : [];

  const kept = [];
  const seen = {};
  const flags = {};

  for (const raw of rawProviders) {
    if (!raw || typeof raw !== "object") {
      continue;
    }

    const id = safeId(raw.id);
    if (!id || seen[id]) {
      continue;
    }
    seen[id] = true;

    const existing = byId[id];

    if (!existing) {
      // A new provider proposed by this user. It needs to be usable.
      const proposal = sanitize(raw);
      if (!proposal || !proposal.url || !proposal.model) {
        continue;
      }
      proposal.origin = ORIGIN_USER;
      proposal.authorId = userId;
      proposal.authorName = userName;
      proposal.createdAt = new Date().toISOString();
      proposal.status = STATUS_ACTIVE;
      kept.push(proposal);
      flags[id] = raw.enabled !== false;
      continue;
    }

    if (isOwnProposal(existing, userId)) {
      const updated = sanitize(raw);
      if (updated) {
        updated.origin = ORIGIN_USER;
        updated.authorId = userId;
        updated.authorName = userName;
        updated.createdAt = existing.createdAt;
        kept.push(updated);
      } else {
        kept.push(existing);
      }
      flags[id] = raw.enabled === true;
      continue;
    }

    // An administrator's entry, or somebody else's: only the flag changes.
    kept.push(existing);
    flags[id] = raw.enabled === true;
  }

  // Whatever the user did not send back.
  const removed = [];
  for (const provider of catalogue.providers) {
    if (seen[provider.id]) {
      continue;
    }
    if (isOwnProposal(provider, userId)) {
      removed.push(provider); // the user deleted their own proposal
      continue;
    }
    kept.push(provider);
  }

  writeCatalogueDoc(kept);
  pushToTrash(removed, { id: userId, name: userName });
  writeFlags(userId, flags);
  return { catalogue: readCatalogue(), flags: flags };
}

// ------------------------------------------------------------------ merge

/// The catalogue as the caller is allowed to see it.
///
/// `canEdit` tells the client whether it may change definitions — only a
/// PocketBase superuser may.
function viewFor(flags, canEdit, userId) {
  const catalogue = readCatalogue();
  const viewer = asText(userId);

  const providers = [];
  for (const provider of catalogue.providers) {
    const isEnabled = flags[provider.id] === true;

    // A regular user sees the administrator's entries plus everything they
    // proposed themselves.
    if (!canEdit && provider.origin === ORIGIN_USER && provider.authorId !== viewer) {
      continue;
    }

    // A provider the administrator marked as dead disappears from a regular
    // user's list — but only while that user has it switched off. An entry
    // that is switched on is never touched, and the administrator always sees
    // everything so the mark can be undone.
    if (!canEdit && provider.status === STATUS_DEAD && !isEnabled) {
      continue;
    }

    providers.push({
      id: provider.id,
      name: provider.name,
      enabled: isEnabled,
      url: provider.url,
      model: provider.model,
      fallbackPriority: provider.fallbackPriority,
      loginUrl: provider.loginUrl,
      getApiKeyUrl: provider.getApiKeyUrl,
      logoUrl: provider.logoUrl,
      logoAsset: provider.logoAsset,
      status: provider.status,
      origin: provider.origin,
      authorName: provider.authorName,
      // Lets the app decide whether the entry may be edited or deleted.
      mine: provider.origin === ORIGIN_USER && provider.authorId === viewer,
    });
  }

  return {
    version: CATALOGUE_VERSION,
    updated: catalogue.updated,
    canEdit: canEdit === true,
    providers: sortProviders(providers),
  };
}

function meta(userId, isSuperuser) {
  const catalogue = readCatalogue();
  let mine = 0;
  let proposals = 0;
  for (const provider of catalogue.providers) {
    if (provider.origin === ORIGIN_USER) {
      proposals++;
      if (provider.authorId === asText(userId)) {
        mine++;
      }
    }
  }

  return {
    dir: configDir(),
    catalogue: cataloguePath(),
    catalogueExists: fileExists(cataloguePath()),
    catalogueCount: catalogue.providers.length,
    proposalCount: proposals,
    myProposalCount: mine,
    userFile: userId ? flagsPath(userId) : "",
    userFileExists: userId ? fileExists(flagsPath(userId)) : false,
    isSuperuser: isSuperuser === true,
  };
}

module.exports = {
  CATALOGUE_VERSION: CATALOGUE_VERSION,
  STATUS_ACTIVE: STATUS_ACTIVE,
  STATUS_DEAD: STATUS_DEAD,
  ORIGIN_ADMIN: ORIGIN_ADMIN,
  ORIGIN_USER: ORIGIN_USER,
  configDir: configDir,
  cataloguePath: cataloguePath,
  flagsPath: flagsPath,
  readCatalogue: readCatalogue,
  writeCatalogue: writeCatalogue,
  applyUserWrite: applyUserWrite,
  readTrash: readTrash,
  pushToTrash: pushToTrash,
  restoreFromTrash: restoreFromTrash,
  purgeTrash: purgeTrash,
  purgeAllTrash: purgeAllTrash,
  readFlags: readFlags,
  writeFlags: writeFlags,
  clearFlags: clearFlags,
  emptyCatalogue: emptyCatalogue,
  viewFor: viewFor,
  meta: meta,
  sortProviders: sortProviders,
};
