/// Test statistics for one model of one provider.
class ModelStats {
  const ModelStats({
    required this.model,
    this.ok = 0,
    this.fail = 0,
    this.usersOk = 0,
    this.usersFail = 0,
    this.last,
    this.lastStatus = '',
    this.lastError = '',
  });

  final String model;

  /// Successful and failed attempts in total.
  final int ok;
  final int fail;

  /// How many distinct users had at least one success / failure.
  final int usersOk;
  final int usersFail;

  final DateTime? last;
  final String lastStatus;
  final String lastError;

  bool get hasData => ok > 0 || fail > 0;

  /// `5 (2)` — five users succeeded, two ran into an error.
  String get usersLabel => usersFail > 0 ? '$usersOk ($usersFail)' : '$usersOk';

  factory ModelStats.fromJson(String model, Map<String, dynamic> json) {
    return ModelStats(
      model: model,
      ok: _toInt(json['ok']),
      fail: _toInt(json['fail']),
      usersOk: _toInt(json['usersOk']),
      usersFail: _toInt(json['usersFail']),
      last: _parseDate(json['last']),
      lastStatus: json['lastStatus']?.toString() ?? '',
      lastError: json['lastError']?.toString() ?? '',
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}

/// Statistics of one provider, keyed by model id.
class ProviderStats {
  const ProviderStats({
    required this.providerId,
    this.updated,
    this.models = const <String, ModelStats>{},
  });

  final String providerId;
  final DateTime? updated;
  final Map<String, ModelStats> models;

  ModelStats? forModel(String? model) {
    if (model == null || model.isEmpty) return null;
    return models[model];
  }

  factory ProviderStats.fromJson(String providerId, Map<String, dynamic> json) {
    final raw = json['models'];
    final models = <String, ModelStats>{};
    if (raw is Map) {
      raw.forEach((dynamic key, dynamic value) {
        if (value is Map) {
          models[key.toString()] =
              ModelStats.fromJson(key.toString(), value.cast<String, dynamic>());
        }
      });
    }
    return ProviderStats(
      providerId: providerId,
      updated: ModelStats._parseDate(json['updated']),
      models: models,
    );
  }
}
