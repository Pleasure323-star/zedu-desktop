import 'dart:io';

import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MemoryStorage extends SecureStorageService {
  String? token;
  @override
  Future<String?> getAccessToken() async => token;
  @override
  Future<void> saveAccessToken(String token, {bool persist = true}) async =>
      this.token = token;
  @override
  Future<void> deleteAccessToken() async => token = null;
}

void main() {
  late HttpServer server;
  late Dio dio;
  late _MemoryStorage storage;
  late ProviderContainer container;

  setUp(() async {
    await locator.reset();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {});
    final baseUrl = 'http://127.0.0.1:${server.port}/';
    final config = AppConfig(apiBaseUrl: baseUrl, usesMockData: false);
    storage = _MemoryStorage();
    final interceptor = AuthInterceptor(storage: storage);
    locator.registerSingleton<SecureStorageService>(storage);
    locator.registerSingleton<AuthInterceptor>(interceptor);
    // Exercise actual transport and auth state handling quickly. The separate
    // API-client tests verify the production 15/30/30-second defaults.
    dio = Dio(
      ApiBaseService.createOptions(baseUrl)
        ..receiveTimeout = const Duration(milliseconds: 100),
    );
    dio.interceptors.add(interceptor);
    final repository = AuthRepositoryImpl(
      remote: AuthRemoteDataSourceImpl(
        config: config,
        apiBaseService: ApiBaseService(config: config, dio: dio),
      ),
    );
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() async {
    container.dispose();
    dio.close(force: true);
    await server.close(force: true);
    await locator.reset();
  });

  Future<AuthNotifier> ready() async {
    final notifier = container.read(authNotifierProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(authNotifierProvider).status,
      AuthStatus.unauthenticated,
    );
    return notifier;
  }

  for (final operation in ['login', 'sign-up']) {
    test(
      '$operation loading stops with the existing timeout message',
      () async {
        final notifier = await ready();
        final request = operation == 'login'
            ? notifier.login(
                email: 'timeout@example.invalid',
                password: 'dummy-only',
              )
            : notifier.signUp(
                username: 'timeout-demo',
                email: 'timeout@example.invalid',
                password: 'dummy-only',
              );
        expect(container.read(authNotifierProvider).isLoading, isTrue);
        await request;
        expect(container.read(authNotifierProvider).isLoading, isFalse);
        expect(
          container.read(authNotifierProvider).error,
          'The request timed out. Please try again.',
        );
      },
    );
  }

  test('magic-link loading stops after a transport timeout', () async {
    await container.read(magicLinkNotifierProvider.future);
    final request = container
        .read(magicLinkNotifierProvider.notifier)
        .send('timeout@example.invalid');
    expect(container.read(magicLinkNotifierProvider).isLoading, isTrue);
    expect(await request, isFalse);
    final result = container.read(magicLinkNotifierProvider);
    expect(result.isLoading, isFalse);
    expect(
      result.error,
      isA<ApiFailure>().having(
        (error) => error.kind,
        'kind',
        ApiFailureKind.timeout,
      ),
    );
  });

  test(
    'a hung saved-session check leaves initial loading after timeout',
    () async {
      storage.token = 'local-test-token-not-a-real-credential';
      container.read(authNotifierProvider);
      expect(container.read(authNotifierProvider).status, AuthStatus.unknown);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(
        container.read(authNotifierProvider).status,
        AuthStatus.unauthenticated,
      );
      // Respect the squad baseline: a timeout preserves the saved session token.
      expect(storage.token, 'local-test-token-not-a-real-credential');
    },
  );
}
