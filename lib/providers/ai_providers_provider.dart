import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_provider.dart';
import '../services/ai_config_sync_service.dart';
import '../services/ai_providers_service.dart';
import '../services/secure_storage_service.dart';
import 'auth_provider.dart';

// The secure storage instance is shared with the auth layer so that a single
// override in tests (and a single keystore on device) serves both.
final aiProvidersServiceProvider = Provider<AiProvidersService>((ref) {
  return AiProvidersService(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  );
});

final aiConfigSyncServiceProvider = Provider<AiConfigSyncService>((ref) {
  return AiConfigSyncService(ref.watch(apiClientProvider));
});

/// Where the provider list currently lives.
enum AiProvidersSource {
  /// The account's PocketBase collection (default behaviour).
  account,

  /// The shared JSON file that also backs the web page at
  /// https://app.devhorizon.online/ai-providers/
  server,
}

class AiProvidersState {
  const AiProvidersState({
    this.items = const <AiProvider>[],
    this.isLoading = false,
    this.error,
    this.source = AiProvidersSource.account,
    this.syncedAt,
  });

  final List<AiProvider> items;
  final bool isLoading;
  final String? error;
  final AiProvidersSource source;

  /// When the server file was last written (server-side timestamp).
  final DateTime? syncedAt;

  bool get syncEnabled => source == AiProvidersSource.server;

  AiProvidersState copyWith({
    List<AiProvider>? items,
    bool? isLoading,
    String? error,
    AiProvidersSource? source,
    DateTime? syncedAt,
    bool clearSyncedAt = false,
  }) {
    return AiProvidersState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      source: source ?? this.source,
      syncedAt: clearSyncedAt ? null : (syncedAt ?? this.syncedAt),
    );
  }
}

class AiProvidersNotifier extends StateNotifier<AiProvidersState> {
  AiProvidersNotifier(this._ref) : super(const AiProvidersState());

  /// Secure-storage key holding the sync switch.
  static const String syncFlagKey = 'ai_providers_sync_enabled';

  final Ref _ref;

  AiProvidersService get _service => _ref.read(aiProvidersServiceProvider);
  AiConfigSyncService get _sync => _ref.read(aiConfigSyncServiceProvider);
  SecureStorageService get _storage => _ref.read(secureStorageProvider);

  String? get _userId {
    final auth = _ref.read(authProvider);
    return auth.user?.id;
  }

