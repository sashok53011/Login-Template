import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_config.dart';
import '../models/ai_provider.dart';
import '../models/ai_stats.dart';
import '../services/ai_config_sync_service.dart';
import '../services/ai_stats_service.dart';
import '../services/provider_test_service.dart';
import '../services/secure_storage_service.dart';
import 'auth_provider.dart';

final aiConfigSyncServiceProvider = Provider<AiConfigSyncService>((ref) {
  return AiConfigSyncService(ref.watch(apiClientProvider));
});

final aiStatsServiceProvider = Provider<AiStatsService>((ref) {
  return AiStatsService(ref.watch(apiClientProvider));
});

final providerTestServiceProvider = Provider<ProviderTestService>((ref) {
  return ProviderTestService();
});

/// Where the list currently comes from.
enum AiProvidersSource {
  /// The administrator's catalogue on the server (normal operation).
  catalogue,

  /// A local snapshot of the last catalogue, used when synchronisation is off.
  snapshot,
}

class AiProvidersState {
  const AiProvidersState({
    this.items = const <AiProvider>[],
    this.isLoading = false,
    this.error,
    this.source = AiProvidersSource.catalogue,
    this.syncedAt,
    this.stats = const <String, ProviderStats>{},
    this.testing = const <String>{},
    this.models = const <String, List<String>>{},
  });

  final List<AiProvider> items;
  final bool isLoading;
  final String? error;
  final AiProvidersSource source;

  /// When the catalogue was last changed on the server.
  final DateTime? syncedAt;

  /// Test statistics per provider, keyed by provider id.
  final Map<String, ProviderStats> stats;

  /// Providers whose test is running right now.
  final Set<String> testing;

  /// Models discovered by the last test, keyed by provider id.
  final Map<String, List<String>> models;

  bool get syncEnabled => source == AiProvidersSource.catalogue;

  ModelStats? statsFor(AiProvider provider) =>
      stats[provider.id]?.forModel(provider.model);

  AiProvidersState copyWith({
    List<AiProvider>? items,
    bool? isLoading,
    String? error,
    AiProvidersSource? source,
    DateTime? syncedAt,
    bool clearSyncedAt = false,
    Map<String, ProviderStats>? stats,
    Set<String>? testing,
    Map<String, List<String>>? models,
  }) {
    return AiProvidersState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      source: source ?? this.source,
      syncedAt: clearSyncedAt ? null : (syncedAt ?? this.syncedAt),
      stats: stats ?? this.stats,
      testing: testing ?? this.testing,
      models: models ?? this.models,
    );
  }
}

/// The provider catalogue is owned by a PocketBase superuser.
///
/// The app can only switch entries on and off and keep the user's API keys on
/// the device, so there is no add / edit / delete here by design.
///
/// On every load the **disabled** entries are reconciled against the server:
///
/// * still in the catalogue  -> keep, and take the fresh URL / model from it;
/// * `status: dead`          -> drop it (the "trace" that the provider died);
/// * gone from the catalogue -> drop it.
///
/// Entries the user switched **on** are never touched: their URL, model and
/// key stay exactly as the user left them.
class AiProvidersNotifier extends StateNotifier<AiProvidersState> {
  AiProvidersNotifier(this._ref) : super(const AiProvidersState());

  /// Secure-storage key for the synchronisation switch.
  static const String syncFlagKey = 'ai_providers_sync_enabled';

  static const String _snapshotPrefix = 'ai_providers_snapshot_';

  final Ref _ref;

  AiConfigSyncService get _sync => _ref.read(aiConfigSyncServiceProvider);
  AiStatsService get _statsService => _ref.read(aiStatsServiceProvider);
  ProviderTestService get _testService => _ref.read(providerTestServiceProvider);
  SecureStorageService get _storage => _ref.read(secureStorageProvider);

  String? get _userId => _ref.read(authProvider).user?.id;

  /// Synchronisation is on by default: the catalogue is the only place provider
  /// definitions come from.
  Future<bool> _isSyncEnabled() async {
    final stored = await _storage.readValue(syncFlagKey);
    return stored == null ? true : stored == 'true';
  }

