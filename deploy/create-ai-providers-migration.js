/// PocketBase migration: creates the `ai_providers` collection used by the
/// Flutter app's "AI Providers list" screen.
///
/// Install:
///   cp create-ai-providers-migration.js ~/pocketbase/pb_migrations/1760313600_create_ai_providers.js
///   systemctl restart pocketbase      # or: ./pocketbase serve ...
///
/// PocketBase applies pending migrations automatically on serve.
/// The migration is idempotent: if the collection already exists it does nothing.
///
/// NOTE: the API key is deliberately NOT a field here. It lives on the device
/// in flutter_secure_storage and is stripped from every request by the client.

migrate(
  (app) => {
    // Idempotent: skip when the collection was already created by hand.
    try {
      app.findCollectionByNameOrId('ai_providers');
      return;
    } catch (_) {
      // not found -> create it below
    }

    const ownerRule = "@request.auth.id != '' && user = @request.auth.id";
    const signedInRule = "@request.auth.id != ''";

    const collection = new Collection({
      type: 'base',
      name: 'ai_providers',
      listRule: ownerRule,
      viewRule: ownerRule,
      createRule: signedInRule,
      updateRule: ownerRule,
      deleteRule: ownerRule,
      fields: [
        {
          type: 'relation',
          name: 'user',
          required: true,
          collectionId: '_pb_users_auth_',
          cascadeDelete: false,
          minSelect: 0,
          maxSelect: 1,
        },
        { type: 'text', name: 'name', required: true, max: 0 },
        { type: 'bool', name: 'enabled' },
        { type: 'url', name: 'url', required: true },
        { type: 'text', name: 'model', required: true, max: 0 },
        {
          type: 'number',
          name: 'fallbackPriority',
          required: false,
          min: 0,
          max: null,
          noDecimal: true,
        },
        { type: 'url', name: 'loginUrl' },
        { type: 'url', name: 'getApiKeyUrl' },
        { type: 'url', name: 'logoUrl' },
        { type: 'text', name: 'logoAsset', max: 0 },
        { type: 'bool', name: 'isPredefined' },
      ],
      indexes: [
        'CREATE INDEX `idx_ai_providers_user` ON `ai_providers` (`user`)',
        'CREATE INDEX `idx_ai_providers_priority` ON `ai_providers` (`fallbackPriority`)',
      ],
    });

    app.save(collection);
  },
  (app) => {
    try {
      app.delete(app.findCollectionByNameOrId('ai_providers'));
    } catch (_) {
      // already gone
    }
  },
);
