import 'dart:io';

import '../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';

void main() {
  test('HTTP defaults bound connection, sending and receiving', () {
    final options = ApiBaseService.createOptions('http://localhost/api/v1/');

    expect(options.baseUrl, 'http://localhost/api/v1/');
    expect(options.connectTimeout, const Duration(seconds: 15));
    expect(options.sendTimeout, const Duration(seconds: 30));
    expect(options.receiveTimeout, const Duration(seconds: 30));
  });

  group('HTTP requests', () {
    late HttpServer server;
    late String baseUrl;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUrl = 'http://127.0.0.1:${server.port}/';
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('fallback client still completes a normal request', () async {
      server.listen((request) {
        request.response
          ..headers.contentType = ContentType.json
          ..write('{"ok":true}');
        request.response.close();
      });
      final api = ApiBaseService(
        config: AppConfig(apiBaseUrl: baseUrl, usesMockData: false),
      );

      final response = await api.get<Map<String, dynamic>>(path: 'health');

      expect(response.statusCode, 200);
      expect(response.data, {'ok': true});
    });

    test(
      'fallback client times out when a server never responds',
      () async {
        server.listen((request) {});
        final api = ApiBaseService(
          config: AppConfig(apiBaseUrl: baseUrl, usesMockData: false),
        );

        await expectLater(
          api.get<Map<String, dynamic>>(path: 'auth/me'),
          throwsA(
            isA<ApiFailure>().having(
              (failure) => failure.kind,
              'kind',
              ApiFailureKind.timeout,
            ),
          ),
        );
      },
      timeout: const Timeout(Duration(seconds: 45)),
    );

    test('an injected client preserves its shorter timeout', () async {
      server.listen((request) {});
      final options = ApiBaseService.createOptions(baseUrl)
        ..receiveTimeout = const Duration(milliseconds: 100);
      final dio = Dio(options);
      addTearDown(() => dio.close(force: true));
      final api = ApiBaseService(
        config: AppConfig(apiBaseUrl: baseUrl, usesMockData: false),
        dio: dio,
      );

      await expectLater(
        api.get<Map<String, dynamic>>(path: 'auth/me'),
        throwsA(
          isA<ApiFailure>()
              .having((failure) => failure.kind, 'kind', ApiFailureKind.timeout)
              .having(
                (failure) => failure.friendlyMessage,
                'message',
                'The request timed out. Please try again.',
              ),
        ),
      );
    });
  });
}
