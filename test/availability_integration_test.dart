import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/services/api_client.dart';
import 'package:login_app/services/auth_service.dart';
import 'package:login_app/services/secure_storage_service.dart';

/// Runs the very same call the registration form makes when the email field
/// loses focus, against the production PocketBase.
///
/// Deliberately NOT mocked: this reproduces what the phone sees. It needs the
/// server to be reachable, so it is opt-in:
///
/// ```
/// flutter test test\availability_integration_test.dart --dart-define=PB_LIVE=true
/// ```
///
/// The `result-probe@test.devhorizon.online` account must exist on the server.
void main() {
  const bool live = bool.fromEnvironment('PB_LIVE');

  test(
    'isValueTaken against the production server',
    () async {
      final api = ApiClient();
      final service = AuthService(api, SecureStorageService());

      final stamp = DateTime.now().microsecondsSinceEpoch;
      final free = await service.isValueTaken('probe-$stamp@example.com');
      // ignore: avoid_print
      print('free  -> $free');
      expect(free, isFalse);

      final taken =
          await service.isValueTaken('result-probe@test.devhorizon.online');
      // ignore: avoid_print
      print('taken -> $taken');
      expect(taken, isTrue);
    },
    skip: live
        ? false
        : 'live check: run with --dart-define=PB_LIVE=true '
            '(requires the PocketBase server to be up)',
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
