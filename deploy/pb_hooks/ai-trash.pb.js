/// <reference path="../pb_data/types.d.ts" />
///
/// The bin for removed providers — routes only, logic in ai-config-lib.js.
///
/// Whenever a provider leaves the catalogue it is kept in
/// `pb_data/ai-config/trash.json` together with who removed it, so an
/// accidental delete (by an administrator or by the author of a proposal) can
/// be undone. Restoring puts it back under the same id, which also brings back
/// the API keys people already stored on their devices for that id.
///
/// Every route here is for a PocketBase superuser only.
///
///   GET    /api/ai-trash            -> { count, items: [...] }
///   POST   /api/ai-trash/restore    -> { restored, provider|reason }
///   DELETE /api/ai-trash/{id}       -> { removed }
///   DELETE /api/ai-trash            -> { removed }
///
/// IMPORTANT: PocketBase runs these handlers in an isolated context, so the
/// module path is spelled out inside every handler on purpose.

routerAdd(
  "GET",
  "/api/ai-trash",
  (e) => {
    const lib = require(__hooks + "/ai-config-lib.js");
    const items = lib.readTrash();
    return e.json(200, { count: items.length, items: items });
  },
  $apis.requireSuperuserAuth(),
);

routerAdd(
  "POST",
  "/api/ai-trash/restore",
  (e) => {
    const lib = require(__hooks + "/ai-config-lib.js");
    const body = e.requestInfo().body;
    const id = body && typeof body.id === "string" ? body.id : "";
    if (!id) {
      throw new BadRequestError("Не указан id провайдера.");
    }
    return e.json(200, lib.restoreFromTrash(id));
  },
  $apis.requireSuperuserAuth(),
);

routerAdd(
  "DELETE",
  "/api/ai-trash/{id}",
  (e) => {
    const lib = require(__hooks + "/ai-config-lib.js");
    return e.json(200, lib.purgeTrash(e.request.pathValue("id")));
  },
  $apis.requireSuperuserAuth(),
);

routerAdd(
  "DELETE",
  "/api/ai-trash",
  (e) => {
    const lib = require(__hooks + "/ai-config-lib.js");
    return e.json(200, lib.purgeAllTrash());
  },
  $apis.requireSuperuserAuth(),
);
