import '../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';

void main() {
  group('SecureStorageService access token', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('a remembered token is saved to storage', () async {
      final service = SecureStorageService();

      await service.saveAccessToken('token-1');

      expect(await service.getAccessToken(), 'token-1');
      // A new service reads the same storage, like the next app launch.
      expect(await SecureStorageService().getAccessToken(), 'token-1');
    });

    test('a token that is not remembered lasts for this run only', () async {
      final service = SecureStorageService();

      await service.saveAccessToken('token-1', persist: false);

      expect(await service.getAccessToken(), 'token-1');
      expect(await SecureStorageService().getAccessToken(), isNull);
    });

    test('not remembering replaces a token saved earlier', () async {
      final service = SecureStorageService();
      await service.saveAccessToken('old-token');

      await service.saveAccessToken('new-token', persist: false);

      expect(await service.getAccessToken(), 'new-token');
      expect(await SecureStorageService().getAccessToken(), isNull);
    });

    test('deleting clears the in-memory token too', () async {
      final service = SecureStorageService();
      await service.saveAccessToken('token-1', persist: false);

      await service.deleteAccessToken();

      expect(await service.getAccessToken(), isNull);
    });
  });
}