  /// Loads the list from whichever store the switch points at.
  Future<void> load() async {
    final userId = _userId;
    if (userId == null) {
      state = state.copyWith(items: const <AiProvider>[], isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    if (await _isSyncEnabled()) {
      try {
        await _pullFromServer(userId);
      } catch (e) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
      return;
    }

    try {
      final list = await _service.list(userId: userId);
      state = state.copyWith(
        items: list,
        isLoading: false,
        source: AiProvidersSource.account,
        clearSyncedAt: true,
      );
      if (list.isEmpty) {
        await _ensurePredefined(userId);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => load();

  // ------------------------------------------------------------ sync switch

  Future<bool> _isSyncEnabled() async =>
      await _storage.readValue(syncFlagKey) == 'true';

  /// Turns the server-file synchronisation on or off.
  ///
  /// Switching on downloads the shared config. When that file is still empty
  /// the providers configured here are uploaded instead, so the web page and
  /// the phone start from one list.
  Future<void> setSyncEnabled(bool enabled) async {
    final userId = _userId;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      if (!enabled) {
        await _storage.writeValue(syncFlagKey, 'false');
        state = state.copyWith(source: AiProvidersSource.account);
        await load();
        return;
      }

      await _storage.writeValue(syncFlagKey, 'true');
      state = state.copyWith(source: AiProvidersSource.server);

      final config = await _sync.fetch();

      if (config.providers.isEmpty && state.items.isNotEmpty) {
        final pushed = await _sync.push(state.items);
        state = state.copyWith(
          items: await _attachKeys(userId, pushed.providers),
          isLoading: false,
          syncedAt: pushed.updated ?? DateTime.now(),
        );
        return;
      }

      state = state.copyWith(
        items: await _attachKeys(userId, config.providers),
        isLoading: false,
        syncedAt: config.updated,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Pushes the current list to the server file ("sync now").
  Future<void> syncNow() async {
    final userId = _userId;
    if (userId == null || !state.syncEnabled) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final saved = await _sync.push(state.items);
      state = state.copyWith(
        items: await _attachKeys(userId, saved.providers),
        isLoading: false,
        syncedAt: saved.updated ?? DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Reads API keys back from the device for freshly downloaded providers:
  /// the server never sends them.
  Future<List<AiProvider>> _attachKeys(
    String userId,
    List<AiProvider> providers,
  ) async {
    final result = <AiProvider>[];
    for (final provider in providers) {
      final key = await _storage.readApiKey(
        userId: userId,
        providerId: provider.id,
      );
      result.add(provider.copyWith(apiKey: key, apiKeyExplicitlySet: true));
    }
    result.sort(_compare);
    return result;
  }

  Future<void> _pullFromServer(String userId) async {
    final config = await _sync.fetch();
    state = state.copyWith(
      items: await _attachKeys(userId, config.providers),
      isLoading: false,
      source: AiProvidersSource.server,
      syncedAt: config.updated,
    );
  }

  // -------------------------------------------------------------- mutations

  Future<void> add(AiProvider provider) async {
    final userId = _userId;
    if (userId == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (state.syncEnabled) {
        final local = provider.copyWith(userId: userId);
        await _storeKey(userId, local);
        await _pushLocal(userId, <AiProvider>[...state.items, local]);
        return;
      }

      final created = await _service.create(provider.copyWith(userId: userId));
      final newList = <AiProvider>[...state.items, created]..sort(_compare);
      state = state.copyWith(items: newList, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> update(String id, Map<String, dynamic> changes) async {
    final userId = _userId;
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (state.syncEnabled) {
        final index = state.items.indexWhere((p) => p.id == id);
        if (index < 0) {
          state = state.copyWith(isLoading: false);
          return;
        }

        var updated = _applyChanges(state.items[index], changes);

        final apiKey = changes['api_key'];
        if (apiKey is String && apiKey.isNotEmpty && userId != null) {
          await _storage.writeApiKey(
            userId: userId,
            providerId: id,
            apiKey: apiKey,
          );
          updated = updated.copyWith(
            apiKey: apiKey,
            apiKeyExplicitlySet: true,
          );
        }

        final list = <AiProvider>[...state.items]..[index] = updated;
        await _pushLocal(userId, list);
        return;
      }

      final effectiveChanges = Map<String, dynamic>.from(changes);
      if (userId != null) {
        effectiveChanges['userId'] = userId;
      }
      final updated = await _service.update(id, effectiveChanges);
      final newList = state.items
          .map((p) => p.id == id ? updated : p)
          .toList()
        ..sort(_compare);
      state = state.copyWith(items: newList, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> toggle(String id, bool enabled) async {
    await update(id, <String, dynamic>{'enabled': enabled});
  }

  Future<void> delete(String id) async {
    final userId = _userId;
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (state.syncEnabled) {
        if (userId != null) {
          await _storage.deleteApiKey(userId: userId, providerId: id);
        }
        await _pushLocal(
          userId,
          state.items.where((p) => p.id != id).toList(),
        );
        return;
      }

      await _service.delete(id, userId: userId);
      final newList = state.items.where((p) => p.id != id).toList()
        ..sort(_compare);
      state = state.copyWith(items: newList, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Sends the whole list to the shared file and adopts the server's answer.
  Future<void> _pushLocal(String? userId, List<AiProvider> providers) async {
    final sorted = <AiProvider>[...providers]..sort(_compare);
    final saved = await _sync.push(sorted);
    state = state.copyWith(
      items: userId == null
          ? saved.providers
          : await _attachKeys(userId, saved.providers),
      isLoading: false,
      source: AiProvidersSource.server,
      syncedAt: saved.updated ?? DateTime.now(),
    );
  }

  Future<void> _storeKey(String userId, AiProvider provider) async {
    final key = provider.apiKey;
    if (key != null && key.isNotEmpty) {
      await _storage.writeApiKey(
        userId: userId,
        providerId: provider.id,
        apiKey: key,
      );
    }
  }

  /// Applies editor changes to a model without touching any store.
  ///
  /// Unlike [AiProvider.copyWith] this can also *clear* a field, which the
  /// editor asks for by sending null.
  AiProvider _applyChanges(AiProvider provider, Map<String, dynamic> changes) {
    String? text(String key, String? current) {
      if (!changes.containsKey(key)) return current;
      final value = changes[key];
      if (value == null) return null;
      final trimmed = value.toString().trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return AiProvider(
      id: provider.id,
      userId: provider.userId,
      name: text('name', provider.name) ?? provider.name,
      enabled: changes.containsKey('enabled')
          ? changes['enabled'] == true
          : provider.enabled,
      url: text('url', provider.url) ?? provider.url,
      model: text('model', provider.model) ?? provider.model,
      apiKey: provider.apiKey,
      fallbackPriority: changes['fallbackPriority'] is num
          ? (changes['fallbackPriority'] as num).toInt()
          : provider.fallbackPriority,
      loginUrl: text('loginUrl', provider.loginUrl),
      getApiKeyUrl: text('getApiKeyUrl', provider.getApiKeyUrl),
      logoUrl: text('logoUrl', provider.logoUrl),
      logoAsset: text('logoAsset', provider.logoAsset),
      isPredefined: provider.isPredefined,
    );
  }

  Future<void> _ensurePredefined(String userId) async {
    final predefined = _predefinedList(userId);
    for (final p in predefined) {
      try {
        await _service.create(p);
      } catch (_) {}
    }
    await load();
  }

  List<AiProvider> _predefinedList(String userId) => <AiProvider>[
        AiProvider(
          id: 'openai',
          userId: userId,
          name: 'OpenAI',
          enabled: false,
          url: 'https://api.openai.com/v1',
          model: 'gpt-4o-mini',
          fallbackPriority: 1,
          loginUrl: 'https://platform.openai.com/',
          getApiKeyUrl: 'https://platform.openai.com/api-keys',
          logoAsset: 'openai',
          isPredefined: true,
        ),
        AiProvider(
          id: 'anthropic',
          userId: userId,
          name: 'Anthropic (Claude)',
          enabled: false,
          url: 'https://api.anthropic.com',
          model: 'claude-3.5-sonnet',
          fallbackPriority: 2,
          loginUrl: 'https://console.anthropic.com/',
          getApiKeyUrl: 'https://console.anthropic.com/settings/keys',
          logoAsset: 'anthropic',
          isPredefined: true,
        ),
        AiProvider(
          id: 'gemini',
          userId: userId,
          name: 'Google Gemini',
          enabled: false,
          url: 'https://generativelanguage.googleapis.com/v1beta/openai',
          model: 'gemini-1.5-flash',
          fallbackPriority: 3,
          loginUrl: 'https://aistudio.google.com/',
          getApiKeyUrl: 'https://aistudio.google.com/apikey',
          logoAsset: 'google-gemini',
          isPredefined: true,
        ),
        AiProvider(
          id: 'groq',
          userId: userId,
          name: 'Groq',
          enabled: false,
          url: 'https://api.groq.com/openai/v1',
          model: 'llama-3.1-8b-instant',
          fallbackPriority: 4,
          loginUrl: 'https://console.groq.com/',
          getApiKeyUrl: 'https://console.groq.com/keys',
          logoAsset: 'groq',
          isPredefined: true,
        ),
        AiProvider(
          id: 'openrouter',
          userId: userId,
          name: 'OpenRouter',
          enabled: false,
          url: 'https://openrouter.ai/api/v1',
          model: 'openrouter/auto',
          fallbackPriority: 5,
          loginUrl: 'https://www.openrouter.ai/',
          getApiKeyUrl: 'https://www.openrouter.ai/keys',
          logoAsset: 'openrouter',
          isPredefined: true,
        ),
        AiProvider(
          id: 'ollama',
          userId: userId,
          name: 'Ollama',
          enabled: false,
          url: 'http://localhost:11434/v1',
          model: 'llama3.2',
          fallbackPriority: 6,
          loginUrl: 'https://ollama.com/',
          getApiKeyUrl: 'https://ollama.com/',
          logoAsset: 'ollama',
          isPredefined: true,
        ),
        AiProvider(
          id: 'lmstudio',
          userId: userId,
          name: 'LM Studio',
          enabled: false,
          url: 'http://localhost:1234/v1',
          model: 'local-model',
          fallbackPriority: 7,
          loginUrl: 'https://lmstudio.ai/',
          getApiKeyUrl: 'https://lmstudio.ai/',
          logoAsset: 'lmstudio',
          isPredefined: true,
        ),
        AiProvider(
          id: 'mistral',
          userId: userId,
          name: 'Mistral',
          enabled: false,
          url: 'https://api.mistral.ai/v1',
          model: 'mistral-small-latest',
          fallbackPriority: 8,
          loginUrl: 'https://console.mistral.ai/',
          getApiKeyUrl: 'https://console.mistral.ai/api-keys/',
          logoAsset: 'mistral',
          isPredefined: true,
        ),
        AiProvider(
          id: 'together',
          userId: userId,
          name: 'Together AI',
          enabled: false,
          url: 'https://api.together.xyz/v1',
          model: 'meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo',
          fallbackPriority: 9,
          loginUrl: 'https://www.together.ai/',
          getApiKeyUrl: 'https://api.together.xyz/settings/api-keys',
          logoAsset: 'together',
          isPredefined: true,
        ),
        AiProvider(
          id: 'fireworks',
          userId: userId,
          name: 'Fireworks AI',
          enabled: false,
          url: 'https://api.fireworks.ai/inference/v1',
          model: 'accounts/fireworks/models/llama-v3p1-8b-instruct',
          fallbackPriority: 10,
          loginUrl: 'https://app.fireworks.ai/',
          getApiKeyUrl: 'https://app.fireworks.ai/settings/users/api-keys',
          logoAsset: 'fireworks',
          isPredefined: true,
        ),
      ];

  int _compare(AiProvider a, AiProvider b) {
    if (a.fallbackPriority != b.fallbackPriority) {
      return a.fallbackPriority.compareTo(b.fallbackPriority);
    }
    return a.id.compareTo(b.id);
  }
}

final aiProvidersProvider =
    StateNotifierProvider<AiProvidersNotifier, AiProvidersState>((ref) {
  return AiProvidersNotifier(ref);
});
