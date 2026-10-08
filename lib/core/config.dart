/// Global application configuration.
class AppConfig {
  AppConfig._();

  /// PocketBase instance reachable through the Cloudflare Tunnel.
  static const String baseUrl = 'https://app.devhorizon.online';

  /// Auth-enabled collection used for register / login.
  static const String usersCollection = 'users';

  /// Must match the secret used in the collection List/Search API rule:
  /// `@request.query.k = 'pb_av_1' && (email = ... || name = ...)`
  static const String availabilityKey = 'pb_av_1';

  /// Query parameter that carries the value being looked up.
  static const String availabilityQuery = 'q';
}
