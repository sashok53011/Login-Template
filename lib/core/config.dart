/// Global application configuration.
class AppConfig {
  AppConfig._();

  /// PocketBase instance reachable through the Cloudflare Tunnel.
  static const String baseUrl = 'https://app.devhorizon.online';

  /// Auth-enabled collection used for register / login.
  static const String usersCollection = 'users';
}
