import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../models/ai_provider.dart';
import '../providers/ai_providers_provider.dart';
import '../providers/auth_provider.dart';

/// The provider catalogue comes from the server and is maintained by a
/// PocketBase superuser. A regular user can only switch entries on and off and
/// store their own API keys on the device, so this screen has no add, edit or
/// delete for provider definitions.
class AiProvidersListScreen extends ConsumerStatefulWidget {
  const AiProvidersListScreen({super.key});

  @override
  ConsumerState<AiProvidersListScreen> createState() =>
      _AiProvidersListScreenState();
}

class _AiProvidersListScreenState extends ConsumerState<AiProvidersListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(aiProvidersProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final state = ref.watch(aiProvidersProvider);

    if (!auth.isLoggedIn) {
      return const Scaffold(
        body: Center(child: Text('Требуется авторизация')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI-провайдеры'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(aiProvidersProvider.notifier).refresh(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _CatalogueCard(
              state: state,
              onSyncNow: () => ref.read(aiProvidersProvider.notifier).syncNow(),
              onToggleSync: (bool value) =>
                  ref.read(aiProvidersProvider.notifier).setSyncEnabled(value),
            ),
            Expanded(
              child: state.isLoading && state.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.items.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Список пуст. Каталог провайдеров заполняет '
                              'администратор.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: state.items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final provider = state.items[index];
                            return _ProviderCard(
                              provider: provider,
                              onToggle: (v) => ref
                                  .read(aiProvidersProvider.notifier)
                                  .toggle(provider.id, v),
                              onEditKey: () => _showApiKeyDialog(provider),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showApiKeyDialog(AiProvider provider) async {
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _ApiKeyDialog(provider: provider),
    );

    if (saved == null) return;
    await ref.read(aiProvidersProvider.notifier).setApiKey(provider.id, saved);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API-ключ сохранён на устройстве')),
    );
  }
}

/// Lets the user enter their own API key for a catalogue entry.
///
/// A stateful widget on purpose: it owns the controller, so the controller
/// cannot outlive the closing animation of the dialog.
class _ApiKeyDialog extends StatefulWidget {
  const _ApiKeyDialog({required this.provider});

  final AiProvider provider;

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  late final TextEditingController _controller;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.provider.apiKey ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return AlertDialog(
      title: Text(provider.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _InfoLine(label: 'URL', value: provider.url),
            _InfoLine(label: 'Model', value: provider.model),
            _InfoLine(
              label: 'Приоритет',
              value: provider.fallbackPriority.toString(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              obscureText: _obscure,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'API Key',
                helperText: 'Хранится только на этом устройстве',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Сам провайдер и его адрес задаются администратором.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

/// Explains where the list comes from and offers the manual refresh.
class _CatalogueCard extends StatelessWidget {
  const _CatalogueCard({
    required this.state,
    required this.onSyncNow,
    required this.onToggleSync,
  });

  final AiProvidersState state;
  final VoidCallback onSyncNow;
  final ValueChanged<bool> onToggleSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.cloud_sync, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Каталог провайдеров ведёт администратор',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Switch(value: state.syncEnabled, onChanged: onToggleSync),
              ],
            ),
            Text(
              state.syncEnabled
                  ? 'Выключенные провайдеры сверяются с каталогом: если '
                      'провайдер помечен как неработающий, он убирается из '
                      'списка. Включённые не трогаются.'
                  : 'Синхронизация выключена: показан последний сохранённый '
                      'список, изменения с сервера не подхватываются.',
              style: theme.textTheme.bodySmall,
            ),
            if (state.syncEnabled && state.syncedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Каталог обновлён: ${_formatTime(state.syncedAt!)}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            Wrap(
              spacing: 8,
              children: <Widget>[
                TextButton.icon(
                  onPressed: state.syncEnabled ? onSyncNow : null,
                  icon: const Icon(Icons.sync),
                  label: const Text('Синхронизировать сейчас'),
                ),
                TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse('${AppConfig.baseUrl}/ai-providers/'),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Веб-версия'),
                ),
              ],
            ),
            Text(
              'API-ключи остаются на этом устройстве и на сервер не '
              'отправляются.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.onToggle,
    required this.onEditKey,
  });

  final AiProvider provider;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEditKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _Logo(provider: provider, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              provider.name,
                              style: theme.textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (provider.isDead)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'не работает',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        'Приоритет: ${provider.fallbackPriority}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(value: provider.enabled, onChanged: onToggle),
              ],
            ),
            const SizedBox(height: 8),
            _InfoLine(label: 'URL', value: provider.url),
            _InfoLine(label: 'Model', value: provider.model),
            _InfoLine(
              label: 'API Key',
              value: provider.apiKey?.isNotEmpty == true
                  ? '••••••••'
                  : '(не задан)',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (_hasUrl(provider.loginUrl))
                  TextButton.icon(
                    onPressed: () => _launchUrl(provider.loginUrl!),
                    icon: const Icon(Icons.login),
                    label: const Text('Страница логина'),
                  ),
                if (_hasUrl(provider.getApiKeyUrl))
                  TextButton.icon(
                    onPressed: () => _launchUrl(provider.getApiKeyUrl!),
                    icon: const Icon(Icons.vpn_key),
                    label: const Text('Получить API-ключ'),
                  ),
                TextButton.icon(
                  onPressed: onEditKey,
                  icon: const Icon(Icons.key),
                  label: const Text('Ввести ключ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _hasUrl(String? u) => u != null && u.trim().isNotEmpty;

  Future<void> _launchUrl(String url) async {
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.provider, this.size = 36});

  final AiProvider provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (provider.logoUrl != null && provider.logoUrl!.trim().isNotEmpty) {
      return Image.network(
        provider.logoUrl!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    if (provider.logoAsset != null && provider.logoAsset!.trim().isNotEmpty) {
      return SvgPicture.asset(
        'assets/logos/${provider.logoAsset}.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.smart_toy_outlined),
    );
  }
}
