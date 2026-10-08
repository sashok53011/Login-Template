/// Global application configuration.
class AppConfig {
  AppConfig._();

  /// PocketBase instance reachable through the Cloudflare Tunnel.
  static const String baseUrl = 'https://app.devhorizon.online';

  /// Auth-enabled collection used for register / login.
  static const String usersCollection = 'users';

  /// Query parameter NAME used by the availability check: `...?k=pb_av_1&q=`.
  ///
  /// Must stay in sync with the `k` on the left side of the collection
  /// List/Search API rule.
  static const String availabilityParam = 'k';

  /// Secret VALUE that has to accompany [availabilityParam]; the rule checks
  /// `@request.query.k = 'pb_av_1'`.
  static const String availabilitySecret = 'pb_av_1';

  /// Query parameter that carries the value being looked up.
  static const String availabilityQuery = 'q';
}
