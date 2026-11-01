import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

void main() {
  group('AppConfig googleClientId defaults', () {
    setUpAll(() {
      // Mirror an empty/absent `.env` value so fromEnvironment can read
      // dotenv keys and still fall through to the built-in default.
      dotenv.loadFromString(envString: 'GOOGLE_CLIENT_ID=');
    });

    test(
      'constructor default and fromEnvironment fallback are the same id',
      () {
        const direct = AppConfig(
          apiBaseUrl: 'https://example.com/',
          usesMockData: false,
        );
        final viaEnvironment = AppConfig.fromEnvironment();

        expect(direct.googleClientId, kDefaultDesktopGoogleClientId);
        expect(
          viaEnvironment.googleClientId,
          direct.googleClientId,
          reason:
              'AppConfig() and AppConfig.fromEnvironment() must resolve to '
              'the same default desktop Google client id',
        );
      },
    );
  });
}
