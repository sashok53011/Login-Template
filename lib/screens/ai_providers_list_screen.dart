import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../models/ai_provider.dart';
import '../providers/ai_providers_provider.dart';
import '../providers/auth_provider.dart';

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
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(aiProvidersProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Добавить провайдера'),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _SyncCard(
              state: state,
              onToggle: (bool value) =>
                  ref.read(aiProvidersProvider.notifier).setSyncEnabled(value),
              onSyncNow: () => ref.read(aiProvidersProvider.notifier).syncNow(),
            ),
            Expanded(
              child: state.isLoading && state.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.items.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Список пуст. Нажмите «Добавить провайдера» для добавления.',
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
                              onEdit: () => _showEditor(context, provider),
                              onDelete: () => _confirmDelete(context, provider),
                              onToggle: (v) => ref
                                  .read(aiProvidersProvider.notifier)
                                  .toggle(provider.id, v),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditor(BuildContext context, AiProvider? provider) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProviderEditorSheet(provider: provider),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AiProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить провайдера?'),
        content: Text('Будет удалён: ${provider.name}'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(aiProvidersProvider.notifier).delete(provider.id);
      if (!mounted) return;
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Провайдер удалён')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }
}

/// Explains and controls where the list lives: the account's PocketBase
/// collection, or the shared JSON file that also backs the web page at
/// https://app.devhorizon.online/ai-providers/
class _SyncCard extends StatelessWidget {
  const _SyncCard({
    required this.state,
    required this.onToggle,
    required this.onSyncNow,
  });

  final AiProvidersState state;
  final ValueChanged<bool> onToggle;
  final VoidCallback onSyncNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SwitchListTile(
            value: state.syncEnabled,
            onChanged: onToggle,
            title: const Text('Синхронизация с сервером'),
            subtitle: Text(_subtitle()),
          ),
          if (state.syncEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Список общий с веб-страницей app.devhorizon.online. '
                    'API-ключи остаются на этом устройстве и на сервер не отправляются.',
                    style: theme.textTheme.bodySmall,
                  ),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: onSyncNow,
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
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _subtitle() {
    if (!state.syncEnabled) {
      return 'Выключена. Список хранится в вашем аккаунте.';
    }
    final at = state.syncedAt;
    if (at == null) {
      return 'Включена. На сервере ещё нет сохранённой версии.';
    }
    return 'Включена. Обновлено: ${_formatTime(at)}';
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
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final AiProvider provider;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Logo(provider: provider, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Приоритет: ${provider.fallbackPriority}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: provider.enabled,
                  onChanged: onToggle,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(label: 'URL', value: provider.url),
            _InfoRow(label: 'Model', value: provider.model),
            _InfoRow(
              label: 'API Key',
              value: provider.apiKey?.isNotEmpty == true ? '••••••••' : '(не задан)',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
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
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Редактировать'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Удалить'),
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
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
      final asset = 'assets/logos/${provider.logoAsset}.svg';
      return SvgPicture.asset(
        asset,
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

class _ProviderEditorSheet extends ConsumerStatefulWidget {
  const _ProviderEditorSheet({this.provider});

  final AiProvider? provider;

  @override
  ConsumerState<_ProviderEditorSheet> createState() =>
      _ProviderEditorSheetState();
}

class _ProviderEditorSheetState extends ConsumerState<_ProviderEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _priorityCtrl = TextEditingController();
  final _loginUrlCtrl = TextEditingController();
  final _getApiKeyCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  final _logoAssetCtrl = TextEditingController();
  bool _enabled = false;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    final p = widget.provider;
    if (p != null) {
      _nameCtrl.text = p.name;
      _urlCtrl.text = p.url;
      _modelCtrl.text = p.model;
      _apiKeyCtrl.text = p.apiKey ?? '';
      _priorityCtrl.text = p.fallbackPriority.toString();
      _loginUrlCtrl.text = p.loginUrl ?? '';
      _getApiKeyCtrl.text = p.getApiKeyUrl ?? '';
      _logoUrlCtrl.text = p.logoUrl ?? '';
      _logoAssetCtrl.text = p.logoAsset ?? '';
      _enabled = p.enabled;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _modelCtrl.dispose();
    _apiKeyCtrl.dispose();
    _priorityCtrl.dispose();
    _loginUrlCtrl.dispose();
    _getApiKeyCtrl.dispose();
    _logoUrlCtrl.dispose();
    _logoAssetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.provider != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'Редактировать провайдера' : 'Добавить провайдера',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Название'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Обязательное поле' : null,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Включён'),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
              TextFormField(
                controller: _urlCtrl,
                decoration: const InputDecoration(labelText: 'URL'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Обязательное поле' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _modelCtrl,
                decoration: const InputDecoration(labelText: 'Model'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Обязательное поле' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _apiKeyCtrl,
                obscureText: _obscureApiKey,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscureApiKey = !_obscureApiKey),
                  ),
                ),
                validator: (v) {
                  if (isEditing && (v == null || v.isEmpty)) return null;
                  if (!isEditing && (v == null || v.trim().isEmpty)) {
                    return 'Обязательное поле';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priorityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Приоритет (fallback)'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Обязательное поле';
                  final n = int.tryParse(v);
                  if (n == null || n < 0) return 'Минимум 0';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _loginUrlCtrl,
                decoration: const InputDecoration(labelText: 'Страница логина (URL)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _getApiKeyCtrl,
                decoration: const InputDecoration(labelText: 'Получить API-ключ (URL)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _logoUrlCtrl,
                decoration: const InputDecoration(labelText: 'logoUrl (ссылка на логотип)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _logoAssetCtrl,
                decoration: const InputDecoration(labelText: 'logoAsset (имя файла без .svg) из assets/logos'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(aiProvidersProvider.notifier);
    final p = widget.provider;
    final priority = int.parse(_priorityCtrl.text.trim());

    if (p == null) {
      final newProvider = AiProvider(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameCtrl.text.trim(),
        enabled: _enabled,
        url: _urlCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        apiKey: _apiKeyCtrl.text.trim(),
        fallbackPriority: priority,
        loginUrl: _loginUrlCtrl.text.trim().isEmpty
            ? null
            : _loginUrlCtrl.text.trim(),
        getApiKeyUrl: _getApiKeyCtrl.text.trim().isEmpty
            ? null
            : _getApiKeyCtrl.text.trim(),
        logoUrl: _logoUrlCtrl.text.trim().isEmpty
            ? null
            : _logoUrlCtrl.text.trim(),
        logoAsset: _logoAssetCtrl.text.trim().isEmpty
            ? null
            : _logoAssetCtrl.text.trim(),
        isPredefined: false,
      );
      try {
        await notifier.add(newProvider);
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
        }
      }
      return;
    }

    final changes = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'enabled': _enabled,
      'url': _urlCtrl.text.trim(),
      'model': _modelCtrl.text.trim(),
      'fallbackPriority': priority,
    };
    if (_apiKeyCtrl.text.trim().isNotEmpty) {
      changes['api_key'] = _apiKeyCtrl.text.trim();
    }
    if (_loginUrlCtrl.text.trim().isEmpty) {
      changes['loginUrl'] = null;
    } else {
      changes['loginUrl'] = _loginUrlCtrl.text.trim();
    }
    if (_getApiKeyCtrl.text.trim().isEmpty) {
      changes['getApiKeyUrl'] = null;
    } else {
      changes['getApiKeyUrl'] = _getApiKeyCtrl.text.trim();
    }
    if (_logoUrlCtrl.text.trim().isEmpty) {
      changes['logoUrl'] = null;
    } else {
      changes['logoUrl'] = _logoUrlCtrl.text.trim();
    }
    if (_logoAssetCtrl.text.trim().isEmpty) {
      changes['logoAsset'] = null;
    } else {
      changes['logoAsset'] = _logoAssetCtrl.text.trim();
    }

    try {
      await notifier.update(p.id, changes);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }
}
