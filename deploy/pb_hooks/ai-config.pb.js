/// <reference path="../pb_data/types.d.ts" />
///
/// Server-side config store for the "AI Providers list" — routes only.
///
/// The web page served at /ai-providers/ and the Android app both read and
/// write the very same JSON file, one per user:
///
///   <pb_data>/ai-config/<userId>.json
///
/// Endpoints (all require a record auth token):
///
///   GET    /api/ai-config        -> { version, updated, providers: [...] }
///   PUT    /api/ai-config        -> overwrites the file, returns what it saved
///   DELETE /api/ai-config        -> resets the file to an empty config
///   GET    /api/ai-config/meta   -> { dir, file, exists, bytes } (diagnostics)
///
/// IMPORTANT: PocketBase executes these handlers in an isolated context, so
/// they cannot see this file's top-level scope. All logic lives in
/// ai-config-lib.js and is required from inside each handler.
///
/// The API key is deliberately NOT part of the schema. It never leaves the
/// device: the Android app keeps it in flutter_secure_storage and strips it
/// before syncing, and the lib's sanitize() drops it even if it is sent.

/// The module path is spelled out inside every handler on purpose: these
/// handlers cannot see this file's top-level scope.
routerAdd(
  "GET",
  "/api/ai-config",
  (e) => {
    const lib = require(__hooks + "/ai-config-lib.js");
    return e.json(200, lib.readConfig(e.auth.id));
  },
  $apis.requireAuth(),
);

routerAdd(
  "PUT",
  "/api/ai-config",
  (e) => {
    const lib = require(__hooks + "/ai-config-lib.js");
    const body = e.requestInfo().body;
    if (!body || typeof body !== "object") {
      throw new BadRequestError("Ожидается JSON-объект с полем providers.");
    }
    return e.json(200, lib.writeConfig(e.auth.id, body));
  },
  $apis.requireAuth(),
);

routerAdd(
  "DELETE",
  "/api/ai-config",
  (e) => {
    const lib = require(__hooks + "/ai-config-lib.js");
    return e.json(200, lib.deleteConfig(e.auth.id));
  },
  $apis.requireAuth(),
);

routerAdd(
  "GET",
  "/api/ai-config/meta",
  (e) => {
    const lib = require(__hooks + "/ai-config-lib.js");
    return e.json(200, lib.meta(e.auth.id));
  },
  $apis.requireAuth(),
);
