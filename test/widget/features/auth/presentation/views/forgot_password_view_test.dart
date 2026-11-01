import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

// Fake notifier that avoids GetIt/locator setup while remaining type-compatible
// with authNotifierProvider (which is NotifierProvider<AuthNotifier, AuthState>).
class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

Widget buildForgotPasswordViewUnderTest() {
  return ProviderScope(
    overrides: [authNotifierProvider.overrideWith(() => FakeAuthNotifier())],
    child: const MaterialApp(home: ForgotPasswordView()),
  );
}

void main() {
  group('ForgotPasswordView', () {
    testWidgets('shows the redesigned heading, copy and actions', (
      tester,
    ) async {
      await tester.pumpWidget(buildForgotPasswordViewUnderTest());
      await tester.pump();

      expect(find.text('Forgot your password?'), findsOneWidget);
      expect(
        find.text(
          'Enter the email address for your account and we\'ll send you instructions to reset your password.',
        ),
        findsOneWidget,
      );
      expect(find.text('Enter your email address'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Send reset instructions'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Back to login'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });

    testWidgets('drops the old labels, outlined button and back arrow', (
      tester,
    ) async {
      await tester.pumpWidget(buildForgotPasswordViewUnderTest());
      await tester.pump();

      expect(find.text('Forgot Password'), findsNothing);
      expect(find.text('Submit'), findsNothing);
      expect(find.text('Back to Login'), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).automaticallyImplyLeading,
        isFalse,
      );
    });
  });
}
