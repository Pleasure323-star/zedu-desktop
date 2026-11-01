import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

// Fake notifier that avoids GetIt/locator setup while remaining type-compatible
// with authNotifierProvider (which is NotifierProvider<AuthNotifier, AuthState>).
class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier({
    AuthState initial = const AuthState(status: AuthStatus.unauthenticated),
    void Function(String email, String password)? onLogin,
    Future<void>? pendingLogin,
  }) : _initial = initial,
       _onLogin = onLogin,
       _pendingLogin = pendingLogin;

  final AuthState _initial;
  final void Function(String email, String password)? _onLogin;
  final Future<void>? _pendingLogin;
  bool? lastRememberMe;

  @override
  AuthState build() => _initial;

  @override
  Future<void> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    lastRememberMe = rememberMe;
    state = state.copyWith(isLoading: true);
    _onLogin?.call(email, password);
    await _pendingLogin;
    state = state.copyWith(isLoading: false);
  }

  @override
  Future<void> logout() async {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

Widget buildLoginViewUnderTest({FakeAuthNotifier? notifier}) {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => notifier ?? FakeAuthNotifier()),
    ],
    child: buildTestMaterialApp(const LoginView()),
  );
}

void main() {
  group('LoginView', () {
    Future<void> pumpDesktopLogin(
      WidgetTester tester,
      FakeAuthNotifier notifier,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildLoginViewUnderTest(notifier: notifier));
      await tester.pump();
    }

    for (final invalidEmail in ['', 'invalid-email']) {
      testWidgets('Enter validates email "$invalidEmail" without logging in', (
        tester,
      ) async {
        var loginCalls = 0;
        await pumpDesktopLogin(
          tester,
          FakeAuthNotifier(onLogin: (_, _) => loginCalls++),
        );
        await tester.enterText(find.byType(TextFormField).at(0), invalidEmail);
        await tester.enterText(find.byType(TextFormField).at(1), '');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(
          find.text(
            invalidEmail.isEmpty
                ? 'Email is required'
                : 'Please enter a valid email',
          ),
          findsOneWidget,
        );
        expect(find.text('Password is required'), findsOneWidget);
        expect(loginCalls, 0);
      });
    }

    testWidgets('Enter submits valid credentials once and permits retry', (
      tester,
    ) async {
      final pendingLogin = Completer<void>();
      final attempts = <(String, String)>[];
      await pumpDesktopLogin(
        tester,
        FakeAuthNotifier(
          onLogin: (email, password) => attempts.add((email, password)),
          pendingLogin: pendingLogin.future,
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      final passwordField = find.byType(TextFormField).at(1);
      await tester.enterText(passwordField, 'Secret123');
      await tester.testTextInput.receiveAction(TextInputAction.done);

      // Refocus after each submission: Flutter's done action unfocuses the field.
      // Submit again before pumping to exercise the synchronous loading guard.
      await tester.tap(passwordField);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.tap(passwordField);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(attempts, [('user@example.com', 'Secret123')]);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );

      pendingLogin.complete();
      await tester.pumpAndSettle();
      await tester.tap(passwordField);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(attempts, [
        ('user@example.com', 'Secret123'),
        ('user@example.com', 'Secret123'),
      ]);
    });

    testWidgets(
      'Enter does not submit while authentication is already loading',
      (tester) async {
        var loginCalls = 0;
        await pumpDesktopLogin(
          tester,
          FakeAuthNotifier(
            initial: const AuthState(
              status: AuthStatus.unauthenticated,
              isLoading: true,
            ),
            onLogin: (_, _) => loginCalls++,
          ),
        );
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'user@example.com',
        );
        await tester.enterText(find.byType(TextFormField).at(1), 'Secret123');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        expect(loginCalls, 0);
      },
    );

    testWidgets('renders form fields and login button when unauthenticated', (
      tester,
    ) async {
      await tester.pumpWidget(buildLoginViewUnderTest());
      await tester.pump();

      expect(find.text('Login to Zedu'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsWidgets);
      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    });

    testWidgets('shows sign in wording on the Google and Apple buttons', (
      tester,
    ) async {
      await tester.pumpWidget(buildLoginViewUnderTest());
      await tester.pump();

      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Sign in with Apple'), findsOneWidget);
      expect(find.text('Sign up with Google'), findsNothing);
      expect(find.text('Sign up with Apple'), findsNothing);
    });

    testWidgets('header prompts users without an account to sign up', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildLoginViewUnderTest());
      await tester.pump();

      expect(
        find.text("Don't have an account? Sign up", findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text('Already have an account? Sign up', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('shows loading spinner when auth status is unknown', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildLoginViewUnderTest(
          notifier: FakeAuthNotifier(
            initial: const AuthState(status: AuthStatus.unknown),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Login to Zedu'), findsNothing);
    });

    testWidgets('shows validation errors when submitting empty form', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildLoginViewUnderTest());
      await tester.pump();

      final loginButton = find.widgetWithText(ElevatedButton, 'Login');
      await tester.ensureVisible(loginButton);
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('calls login with correct credentials when form is valid', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? capturedEmail;
      String? capturedPassword;

      await tester.pumpWidget(
        buildLoginViewUnderTest(
          notifier: FakeAuthNotifier(
            onLogin: (email, password) {
              capturedEmail = email;
              capturedPassword = password;
            },
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Secret123');

      final loginButton = find.widgetWithText(ElevatedButton, 'Login');
      await tester.ensureVisible(loginButton);
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      expect(capturedEmail, 'user@example.com');
      expect(capturedPassword, 'Secret123');
    });

    testWidgets(
      'accepts an email with a trailing space and submits it trimmed',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 1024));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        String? capturedEmail;

        await tester.pumpWidget(
          buildLoginViewUnderTest(
            notifier: FakeAuthNotifier(
              onLogin: (email, password) => capturedEmail = email,
            ),
          ),
        );
        await tester.pump();

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'user@example.com ',
        );
        await tester.enterText(find.byType(TextFormField).at(1), 'Secret123');

        final loginButton = find.widgetWithText(ElevatedButton, 'Login');
        await tester.ensureVisible(loginButton);
        await tester.tap(loginButton);
        await tester.pumpAndSettle();

        expect(find.text('Please enter a valid email'), findsNothing);
        expect(capturedEmail, 'user@example.com');
      },
    );

    Finder socialButton(String label) => find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is SocialAuthButton && widget.label == label,
      ),
      matching: find.byType(OutlinedButton),
    );

    testWidgets('google button shows a spinner and is disabled while loading', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildLoginViewUnderTest(
          notifier: FakeAuthNotifier(
            initial: const AuthState(
              status: AuthStatus.unauthenticated,
              isLoading: true,
            ),
          ),
        ),
      );
      await tester.pump();

      final googleButton = socialButton('Sign in with Google');
      expect(tester.widget<OutlinedButton>(googleButton).onPressed, isNull);
      expect(
        find.descendant(
          of: googleButton,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(socialButton('Sign in with Apple'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('loading google button keeps its label for screen readers', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        buildLoginViewUnderTest(
          notifier: FakeAuthNotifier(
            initial: const AuthState(
              status: AuthStatus.unauthenticated,
              isLoading: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel('Sign in with Google, loading'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('google button is enabled when not loading', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildLoginViewUnderTest());
      await tester.pump();

      final googleButton = socialButton('Sign in with Google');
      expect(tester.widget<OutlinedButton>(googleButton).onPressed, isNotNull);
      expect(
        find.descendant(
          of: googleButton,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
    });

    for (final ticked in [false, true]) {
      testWidgets('passes Remember me = $ticked to login', (tester) async {
        final notifier = FakeAuthNotifier();
        await pumpDesktopLogin(tester, notifier);

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'user@example.com',
        );
        await tester.enterText(find.byType(TextFormField).at(1), 'Secret123');
        if (ticked) {
          await tester.ensureVisible(find.byType(Checkbox));
          await tester.tap(find.byType(Checkbox));
          await tester.pump();
        }

        final loginButton = find.widgetWithText(ElevatedButton, 'Login');
        await tester.ensureVisible(loginButton);
        await tester.tap(loginButton);
        await tester.pumpAndSettle();

        expect(notifier.lastRememberMe, ticked);
      });
    }
  });
}
