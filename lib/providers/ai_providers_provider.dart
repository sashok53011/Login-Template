import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_provider.dart';
import '../services/ai_providers_service.dart';
import 'auth_provider.dart';

// The secure storage instance is shared with the auth layer so that a single
// override in tests (and a single keystore on device) serves both.
final aiProvidersServiceProvider = Provider<AiProvidersService>((ref) {
  return AiProvidersService(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  );
});

class AiProvidersState {
  const AiProvidersState({
    this.items = const <AiProvider>[],
    this.isLoading = false,
    this.error,
  });

  final List<AiProvider> items;
  final bool isLoading;
  final String? error;

  AiProvidersState copyWith({
    List<AiProvider>? items,
    bool? isLoading,
    String? error,
  }) {
    return AiProvidersState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AiProvidersNotifier extends StateNotifier<AiProvidersState> {
  AiProvidersNotifier(this._ref) : super(const AiProvidersState());

  final Ref _ref;

  AiProvidersService get _service => _ref.read(aiProvidersServiceProvider);
  String? get _userId {
    final auth = _ref.read(authProvider);
    return auth.user?.id;
  }

  Future<void> load() async {
    final userId = _userId;
    if (userId == null) {
      state = state.copyWith(items: const <AiProvider>[], isLoading: false);
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _service.list(userId: userId);
      state = state.copyWith(items: list, isLoading: false);
      if (list.isEmpty) {
        await _ensurePredefined(userId);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await load();
  }

  Future<void> add(AiProvider provider) async {
    final userId = _userId;
    if (userId == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final created = await _service.create(provider.copyWith(userId: userId));
      final newList = [...state.items, created]..sort(_compare);
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
      await _service.delete(id, userId: userId);
      final newList = state.items.where((p) => p.id != id).toList()
        ..sort(_compare);
      state = state.copyWith(items: newList, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
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
