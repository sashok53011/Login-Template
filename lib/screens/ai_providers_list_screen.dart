import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../models/ai_provider.dart';
import '../models/ai_stats.dart';
import '../providers/ai_providers_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/provider_test_service.dart';

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
      return Scaffold(
        body: Center(child: Text(tr(ref, 'ai.requiresAuth'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'ai.title')),
        actions: <Widget>[
          IconButton(
            tooltip: tr(ref, 'ai.refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(aiProvidersProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(null),
        icon: const Icon(Icons.add),
        label: Text(tr(ref, 'ai.addProvider')),
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
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.error_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(aiProvidersProvider.notifier).refresh(),
                      child: Text(tr(ref, 'common.retry')),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: state.isLoading && state.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              tr(ref, 'ai.emptyList'),
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
                              testing: state.testing.contains(provider.id),
                              stats: state.statsFor(provider),
                              onToggle: (v) => ref
                                  .read(aiProvidersProvider.notifier)
                                  .toggle(provider.id, v),
                              onEditKey: () => _showApiKeyDialog(provider),
                              onTest: () => _runTest(provider),
                              onEdit: provider.mine
                                  ? () => _showEditor(provider)
                                  : null,
                              onDelete: provider.mine
                                  ? () => _confirmDelete(provider)
                                  : null,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String get _language => ref.read(settingsProvider).language;

  Future<void> _showApiKeyDialog(AiProvider provider) async {
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _ApiKeyDialog(provider: provider),
    );

    if (saved == null) return;
    // Saving a key also runs the test, which publishes the result.
    await ref.read(aiProvidersProvider.notifier).setApiKey(provider.id, saved);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(translate('ai.apiKeySaved', _language))),
    );
  }

  /// Creates a provider of the user's own, or edits one of their proposals.
  ///
  /// A new provider is sent to the administrator for review: it appears in
  /// their list marked with the author, and becomes visible to everyone only
  /// when an administrator publishes it.
  Future<void> _showEditor(AiProvider? provider) async {
    final changes = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ProviderEditorDialog(provider: provider),
    );
    if (changes == null) return;

    final notifier = ref.read(aiProvidersProvider.notifier);
    try {
      if (provider == null) {
        await notifier.add(
          AiProvider(
            id: 'p${DateTime.now().millisecondsSinceEpoch}',
            name: changes['name']?.toString() ?? '',
            enabled: true,
            url: changes['url']?.toString() ?? '',
            model: changes['model']?.toString() ?? '',
            fallbackPriority: changes['fallbackPriority'] is num
                ? (changes['fallbackPriority'] as num).toInt()
                : 0,
            loginUrl: _text(changes['loginUrl']),
            getApiKeyUrl: _text(changes['getApiKeyUrl']),
            logoUrl: _text(changes['logoUrl']),
            logoAsset: _text(changes['logoAsset']),
          ),
        );
      } else {
        await notifier.update(provider.id, changes);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            translate(
              provider == null ? 'ai.providerAdded' : 'ai.providerUpdated',
              _language,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            translate(
              'ai.errorPrefix',
              _language,
              args: <String, String>{
                'error': translate(_cleanError(e), _language),
              },
            ),
          ),
        ),
      );
    }
  }

  String? _text(dynamic value) {
    final s = value?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  Future<void> _confirmDelete(AiProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(translate('ai.deleteTitle', _language)),
        content: Text(
          translate(
            'ai.deleteConfirm',
            _language,
            args: <String, String>{'name': provider.name},
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(translate('common.cancel', _language)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(translate('common.delete', _language)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(aiProvidersProvider.notifier).delete(provider.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            translate(
              'ai.errorPrefix',
              _language,
              args: <String, String>{
                'error': translate(_cleanError(e), _language),
              },
            ),
          ),
        ),
      );
    }
  }

  /// Runs the provider test and shows either the model list or the reason it
  /// failed.
  Future<void> _runTest(AiProvider provider) async {
    final result =
        await ref.read(aiProvidersProvider.notifier).testProvider(provider.id);
    if (!mounted || result == null) return;

    if (!result.ok) {
      final key = result.error ?? 'ai.testFailed';
      final args = result.status != null
          ? <String, String>{'status': '${result.status}'}
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translate(key, _language, args: args))),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => _ModelsDialog(
        provider: provider,
        result: result,
      ),
    );
  }
}

