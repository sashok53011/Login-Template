/// Shared helpers for the /api/ai-stats routes.
///
/// Keeps one small JSON file per provider with the outcome of the tests users
/// ran against it:
///
///   <pb_data>/ai-stats/<providerId>.json
///
/// Shape on disk (the raw per-user counters are not exposed over the API):
///
///   { version, providerId, updated, models: {
///       "<model>": { ok, fail, last, lastStatus, lastError,
///                    users: { "<userId>": { ok, fail, last } } } } }
///
/// The API exposes, per model:
///
///   { ok, fail, usersOk, usersFail, last, lastStatus, lastError }
///
/// `usersOk` is the number of distinct users who had at least one success —
/// that is the "how many people use this model successfully" figure.
///
/// IMPORTANT: like ai-config-lib.js this module is pulled in with require()
/// from *inside* the route handlers, because PocketBase runs handlers in an
/// isolated context that cannot see a hook file's top-level scope.

const STATS_VERSION = 1;

/// Guards against unbounded growth from hostile input.
const MAX_MODELS = 300;
const MAX_MODEL_LENGTH = 120;
const MAX_ERROR_LENGTH = 300;

function statsDir() {
  const override = $os.getenv("PB_AI_STATS_DIR");
  if (override) {
    return override;
  }
  return $os.getwd() + "/pb_data/ai-stats";
}

function statsPath(providerId) {
  return statsDir() + "/" + safeId(providerId) + ".json";
}

/// Provider ids come from the catalogue but are still cleaned before being
/// used as a file name.
function safeId(value) {
  return asText(value).replace(/[^A-Za-z0-9_.-]/g, "_").slice(0, 64);
}

function asText(value) {
  return typeof value === "string" ? value : "";
}

function asInt(value) {
  const n = typeof value === "number" ? value : parseInt(value, 10);
  return isNaN(n) || n < 0 ? 0 : Math.floor(n);
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
    $app.logger().warn("ai-stats: unreadable file", "path", path, "error", err);
    return null;
  }
}

function writeJson(path, value) {
  const dir = statsDir();
  try {
    $os.mkdirAll(dir, 0o755);
  } catch (err) {
    // already exists
  }
  $os.writeFile(path, JSON.stringify(value, null, 2), 0o600);
}

function emptyProvider(providerId) {
  return {
    version: STATS_VERSION,
    providerId: providerId,
    updated: "",
    models: {},
  };
}

function readProvider(providerId) {
  const parsed = readJson(statsPath(providerId));
  if (!parsed || typeof parsed !== "object" || !parsed.models) {
    return emptyProvider(safeId(providerId));
  }
  parsed.providerId = safeId(providerId);
  return parsed;
}

// -------------------------------------------------------------- reporting

/// Records one test result and returns the public view for that provider.
///
/// `ok` counts an attempt where the provider answered and offered the model;
/// `fail` counts a rejected key, an unreachable endpoint or a model the
/// provider does not serve.
function record(providerId, model, userId, ok, error) {
  const id = safeId(providerId);
  const stats = readProvider(id);

  const name = asText(model).slice(0, MAX_MODEL_LENGTH) || "(без модели)";
  const user = asText(userId) || "anonymous";

  if (!stats.models[name]) {
    if (Object.keys(stats.models).length >= MAX_MODELS) {
      throw new BadRequestError("Слишком много моделей в статистике.");
    }
    stats.models[name] = {
      ok: 0,
      fail: 0,
      last: "",
      lastStatus: "",
      lastError: "",
      users: {},
    };
  }

  const entry = stats.models[name];
  const now = new Date().toISOString();

  if (ok === true) {
    entry.ok = asInt(entry.ok) + 1;
    entry.lastStatus = "ok";
    entry.lastError = "";
  } else {
    entry.fail = asInt(entry.fail) + 1;
    entry.lastStatus = "fail";
    entry.lastError = asText(error).slice(0, MAX_ERROR_LENGTH);
  }
  entry.last = now;

  if (!entry.users[user]) {
    entry.users[user] = { ok: 0, fail: 0, last: "" };
  }
  if (ok === true) {
    entry.users[user].ok = asInt(entry.users[user].ok) + 1;
  } else {
    entry.users[user].fail = asInt(entry.users[user].fail) + 1;
  }
  entry.users[user].last = now;

  stats.updated = now;
  writeJson(statsPath(id), stats);

  return viewFor(stats);
}

/// Strips the raw per-user counters; the API only returns the totals.
function viewFor(stats) {
  const models = {};

  for (const name of Object.keys(stats.models || {})) {
    const entry = stats.models[name];
    let usersOk = 0;
    let usersFail = 0;

    const users = entry.users || {};
    for (const key of Object.keys(users)) {
      if (asInt(users[key].ok) > 0) {
        usersOk++;
      }
      if (asInt(users[key].fail) > 0) {
        usersFail++;
      }
    }

    models[name] = {
      ok: asInt(entry.ok),
      fail: asInt(entry.fail),
      usersOk: usersOk,
      usersFail: usersFail,
      last: asText(entry.last),
      lastStatus: asText(entry.lastStatus),
      lastError: asText(entry.lastError),
    };
  }

  return {
    version: STATS_VERSION,
    providerId: asText(stats.providerId),
    updated: asText(stats.updated),
    models: models,
  };
}

/// Stats for the given provider ids, keyed by provider id.
///
/// The caller passes the ids (usually taken from the catalogue) so that no
/// directory listing is needed.
function readFor(providerIds) {
  const result = {};

  for (const providerId of providerIds || []) {
    const id = safeId(providerId);
    const stats = readProvider(id);
    if (Object.keys(stats.models).length > 0) {
      result[id] = viewFor(stats);
    }
  }

  return result;
}

module.exports = {
  STATS_VERSION: STATS_VERSION,
  statsDir: statsDir,
  statsPath: statsPath,
  readProvider: readProvider,
  readFor: readFor,
  record: record,
  viewFor: viewFor,
};
