/// Shared helpers for the /api/ai-config routes.
///
/// IMPORTANT: PocketBase executes route handlers in an isolated context, so a
/// handler cannot see the top-level scope of the file that registered it
/// (`ReferenceError: <name> is not defined`). Everything shared therefore lives
/// in this module and is pulled in with require() from *inside* each handler.
///
/// Storage layout:
///   <pb_data>/ai-config/catalogue.json     the provider catalogue (superuser)
///   <pb_data>/ai-config/<userId>.json      one file per user: enable flags
///
/// The catalogue is the only place provider definitions live. It is written
/// exclusively by a PocketBase superuser. A regular user's file holds nothing
/// but which catalogue entries they switched on, so a user can never invent or
/// rewrite a provider. API keys are not stored here at all — they stay on the
/// device in flutter_secure_storage.

const CATALOGUE_VERSION = 2;

const STATUS_ACTIVE = "active";
const STATUS_DEAD = "dead";

/// Resolves the directory holding the catalogue and the per-user files.
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
  return configDir() + "/" + userId + ".json";
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

/// Keeps only known, non-secret fields. Anything else (notably `api_key`)
/// is dropped, so a hand-written request cannot smuggle a secret into a file.
function sanitize(raw) {
  if (!raw || typeof raw !== "object") {
    return null;
  }

  const provider = {
    id: asText(raw.id),
    name: asText(raw.name),
    url: asText(raw.url),
    model: asText(raw.model),
    fallbackPriority: asInt(raw.fallbackPriority),
    loginUrl: asText(raw.loginUrl),
    getApiKeyUrl: asText(raw.getApiKeyUrl),
    logoUrl: asText(raw.logoUrl),
    logoAsset: asText(raw.logoAsset),
    status: asStatus(raw.status),
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
function writeCatalogue(incoming) {
  const rawProviders =
    incoming && Array.isArray(incoming.providers) ? incoming.providers : [];

  const providers = [];
  const seen = {};
  for (const raw of rawProviders) {
    const provider = sanitize(raw);
    if (provider && !seen[provider.id]) {
      seen[provider.id] = true;
      providers.push(provider);
    }
  }

  const doc = {
    version: CATALOGUE_VERSION,
    updated: new Date().toISOString(),
    providers: sortProviders(providers),
  };

  writeJson(cataloguePath(), doc);
  return doc;
}

// ------------------------------------------------------------- user flags

/// Reads the enable flags of a user.
///
/// Understands the previous format too, where the file held whole provider
/// definitions: only their `enabled` value is taken from it.
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

  if (Array.isArray(parsed.providers)) {
    for (const item of parsed.providers) {
      if (item && typeof item.id === "string") {
        flags[item.id] = item.enabled === true;
      }
    }
  }

  return flags;
}

/// Stores the enable flags of a user. Ids absent from the catalogue are
/// ignored, and nothing else about a provider can be changed this way.
function writeFlags(userId, incoming, catalogue) {
  const known = {};
  for (const provider of catalogue.providers) {
    known[provider.id] = true;
  }

  const flags = {};
  const rawProviders =
    incoming && Array.isArray(incoming.providers) ? incoming.providers : [];

  for (const raw of rawProviders) {
    if (!raw || typeof raw !== "object") {
      continue;
    }
    const id = asText(raw.id);
    if (id && known[id]) {
      flags[id] = raw.enabled === true;
    }
  }

  const doc = {
    version: CATALOGUE_VERSION,
    updated: new Date().toISOString(),
    enabled: flags,
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

// ------------------------------------------------------------------ merge

/// The catalogue as the caller is allowed to see it: definitions from the
/// catalogue, `enabled` from the caller's own flags.
///
/// `canEdit` tells the client whether it may change the definitions — only a
/// PocketBase superuser may.
function viewFor(flags, canEdit) {
  const catalogue = readCatalogue();

  const providers = [];
  for (const provider of catalogue.providers) {
    const isEnabled = flags[provider.id] === true;

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
  return {
    dir: configDir(),
    catalogue: cataloguePath(),
    catalogueExists: fileExists(cataloguePath()),
    catalogueCount: catalogue.providers.length,
    userFile: userId ? flagsPath(userId) : "",
    userFileExists: userId ? fileExists(flagsPath(userId)) : false,
    isSuperuser: isSuperuser === true,
  };
}

module.exports = {
  CATALOGUE_VERSION: CATALOGUE_VERSION,
  STATUS_ACTIVE: STATUS_ACTIVE,
  STATUS_DEAD: STATUS_DEAD,
  configDir: configDir,
  cataloguePath: cataloguePath,
  flagsPath: flagsPath,
  readCatalogue: readCatalogue,
  writeCatalogue: writeCatalogue,
  readFlags: readFlags,
  writeFlags: writeFlags,
  clearFlags: clearFlags,
  emptyCatalogue: emptyCatalogue,
  viewFor: viewFor,
  meta: meta,
  sortProviders: sortProviders,
};
