/// Shared helpers for the /api/ai-config routes.
///
/// IMPORTANT: PocketBase executes route handlers in an isolated context, so a
/// handler cannot see the top-level scope of the file that registered it
/// (`ReferenceError: <name> is not defined`). Everything shared therefore lives
/// in this module and is pulled in with require() from *inside* each handler.
///
/// Storage layout, one file per user:
///   <pb_data>/ai-config/<userId>.json

const CONFIG_VERSION = 1;

/// Resolves the directory holding the per-user config files.
function configDir() {
  const override = $os.getenv("PB_AI_CONFIG_DIR");
  if (override) {
    return override;
  }
  // PocketBase runs with its own directory as the working directory
  // (systemd WorkingDirectory=...), so this resolves to <pb_dir>/pb_data.
  return $os.getwd() + "/pb_data/ai-config";
}

function configPath(userId) {
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

function asText(value) {
  return typeof value === "string" ? value : "";
}

function asInt(value) {
  const n = typeof value === "number" ? value : parseInt(value, 10);
  return isNaN(n) || n < 0 ? 0 : Math.floor(n);
}

/// Keeps only known, non-secret fields. Anything else (notably `api_key`)
/// is dropped, so a hand-written request cannot smuggle a secret into the file.
function sanitize(raw) {
  if (!raw || typeof raw !== "object") {
    return null;
  }

  const provider = {
    id: asText(raw.id),
    name: asText(raw.name),
    enabled: raw.enabled === true,
    url: asText(raw.url),
    model: asText(raw.model),
    fallbackPriority: asInt(raw.fallbackPriority),
    loginUrl: asText(raw.loginUrl),
    getApiKeyUrl: asText(raw.getApiKeyUrl),
    logoUrl: asText(raw.logoUrl),
    logoAsset: asText(raw.logoAsset),
    isPredefined: raw.isPredefined === true,
  };

  if (!provider.id || !provider.name) {
    return null;
  }

  return provider;
}

function emptyConfig() {
  return { version: CONFIG_VERSION, updated: "", providers: [] };
}

function readConfig(userId) {
  const path = configPath(userId);
  if (!fileExists(path)) {
    return emptyConfig();
  }

  let parsed;
  try {
    parsed = JSON.parse(toString($os.readFile(path)));
  } catch (err) {
    $app.logger().warn("ai-config: unreadable file", "path", path, "error", err);
    return emptyConfig();
  }

  const rawProviders =
    parsed && Array.isArray(parsed.providers) ? parsed.providers : [];

  const providers = [];
  for (const raw of rawProviders) {
    const provider = sanitize(raw);
    if (provider) {
      providers.push(provider);
    }
  }

  return {
    version: CONFIG_VERSION,
    updated: asText(parsed && parsed.updated),
    providers: providers,
  };
}

function writeConfig(userId, incoming) {
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
    providers.push(provider);
  }

  providers.sort(function (a, b) {
    if (a.fallbackPriority !== b.fallbackPriority) {
      return a.fallbackPriority - b.fallbackPriority;
    }
    return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
  });

  const doc = {
    version: CONFIG_VERSION,
    updated: new Date().toISOString(),
    providers: providers,
  };

  const dir = configDir();
  try {
    $os.mkdirAll(dir, 0o755);
  } catch (err) {
    // already exists
  }
  $os.writeFile(configPath(userId), JSON.stringify(doc, null, 2), 0o600);

  return doc;
}

function deleteConfig(userId) {
  const path = configPath(userId);
  if (fileExists(path)) {
    $os.remove(path);
  }
  return emptyConfig();
}

function meta(userId) {
  const path = configPath(userId);
  const exists = fileExists(path);
  return {
    dir: configDir(),
    file: path,
    exists: exists,
    bytes: exists ? $os.stat(path).size() : 0,
  };
}

module.exports = {
  configDir: configDir,
  configPath: configPath,
  readConfig: readConfig,
  writeConfig: writeConfig,
  deleteConfig: deleteConfig,
  emptyConfig: emptyConfig,
  meta: meta,
};
