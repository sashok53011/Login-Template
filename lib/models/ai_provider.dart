import 'package:equatable/equatable.dart';

/// Model representing an AI provider configuration stored in PocketBase.
class AiProvider extends Equatable {
  const AiProvider({
    required this.id,
    this.userId,
    required this.name,
    required this.enabled,
    required this.url,
    required this.model,
    this.apiKey,
    this.fallbackPriority = 0,
    this.loginUrl,
    this.getApiKeyUrl,
    this.logoUrl,
    this.logoAsset,
    this.isPredefined = false,
    this.status = 'active',
    this.origin = 'admin',
    this.authorName = '',
    this.mine = false,
  });

  final String id;
  final String? userId;
  final String name;
  final bool enabled;
  final String url;
  final String model;
  final String? apiKey;
  final int fallbackPriority;
  final String? loginUrl;
  final String? getApiKeyUrl;
  final String? logoUrl;
  final String? logoAsset;
  final bool isPredefined;

  /// `active` or `dead`. Only the catalogue owner (a PocketBase superuser)
  /// sets this; a dead entry is removed from a user's list while it is off.
  final String status;

  /// `admin` for an entry the administrator published to everyone, `user` for
  /// a proposal that only its author and the administrator can see.
  final String origin;

  /// Name of the user who proposed the entry (empty for the administrator's).
  final String authorName;

  /// True when this entry is the current user's own proposal, i.e. the one
  /// they may edit or delete.
  final bool mine;

  bool get isDead => status == 'dead';

  /// Switched off for everybody by the administrator. Such an entry is hidden
  /// from users who have it off, and listed with a mark for those who still
  /// have it on, so they can turn it off.
  bool get isDisabledForAll => status == 'disabled_for_all';

  bool get isProposal => origin == 'user';

  factory AiProvider.fromJson(Map<String, dynamic> json) {
    return AiProvider(
      id: json['id']?.toString() ?? '',
      userId: _readRelation(json, 'user'),
      name: json['name']?.toString() ?? '',
      enabled: json['enabled'] == true,
      url: json['url']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      apiKey: json['api_key']?.toString(),
      fallbackPriority: _toInt(json['fallbackPriority']),
      loginUrl: json['loginUrl']?.toString(),
      getApiKeyUrl: json['getApiKeyUrl']?.toString(),
      logoUrl: json['logoUrl']?.toString(),
      logoAsset: json['logoAsset']?.toString(),
      isPredefined: json['isPredefined'] == true,
      status: json['status']?.toString() ?? 'active',
      origin: json['origin']?.toString() ?? 'admin',
      authorName: json['authorName']?.toString() ?? '',
      mine: json['mine'] == true,
    );
  }

  static String? _readRelation(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) return value;
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is String) return first;
      if (first is Map && first['id'] is String) return first['id'] as String;
    }
    if (value is Map && value['id'] is String) return value['id'] as String;
    return value.toString();
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'enabled': enabled,
      'url': url,
      'model': model,
      if (apiKey != null && apiKey!.isNotEmpty) 'api_key': apiKey,
      'fallbackPriority': fallbackPriority,
      if (loginUrl != null && loginUrl!.isNotEmpty) 'loginUrl': loginUrl,
      if (getApiKeyUrl != null && getApiKeyUrl!.isNotEmpty)
        'getApiKeyUrl': getApiKeyUrl,
      if (logoUrl != null && logoUrl!.isNotEmpty) 'logoUrl': logoUrl,
      if (logoAsset != null && logoAsset!.isNotEmpty) 'logoAsset': logoAsset,
      'isPredefined': isPredefined,
      if (userId != null) 'user': userId,
    };
  }

  /// Convert to JSON for PocketBase (excludes secrets).
  Map<String, dynamic> toJsonForPocketBase() {
    return <String, dynamic>{
      'name': name,
      'enabled': enabled,
      'url': url,
      'model': model,
      'fallbackPriority': fallbackPriority,
      if (loginUrl != null && loginUrl!.isNotEmpty) 'loginUrl': loginUrl,
      if (getApiKeyUrl != null && getApiKeyUrl!.isNotEmpty)
        'getApiKeyUrl': getApiKeyUrl,
      if (logoUrl != null && logoUrl!.isNotEmpty) 'logoUrl': logoUrl,
      if (logoAsset != null && logoAsset!.isNotEmpty) 'logoAsset': logoAsset,
      'isPredefined': isPredefined,
      if (userId != null) 'user': userId,
    };
  }

  /// Payload for the shared server-side config (`/api/ai-config`).
  ///
  /// The server keeps only the `enabled` flags for a regular user and ignores
  /// every other field, because the catalogue is owned by a superuser.
  Map<String, dynamic> toSyncJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'enabled': enabled,
      'url': url,
      'model': model,
      'fallbackPriority': fallbackPriority,
      'loginUrl': loginUrl ?? '',
      'getApiKeyUrl': getApiKeyUrl ?? '',
      'logoUrl': logoUrl ?? '',
      'logoAsset': logoAsset ?? '',
      'isPredefined': isPredefined,
      'status': status,
      'origin': origin,
      'authorName': authorName,
    };
  }

  AiProvider copyWith({
    String? id,
    String? userId,
    String? name,
    bool? enabled,
    String? url,
    String? model,
    String? apiKey,
    bool apiKeyExplicitlySet = false,
    int? fallbackPriority,
    String? loginUrl,
    String? getApiKeyUrl,
    String? logoUrl,
    String? logoAsset,
    bool? isPredefined,
    String? status,
    String? origin,
    String? authorName,
    bool? mine,
  }) {
    return AiProvider(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      url: url ?? this.url,
      model: model ?? this.model,
      apiKey: apiKeyExplicitlySet ? apiKey : (apiKey ?? this.apiKey),
      fallbackPriority: fallbackPriority ?? this.fallbackPriority,
      loginUrl: loginUrl ?? this.loginUrl,
      getApiKeyUrl: getApiKeyUrl ?? this.getApiKeyUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      logoAsset: logoAsset ?? this.logoAsset,
      isPredefined: isPredefined ?? this.isPredefined,
      status: status ?? this.status,
      origin: origin ?? this.origin,
      authorName: authorName ?? this.authorName,
      mine: mine ?? this.mine,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        userId,
        name,
        enabled,
        url,
        model,
        apiKey,
        fallbackPriority,
        loginUrl,
        getApiKeyUrl,
        logoUrl,
        logoAsset,
        isPredefined,
        status,
        origin,
        authorName,
        mine,
      ];
}