/// Definition editor for the user's own providers. The shared catalogue is the
/// administrator's, so this is never reachable for their entries.
class _ProviderEditorDialog extends ConsumerStatefulWidget {
  const _ProviderEditorDialog({this.provider});

  final AiProvider? provider;

  @override
  ConsumerState<_ProviderEditorDialog> createState() =>
      _ProviderEditorDialogState();
}

class _ProviderEditorDialogState extends ConsumerState<_ProviderEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _model;
  late final TextEditingController _priority;
  late final TextEditingController _loginUrl;
  late final TextEditingController _getApiKeyUrl;
  late final TextEditingController _logoUrl;
  late final TextEditingController _logoAsset;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    final p = widget.provider;
    _name = TextEditingController(text: p?.name ?? '');
    _url = TextEditingController(text: p?.url ?? '');
    _model = TextEditingController(text: p?.model ?? '');
    _priority = TextEditingController(
      text: (p?.fallbackPriority ?? 0).toString(),
    );
    _loginUrl = TextEditingController(text: p?.loginUrl ?? '');
    _getApiKeyUrl = TextEditingController(text: p?.getApiKeyUrl ?? '');
    _logoUrl = TextEditingController(text: p?.logoUrl ?? '');
    _logoAsset = TextEditingController(text: p?.logoAsset ?? '');
    _enabled = p?.enabled ?? true;
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _name,
      _url,
      _model,
      _priority,
      _loginUrl,
      _getApiKeyUrl,
      _logoUrl,
      _logoAsset,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.provider == null;

    return AlertDialog(
      title: Text(
        tr(ref, isNew ? 'ai.newProvider' : 'ai.yourProvider'),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (isNew)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      tr(ref, 'ai.providerNewHint'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                _field(_name, tr(ref, 'ai.fieldName'), required: true),
                _field(_url, 'URL', required: true),
                _field(_model, 'Model', required: true),
                _field(_priority, tr(ref, 'ai.fieldPriority'), numeric: true),
                _field(_loginUrl, tr(ref, 'ai.fieldLoginUrl')),
                _field(_getApiKeyUrl, tr(ref, 'ai.fieldGetApiKeyUrl')),
                _field(_logoUrl, tr(ref, 'ai.fieldLogoUrl')),
                _field(_logoAsset, tr(ref, 'ai.fieldLogoAsset')),
                SwitchListTile(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  title: Text(tr(ref, 'ai.fieldEnabled')),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr(ref, 'common.cancel')),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(tr(ref, 'common.save')),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool numeric = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (!required) return null;
          return value == null || value.trim().isEmpty
              ? translate('valid.required', ref.read(settingsProvider).language)
              : null;
        },
      ),
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final priority = int.tryParse(_priority.text.trim()) ?? 0;

    Navigator.of(context).pop(<String, dynamic>{
      'name': _name.text.trim(),
      'url': _url.text.trim(),
      'model': _model.text.trim(),
      'fallbackPriority': priority < 0 ? 0 : priority,
      'enabled': _enabled,
      'loginUrl': _loginUrl.text.trim(),
      'getApiKeyUrl': _getApiKeyUrl.text.trim(),
      'logoUrl': _logoUrl.text.trim(),
      'logoAsset': _logoAsset.text.trim(),
    });
  }
}

