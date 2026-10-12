/// <reference path="../pb_data/types.d.ts" />
///
/// Route registration only — the logic lives in ai-stats-lib.js.
///
/// Test statistics for the provider catalogue: one entry per provider and
/// model, showing how many users succeed, how many run into errors and when
/// the last report arrived.
///
///   GET  /api/ai-stats   -> { "<providerId>": { models: { "<model>": {...} } } }
///   POST /api/ai-stats   -> records one test result, returns that provider
///
/// Both need a token (a record or a superuser).
///
/// A provider the administrator marked as `dead` in the catalogue must not be
/// tested at all, so POST refuses such a report — the app also disables the
/// button, this is the server-side half of that rule.
///
/// IMPORTANT: PocketBase runs these handlers in an isolated context, so the
/// module paths are spelled out inside every handler on purpose.



routerAdd(
  "GET",
  "/api/ai-stats",
  (e) => {
    const stats = require(__hooks + "/ai-stats-lib.js");
    const config = require(__hooks + "/ai-config-lib.js");

    const catalogue = config.readCatalogue();
    const ids = [];
    for (const provider of catalogue.providers) {
      ids.push(provider.id);
    }

    return e.json(200, stats.readFor(ids));
  },
  (e) => {
    if (e.auth || e.hasSuperuserAuth()) {
      return e.next();
    }
    throw new UnauthorizedError();
  },
);

routerAdd(
  "POST",
  "/api/ai-stats",
  (e) => {
    const stats = require(__hooks + "/ai-stats-lib.js");
    const config = require(__hooks + "/ai-config-lib.js");

    const body = e.requestInfo().body;
    if (!body || typeof body !== "object") {
      throw new BadRequestError("Ожидается JSON-объект.");
    }

    const providerId = typeof body.providerId === "string" ? body.providerId : "";
    if (!providerId) {
      throw new BadRequestError("Не указан providerId.");
    }

    // A provider marked as dead by the administrator cannot be tested.
    const catalogue = config.readCatalogue();
    let known = null;
    for (const provider of catalogue.providers) {
      if (provider.id === providerId) {
        known = provider;
        break;
      }
    }

    if (!known) {
      throw new NotFoundError("Провайдер не найден в каталоге.");
    }
    if (known.status === config.STATUS_DEAD) {
      throw new ForbiddenError(
        "Провайдер помечен администратором как неработающий.",
      );
    }

    const userId = e.auth ? e.auth.id : "superuser";
    const model = typeof body.model === "string" ? body.model : "";
    const error = typeof body.error === "string" ? body.error : "";

    return e.json(200, stats.record(providerId, model, userId, body.ok === true, error));
  },
  (e) => {
    if (e.auth || e.hasSuperuserAuth()) {
      return e.next();
    }
    throw new UnauthorizedError();
  },
);
