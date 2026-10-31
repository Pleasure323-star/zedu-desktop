import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockAppLinks extends Mock implements AppLinks {}

class FakeDeepLinkAuthNotifier extends AuthNotifier {
  FakeDeepLinkAuthNotifier({required this.user});

  final User user;

  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated, user: user);
}

class FakeDeepLinkCreditsNotifier extends CreditsNotifier {
  FakeDeepLinkCreditsNotifier({this.verified = true});

  final bool verified;

  @override
  CreditsState build() => const CreditsState();

  @override
  Future<bool> verifyPayment({
    required String sessionId,
    required String orgId,
  }) async => verified;
}

User _user({String? currentOrg}) => User(
  id: 'u-1',
  firstName: 'Fawaz',
  lastName: 'Yusuff',
  email: 'fawaz@example.com',
  phone: '0800000000',
  username: 'foyusuff7',
  isVerified: true,
  isOnboarded: true,
  createdAt: DateTime(2026),
  currentOrg: currentOrg ?? 'org-1',
  currentOrganisationSlug: 'team-neo',
  avatarUrl: '',
  defaultAvatarUrl: '',
);

void main() {
  group('CreditsPaymentDeepLinkListener', () {
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

    Future<void> pumpPaymentLink(
      WidgetTester tester, {
      required String sessionId,
      required User user,
      required bool verified,
    }) async {
      // Mounts the listener where App.build mounts it: wrapping the router
      // from MaterialApp.router's builder, above the Navigator.
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
            path: AppRouter.buyCredits,
            builder: (context, state) =>
                const Scaffold(body: Text('Credits screen')),
          ),
        ],
      );

      when(() => mockAppLinks.getInitialLink()).thenAnswer(
        (_) async =>
            Uri.parse('zedu://credits/payment-success?session_id=$sessionId'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => FakeDeepLinkAuthNotifier(user: user),
            ),
            creditsNotifierProvider.overrideWith(
              () => FakeDeepLinkCreditsNotifier(verified: verified),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => CreditsPaymentDeepLinkListener(
              appLinks: mockAppLinks,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a verified payment reaches the user', (tester) async {
      await pumpPaymentLink(
        tester,
        sessionId: 'cs-1',
        user: _user(),
        verified: true,
      );

      expect(find.text('Credits screen'), findsOneWidget);
      expect(find.text('AI credits purchased successfully!'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('a payment link is verified against the selected org', (
      tester,
    ) async {
      String? verifiedSession;
      String? verifiedOrg;

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
            path: AppRouter.buyCredits,
            builder: (context, state) =>
                const Scaffold(body: Text('Credits screen')),
          ),
        ],
      );

      when(() => mockAppLinks.getInitialLink()).thenAnswer(
        (_) async =>
            Uri.parse('zedu://credits/payment-success?session_id=cs-2'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => FakeDeepLinkAuthNotifier(user: _user(currentOrg: 'org-9')),
            ),
            creditsNotifierProvider.overrideWith(
              () => _SpyCreditsNotifier(
                onVerify: (sessionId, orgId) {
                  verifiedSession = sessionId;
                  verifiedOrg = orgId;
                },
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => CreditsPaymentDeepLinkListener(
              appLinks: mockAppLinks,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(verifiedSession, 'cs-2');
      expect(verifiedOrg, 'org-9');
    });
  });
}

class _SpyCreditsNotifier extends CreditsNotifier {
  _SpyCreditsNotifier({required this.onVerify});

  final void Function(String sessionId, String orgId) onVerify;

  @override
  CreditsState build() => const CreditsState();

  @override
  Future<bool> verifyPayment({
    required String sessionId,
    required String orgId,
  }) async {
    onVerify(sessionId, orgId);
    return false;
  }
}
