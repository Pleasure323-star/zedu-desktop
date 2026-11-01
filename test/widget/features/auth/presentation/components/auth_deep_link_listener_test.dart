import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockAppLinks extends Mock implements AppLinks {}

class FakeDeepLinkAuthNotifier extends AuthNotifier {
  FakeDeepLinkAuthNotifier({this.onVerify, this.authenticated = false});

  final void Function(String token)? onVerify;
  final bool authenticated;

  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);

  @override
  Future<void> verifyMagicLink({required String token}) async {
    onVerify?.call(token);
    state = authenticated
        ? const AuthState(status: AuthStatus.authenticated)
        : const AuthState(status: AuthStatus.unauthenticated);
  }
}

void main() {
  group('AuthDeepLinkListener', () {
    late MockAppLinks mockAppLinks;
    late StreamController<Uri> linkController;

    setUp(() {
      mockAppLinks = MockAppLinks();
      linkController = StreamController<Uri>.broadcast();

      when(
        () => mockAppLinks.uriLinkStream,
      ).thenAnswer((_) => linkController.stream);
    });

    tearDown(() async {
      await linkController.close();
    });

    testWidgets('ignores link when token query param is missing', (
      tester,
    ) async {
      String? capturedToken;

      when(
        () => mockAppLinks.getInitialLink(),
      ).thenAnswer((_) async => Uri.parse('zedu://auth/magick-link/verify'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => FakeDeepLinkAuthNotifier(
                onVerify: (token) => capturedToken = token,
              ),
            ),
          ],
          child: MaterialApp(
            home: AuthDeepLinkListener(
              appLinks: mockAppLinks,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(capturedToken, isNull);
    });

    testWidgets('passes token to verifyMagicLink for valid initial link', (
      tester,
    ) async {
      String? capturedToken;

      when(() => mockAppLinks.getInitialLink()).thenAnswer(
        (_) async => Uri.parse('zedu://auth/magick-link/verify?token=t-123'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => FakeDeepLinkAuthNotifier(
                onVerify: (token) => capturedToken = token,
              ),
            ),
          ],
          child: MaterialApp(
            home: AuthDeepLinkListener(
              appLinks: mockAppLinks,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(capturedToken, 't-123');
    });

    testWidgets('a successful verification reaches the user', (tester) async {
      // Mounts the listener exactly where App.build mounts it: wrapping the
      // router from MaterialApp.router's builder, above the Navigator.
      final router = GoRouter(
        initialLocation: AppRouter.login,
        navigatorKey: AppRouter.navigatorKey,
        routes: [
          GoRoute(
            path: AppRouter.login,
            builder: (context, state) =>
                const Scaffold(body: Text('Login screen')),
          ),
          GoRoute(
            path: AppRouter.home,
            builder: (context, state) =>
                const Scaffold(body: Text('Home screen')),
          ),
        ],
      );

      when(() => mockAppLinks.getInitialLink()).thenAnswer(
        (_) async => Uri.parse('zedu://auth/magick-link/verify?token=t-1'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => FakeDeepLinkAuthNotifier(authenticated: true),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => AuthDeepLinkListener(
              appLinks: mockAppLinks,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Home screen'), findsOneWidget);
      expect(find.text('Logged in successfully!'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });
}
