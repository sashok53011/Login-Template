/// <reference path="../pb_data/types.d.ts" />
///
/// Closes an information leak in the `users` List/Search rule.
///
/// The rule exists only for the app's live availability check:
///
///   GET /api/collections/users/records?k=pb_av_1&q=<value>
///
/// Without the `@request.query.q != ''` guard, a request with NO `q` at all
/// evaluates `email = @request.query.q` as `email = ''` and happily returns
/// every record whose `name` or `email` is empty — including the account the
/// app created before it started filling the `name` field.
///
/// Install:
///   cp tighten-users-list-rule.js \
///      ~/pocketbase/pb_migrations/1791463100_tighten_users_list_rule.js
///   sudo systemctl restart pocketbase
migrate((app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_")

  // update collection data
  unmarshal({
    "listRule": "@request.query.k = 'pb_av_1' && @request.query.q != '' && (email = @request.query.q || name = @request.query.q)"
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_")

  // update collection data
  unmarshal({
    "listRule": "@request.query.k = 'pb_av_1' && (email = @request.query.q || name = @request.query.q)"
  }, collection)

  return app.save(collection)
})
