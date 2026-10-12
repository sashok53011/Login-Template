import 'ai_provider.dart';

/// The per-user configuration document shared with the web page.
///
/// It is stored on the server as
/// `<pb_data>/ai-config/<userId>.json` and is deliberately free of secrets:
/// API keys stay on the device.
class AiConfig {
  const AiConfig({
    this.version = 2,
    this.updated,
    this.canEdit = false,
    this.providers = const <AiProvider>[],
  });

  final int version;
  final DateTime? updated;

  /// True only for a PocketBase superuser: provider definitions may then be
  /// changed. The app never gets this, it only toggles entries on and off.
  final bool canEdit;

  final List<AiProvider> providers;

  factory AiConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['providers'];
    final providers = <AiProvider>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          providers.add(AiProvider.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return AiConfig(
      version: json['version'] is int ? json['version'] as int : 2,
      updated: _parseDate(json['updated']),
      canEdit: json['canEdit'] == true,
      providers: providers,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'providers': providers.map((p) => p.toSyncJson()).toList(),
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}
