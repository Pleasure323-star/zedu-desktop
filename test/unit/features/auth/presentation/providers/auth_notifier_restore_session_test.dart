import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  group('AuthNotifier session restore', () {
    late MockAuthRepository repository;
    late MockSecureStorageService storage;
    late ProviderContainer container;

    setUp(() {
      repository = MockAuthRepository();
      storage = MockSecureStorageService();

      when(() => storage.deleteAccessToken()).thenAnswer((_) async {});

      locator.registerSingleton<SecureStorageService>(storage);
      locator.registerSingleton<AuthInterceptor>(
        AuthInterceptor(storage: storage),
      );

      container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
    });

    tearDown(() async {
      await locator.reset();
    });

    // Starts the notifier and waits until it has finished restoring.
    Future<AuthState> restoreSession() {
      final completer = Completer<AuthState>();
      final subscription = container.listen<AuthState>(authNotifierProvider, (
        previous,
        next,
      ) {
        if (next.status != AuthStatus.unknown && !completer.isCompleted) {
          completer.complete(next);
        }
      }, fireImmediately: true);
      addTearDown(subscription.close);
      return completer.future.timeout(const Duration(seconds: 2));
    }

    void givenSavedTokenAndFailure(ApiFailure failure) {
      when(
        () => storage.getAccessToken(),
      ).thenAnswer((_) async => 'saved-token');
      when(
        () => repository.getCurrentUser(),
      ).thenAnswer((_) async => Failure<User>(failure));
    }

    for (final kind in [
      ApiFailureKind.network,
      ApiFailureKind.timeout,
      ApiFailureKind.server,
    ]) {
      test('keeps the saved token when /auth/me fails with $kind', () async {
        final failure = ApiFailure(message: 'boom', kind: kind);
        givenSavedTokenAndFailure(failure);

        final state = await restoreSession();

        verifyNever(() => storage.deleteAccessToken());
        expect(state.status, AuthStatus.unauthenticated);
        expect(state.error, failure.friendlyMessage);
      });
    }

    test('deletes the saved token when /auth/me returns 401', () async {
      givenSavedTokenAndFailure(
        const ApiFailure(
          message: 'Unauthorized',
          statusCode: 401,
          kind: ApiFailureKind.unauthorized,
        ),
      );

      final state = await restoreSession();

      verify(() => storage.deleteAccessToken()).called(1);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.error, isNull);
    });
  });
}