  Future<void> load() async {
    final userId = _userId;
    if (userId == null) {
      state = state.copyWith(items: const <AiProvider>[], isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    if (!await _isSyncEnabled()) {
      state = state.copyWith(
        items: await _readSnapshot(userId),
        isLoading: false,
        source: AiProvidersSource.snapshot,
        clearSyncedAt: true,
      );
      return;
    }

    try {
      final AiConfig view = await _sync.fetch();
      // The reconciliation baseline is the last known list, not the (possibly
      // empty) in-memory state: an entry switched on earlier must keep its
      // local URL and key across restarts.
      final local = await _readSnapshot(userId);
      final items = await _reconcile(userId, local, view.providers);
      state = state.copyWith(
        items: items,
        isLoading: false,
        source: AiProvidersSource.catalogue,
        syncedAt: view.updated,
      );
      await _saveSnapshot(userId, items);
      await refreshStats();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Loads the test statistics of every catalogue provider.
  ///
  /// Statistics are secondary: a failure here must never break the screen.
  Future<void> refreshStats() async {
    if (_userId == null) return;
    try {
      final stats = await _statsService.fetchAll();
      state = state.copyWith(stats: stats);
    } catch (_) {
      // ignored on purpose
    }
  }

  /// Asks the provider for its model list and publishes the result.
  ///
  /// One request covers both the "fetch model list" button and the API key
  /// check, and the outcome is recorded on the server right away so that the
  /// counters and the last-message time stay current.
  ///
  /// A provider the administrator marked as `dead` is not tested at all — the
  /// server rejects such a report as well.
  Future<ProviderTestResult?> testProvider(String id) async {
    final provider = _find(id);
    if (provider == null) return null;

    if (provider.isDead) {
      state = state.copyWith(
        error: 'Провайдер помечен администратором как неработающий.',
      );
      return null;
    }

    final apiKey = provider.apiKey ?? '';
    if (apiKey.isEmpty) {
      state = state.copyWith(error: 'Сначала введите API-ключ.');
      return null;
    }

    state = state.copyWith(
      testing: <String>{...state.testing, id},
      error: null,
    );

    final result = await _testService.fetchModels(
      provider: provider,
      apiKey: apiKey,
    );

    // Success means: the key works *and* the provider offers the configured
    // model. A key that works but does not serve the model is reported as a
    // failure, so the administrator can see which models people cannot use.
    final offers = result.offersModel(provider.model);
    final ok = result.ok && offers;
    final error = result.ok
        ? (offers ? null : 'Модель ${provider.model} не предлагается')
        : result.error;

    try {
      final stats = await _statsService.report(
        providerId: id,
        model: provider.model,
        ok: ok,
        error: error,
      );
      state = state.copyWith(
        testing: state.testing.where((String t) => t != id).toSet(),
        stats: <String, ProviderStats>{...state.stats, id: stats},
        models: <String, List<String>>{...state.models, id: result.models},
        error: ok ? null : error,
      );
    } catch (e) {
      state = state.copyWith(
        testing: state.testing.where((String t) => t != id).toSet(),
        error: e.toString(),
      );
    }

    return result;
  }

  AiProvider? _find(String id) {
    for (final provider in state.items) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  Future<void> refresh() => load();

  /// Manual "sync now" (only meaningful while synchronisation is on).
  Future<void> syncNow() async {
    if (!state.syncEnabled) return;
    await load();
  }

  Future<void> setSyncEnabled(bool enabled) async {
    if (_userId == null) return;
    await _storage.writeValue(syncFlagKey, enabled ? 'true' : 'false');
    state = state.copyWith(
      source:
          enabled ? AiProvidersSource.catalogue : AiProvidersSource.snapshot,
    );
    await load();
  }

  /// Switches one catalogue entry on or off and stores the choice server-side.
  Future<void> toggle(String id, bool enabled) async {
    final userId = _userId;
    if (userId == null) return;

    final items = state.items
        .map((p) => p.id == id ? p.copyWith(enabled: enabled) : p)
        .toList();
    state = state.copyWith(items: items);

    if (!state.syncEnabled) {
      await _saveSnapshot(userId, items);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final AiConfig view = await _sync.push(items);
      final merged = await _reconcile(userId, items, view.providers);
      state = state.copyWith(
        items: merged,
        isLoading: false,
        syncedAt: view.updated,
      );
      await _saveSnapshot(userId, merged);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Stores the API key on the device. It is never sent to the server.
  Future<void> setApiKey(String id, String apiKey) async {
    final userId = _userId;
    if (userId == null) return;

    final value = apiKey.trim();
    if (value.isEmpty) {
      await _storage.deleteApiKey(userId: userId, providerId: id);
    } else {
      await _storage.writeApiKey(
        userId: userId,
        providerId: id,
        apiKey: value,
      );
    }

    final items = state.items
        .map(
          (p) => p.id == id
              ? p.copyWith(
                  apiKey: value.isEmpty ? null : value,
                  apiKeyExplicitlySet: true,
                )
              : p,
        )
        .toList();
    state = state.copyWith(items: items);
    await _saveSnapshot(userId, items);

    // A fresh key is tested right away, so the server statistics are updated
    // immediately after new data is entered.
    if (value.isNotEmpty) {
      final provider = _find(id);
      if (provider != null && !provider.isDead) {
        await testProvider(id);
      }
    }
  }

  // ------------------------------------------------------------- internals

  /// Reconciles the list with the catalogue and attaches the keys that live on
  /// the device.
  ///
  /// Only the entries the user switched **off** are processed:
  ///
  /// * still in the catalogue -> keep, taking the fresh URL / model from it;
  /// * `status: dead`         -> drop (the trace that the provider died);
  /// * gone from the catalogue -> drop.
  ///
  /// Entries switched **on** are never touched — their URL, model and key stay
  /// exactly as the user left them, even when the catalogue marks them dead.
  /// The user's own choice also wins over the server copy, so a device that
  /// enabled something while offline does not lose it on the next sync.
  Future<List<AiProvider>> _reconcile(
    String userId,
    List<AiProvider> local,
    List<AiProvider> remote,
  ) async {
    final localById = <String, AiProvider>{
      for (final p in local) p.id: p,
    };

    final result = <AiProvider>[];
    final handled = <String>{};

    for (final remoteProvider in remote) {
      handled.add(remoteProvider.id);

      final localCopy = localById[remoteProvider.id];
      final isEnabled = localCopy?.enabled ?? remoteProvider.enabled;

      if (!isEnabled && remoteProvider.isDead) {
        continue;
      }

      var chosen = remoteProvider;
      if (isEnabled && localCopy != null) {
        chosen = localCopy;
      }

      final key = await _storage.readApiKey(
        userId: userId,
        providerId: chosen.id,
      );
      result.add(
        chosen.copyWith(
          enabled: isEnabled,
          apiKey: key,
          apiKeyExplicitlySet: true,
        ),
      );
    }

    // Switched-on entries are never dropped, not even when the catalogue no
    // longer lists them.
    for (final localCopy in local) {
      if (!localCopy.enabled || handled.contains(localCopy.id)) {
        continue;
      }
      final key = await _storage.readApiKey(
        userId: userId,
        providerId: localCopy.id,
      );
      result.add(
        localCopy.copyWith(apiKey: key, apiKeyExplicitlySet: true),
      );
    }

    result.sort(_compare);
    return result;
  }

  Future<void> _saveSnapshot(String userId, List<AiProvider> items) async {
    await _storage.writeValue(
      _snapshotPrefix + userId,
      jsonEncode(items.map((p) => p.toSyncJson()).toList()),
    );
  }

  Future<List<AiProvider>> _readSnapshot(String userId) async {
    final raw = await _storage.readValue(_snapshotPrefix + userId);
    if (raw == null || raw.isEmpty) {
      return const <AiProvider>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <AiProvider>[];
      final items = <AiProvider>[];
      for (final item in decoded) {
        if (item is Map) {
          items.add(AiProvider.fromJson(item.cast<String, dynamic>()));
        }
      }
      return await _attachKeys(userId, items);
    } catch (_) {
      return const <AiProvider>[];
    }
  }

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