/// Lets the user enter their own API key for a catalogue entry.
///
/// A stateful widget on purpose: it owns the controller, so the controller
/// cannot outlive the closing animation of the dialog.
class _ApiKeyDialog extends ConsumerStatefulWidget {
  const _ApiKeyDialog({required this.provider});

  final AiProvider provider;

  @override
  ConsumerState<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends ConsumerState<_ApiKeyDialog> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _obscure = true;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.provider.apiKey ?? '');
    _focusNode.addListener(_onFocusChanged);
  }

  /// The paste button only wakes up once the field is being edited, so a key
  /// cannot be dropped in by accident.
  void _onFocusChanged() {
    if (_focusNode.hasFocus != _focused) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';

    if (!mounted) return;

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            translate('ai.clipboardEmpty', ref.read(settingsProvider).language),
          ),
        ),
      );
      return;
    }

    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final language = ref.watch(settingsProvider).language;

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
              label: translate('ai.fieldPriority', language),
              value: provider.fallbackPriority.toString(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'API Key',
                helperText: translate('ai.apiKeyHint', language),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: translate(
                    _obscure ? 'ai.show' : 'ai.hide',
                    language,
                  ),
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: _focused ? _pasteFromClipboard : null,
                  icon: const Icon(Icons.content_paste),
                  label: Text(translate('ai.paste', language)),
                ),
                TextButton.icon(
                  onPressed: _controller.text.isEmpty
                      ? null
                      : () {
                          setState(() {
                            _controller.clear();
                          });
                        },
                  icon: const Icon(Icons.clear),
                  label: Text(translate('ai.clear', language)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              translate('ai.apiKeyNote', language),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(translate('common.cancel', language)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(translate('common.save', language)),
        ),
      ],
    );
  }
}

/// Explains where the list comes from and offers the manual refresh.
class _CatalogueCard extends ConsumerWidget {
  const _CatalogueCard({
    required this.state,
    required this.onSyncNow,
    required this.onToggleSync,
  });

  final AiProvidersState state;
  final VoidCallback onSyncNow;
  final ValueChanged<bool> onToggleSync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final language = ref.watch(settingsProvider).language;

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
                    translate('ai.catalogueTitle', language),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Switch(value: state.syncEnabled, onChanged: onToggleSync),
              ],
            ),
            Text(
              translate(
                state.syncEnabled ? 'ai.syncOnDesc' : 'ai.syncOffDesc',
                language,
              ),
              style: theme.textTheme.bodySmall,
            ),
            if (state.syncEnabled && state.syncedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  translate(
                    'ai.catalogueUpdated',
                    language,
                    args: <String, String>{
                      'time': _formatTime(state.syncedAt!),
                    },
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            Wrap(
              spacing: 8,
              children: <Widget>[
                TextButton.icon(
                  onPressed: state.syncEnabled ? onSyncNow : null,
                  icon: const Icon(Icons.sync),
                  label: Text(translate('ai.syncNow', language)),
                ),
                TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse('${AppConfig.baseUrl}/ai-providers/'),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(translate('ai.webVersion', language)),
                ),
              ],
            ),
            Text(
              translate('ai.keysStayLocal', language),
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

class _ProviderCard extends ConsumerWidget {
  const _ProviderCard({
    required this.provider,
    required this.onToggle,
    required this.onEditKey,
    required this.onTest,
    this.testing = false,
    this.stats,
    this.onEdit,
    this.onDelete,
  });

  final AiProvider provider;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEditKey;
  final VoidCallback onTest;

  /// Set only for the user's own providers.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// True while this provider's test is running.
  final bool testing;

  /// Statistics of the provider's configured model.
  final ModelStats? stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final language = ref.watch(settingsProvider).language;

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
                          if (provider.isProposal)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                translate('ai.badgeMine', language),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer,
                                ),
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
                                translate('ai.badgeDead', language),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        translate(
                          'ai.priority',
                          language,
                          args: <String, String>{
                            'n': '${provider.fallbackPriority}',
                          },
                        ),
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
            _InfoLine(
              label: 'Model',
              value: provider.model,
              trailing: _statsLabel(stats),
            ),
            _InfoLine(
              label: 'API Key',
              value: provider.apiKey?.isNotEmpty == true
                  ? '••••••••'
                  : translate('ai.keyNotSet', language),
              trailing: provider.apiKey?.isNotEmpty == true
                  ? null
                  : translate('ai.keyEnter', language),
              onTap: onEditKey,
            ),
            if (provider.isDead)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  translate('ai.deadHint', language),
                  style: theme.textTheme.bodySmall,
                ),
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
                    label: Text(translate('ai.loginPage', language)),
                  ),
                if (_hasUrl(provider.getApiKeyUrl))
                  TextButton.icon(
                    onPressed: () => _launchUrl(provider.getApiKeyUrl!),
                    icon: const Icon(Icons.vpn_key),
                    label: Text(translate('ai.getApiKey', language)),
                  ),
                TextButton.icon(
                  onPressed: onEditKey,
                  icon: const Icon(Icons.key),
                  label: Text(translate('ai.enterKey', language)),
                ),
                TextButton.icon(
                  onPressed:
                      provider.isDead || testing ? null : onTest,
                  icon: testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    translate(
                      testing ? 'common.checking' : 'ai.testAndModels',
                      language,
                    ),
                  ),
                ),
                if (onEdit != null)
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                    label: Text(translate('ai.edit', language)),
                  ),
                if (onDelete != null)
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(translate('common.delete', language)),
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

