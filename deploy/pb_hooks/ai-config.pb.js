/// <reference path="../pb_data/types.d.ts" />
///
/// Routes only — the logic lives in ai-config-lib.js.
///
/// The provider catalogue is owned by a PocketBase superuser. A regular user
/// can read it, switch entries on and store their own API keys on the device;
/// they cannot add, edit or delete providers.
///
///   GET    /api/ai-config       -> { version, updated, canEdit, providers }
///   PUT    /api/ai-config       -> superuser: replaces the catalogue;
///                                  regular user: stores only the enabled flags
///   DELETE /api/ai-config       -> regular user: clears their flags
///   GET    /api/ai-config/meta  -> diagnostics
///
/// IMPORTANT: PocketBase runs these handlers in an isolated context, so they
/// cannot see this file's top-level scope: the module path is spelled out
/// inside every handler on purpose.
///
/// The API key is not part of the schema. The lib's sanitize() drops it even
/// if one is sent by hand.

/// Allows both a record token and a superuser token.
/// Defined inline in every route because a shared function would not be
/// reachable from the handler context.
routerAdd(
  "GET",
  "/api/ai-config",
  (e) => {
    const lib = require(__hooks + "/ai-config-lib.js");
    if (e.hasSuperuserAuth()) {
      return e.json(200, lib.viewFor({}, true, ""));
    }
    if (!e.auth) {
      throw new UnauthorizedError();
    }
    return e.json(200, lib.viewFor(lib.readFlags(e.auth.id), false, e.auth.id));
  },
  (e) => {
    if (e.auth || e.hasSuperuserAuth()) {
      return e.next();
    }
    throw new UnauthorizedError();
  },
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

    if (e.hasSuperuserAuth()) {
      lib.writeCatalogue(body);
      return e.json(200, lib.viewFor({}, true, ""));
    }

    if (!e.auth) {
      throw new UnauthorizedError();
    }

    // A regular user may flip flags and propose their own providers; an
    // administrator's entries and other users' proposals are untouchable.
    lib.applyUserWrite(e.auth.id, e.auth.get("name") || e.auth.get("email"), body);
    return e.json(
      200,
      lib.viewFor(lib.readFlags(e.auth.id), false, e.auth.id),
    );
  },
  (e) => {
    if (e.auth || e.hasSuperuserAuth()) {
      return e.next();
    }
    throw new UnauthorizedError();
  },
);

routerAdd(
  "DELETE",
  "/api/ai-config",
  (e) => {
    const lib = require(__hooks + "/ai-config-lib.js");
    if (e.auth) {
      lib.clearFlags(e.auth.id);
      return e.json(200, lib.viewFor({}, false, e.auth.id));
    }
    throw new UnauthorizedError("Сбросить каталог может только суперпользователь.");
  },
  (e) => {
    if (e.auth || e.hasSuperuserAuth()) {
      return e.next();
    }
    throw new UnauthorizedError();
  },
);

routerAdd(
  "GET",
  "/api/ai-config/meta",
  (e) => {
    const lib = require(__hooks + "/ai-config-lib.js");
    const isSuperuser = e.hasSuperuserAuth();
    return e.json(200, lib.meta(e.auth ? e.auth.id : "", isSuperuser));
  },
  (e) => {
    if (e.auth || e.hasSuperuserAuth()) {
      return e.next();
    }
    throw new UnauthorizedError();
  },
);