/// `5 (2) · 12.10 21:15` — users who succeeded, users with errors, last report.
String? _statsLabel(ModelStats? stats) {
  if (stats == null || !stats.hasData) return null;

  String two(int n) => n.toString().padLeft(2, '0');
  final at = stats.last;
  final when = at == null
      ? ''
      : ' · ${two(at.day)}.${two(at.month)} ${two(at.hour)}:${two(at.minute)}';

  return '${stats.usersLabel}$when';
}

/// Drops the `Exception: ` prefix so error texts read naturally.
String _cleanError(Object error) {
  final text = error.toString();
  const prefix = 'Exception: ';
  return text.startsWith(prefix) ? text.substring(prefix.length) : text;
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String value;

  /// Optional muted suffix, e.g. the usage counters of a model.
  final String? trailing;

  /// Makes the whole row tappable, used for the API key line.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Flexible(
                  child: Text(
                    value,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      trailing!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// Shows the models the provider reported, with the usage counters collected
/// from every user's tests.
class _ModelsDialog extends ConsumerWidget {
  const _ModelsDialog({required this.provider, required this.result});

  final AiProvider provider;
  final ProviderTestResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(aiProvidersProvider).stats[provider.id];
    final language = ref.watch(settingsProvider).language;

    return AlertDialog(
      title: Text(
        translate(
          'ai.modelsTitle',
          language,
          args: <String, String>{'name': provider.name},
        ),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _InfoLine(
                label: translate('ai.fieldAddress', language),
                value: result.endpoint,
              ),
              _InfoLine(
                label: translate('ai.fieldConfigured', language),
                value: provider.model,
                trailing: result.offersModel(provider.model)
                    ? translate('ai.modelInList', language)
                    : translate('ai.modelNotInList', language),
              ),
              const Divider(height: 20),
              Text(
                translate(
                  'ai.modelsFound',
                  language,
                  args: <String, String>{'n': '${result.models.length}'},
                ),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(
                translate('ai.modelsHint', language),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              ...result.models.map((String model) {
                final modelStats = stats?.forModel(model);
                final isConfigured = model == provider.model;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          model,
                          style: TextStyle(
                            fontWeight:
                                isConfigured ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      Text(
                        _statsLabel(modelStats) ??
                            translate('ai.noData', language),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: modelStats == null
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(translate('common.close', language)),
        ),
      ],
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
