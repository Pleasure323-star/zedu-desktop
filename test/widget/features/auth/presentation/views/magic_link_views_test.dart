import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class FakeMagicLinkNotifier extends MagicLinkNotifier {
  FakeMagicLinkNotifier({this.sendResult = true, this.onSend, this.error});

  final bool sendResult;
  final void Function(String email)? onSend;
  final Object? error;

  @override
  FutureOr<void> build() {}

  @override
  Future<bool> send(String email) async {
    onSend?.call(email);
    if (error != null) {
      state = AsyncError<void>(error!, StackTrace.current);
    }
    return sendResult;
  }
}

Widget buildMagicLinkRouterUnderTest({
  FakeMagicLinkNotifier? magicLinkNotifier,
}) {
  final router = GoRouter(
    initialLocation: AppRouter.magicLinkRequest,
    routes: [
      GoRoute(
        path: AppRouter.magicLinkRequest,
        builder: (context, state) => const MagicLinkRequestView(),
      ),
      GoRoute(
        path: AppRouter.magicLinkSent,
        builder: (context, state) =>
            MagicLinkSentView(email: state.extra! as String),
      ),
      GoRoute(
        path: AppRouter.signup,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Sign up screen'))),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      magicLinkNotifierProvider.overrideWith(
        () => magicLinkNotifier ?? FakeMagicLinkNotifier(),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('Magic link views', () {
    testWidgets('request page renders form and shared header icon', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildMagicLinkRouterUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Login with email link'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Generate magic link'), findsOneWidget);
      expect(find.byType(AuthHeaderStrip), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('request page validates empty email', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildMagicLinkRouterUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate magic link'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('successful send navigates to sent page with email', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? capturedEmail;
      await tester.pumpWidget(
        buildMagicLinkRouterUnderTest(
          magicLinkNotifier: FakeMagicLinkNotifier(
            sendResult: true,
            onSend: (email) => capturedEmail = email,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField),
        'anonymoususer@gmail.com',
      );
      await tester.tap(find.text('Generate magic link'));
      await tester.pumpAndSettle();

      expect(capturedEmail, 'anonymoususer@gmail.com');
      expect(find.text('Check your email'), findsOneWidget);
      expect(find.textContaining('anonymoususer@gmail.com'), findsOneWidget);
      expect(
        find.textContaining('Open the email and click the link to continue.'),
        findsOneWidget,
      );
      expect(find.byType(AuthHeaderStrip), findsOneWidget);
    });

    testWidgets(
      'unknown email shows a friendly message, not the generic 404 text',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 1024));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Mirrors the backend's 404 for an unregistered email:
        // {"status":"error","status_code":404,"message":"user not found"}.
        // ApiFailure maps 404 -> notFound; the screen shows a fixed message.
        await tester.pumpWidget(
          buildMagicLinkRouterUnderTest(
            magicLinkNotifier: FakeMagicLinkNotifier(
              sendResult: false,
              error: const ApiFailure(
                message: 'user not found',
                statusCode: 404,
                path: '/auth/magick-link',
                kind: ApiFailureKind.notFound,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField),
          'unknown@example.com',
        );
        await tester.tap(find.text('Generate magic link'));
        await tester.pumpAndSettle();

        expect(
          find.text("We couldn't find an account with that email."),
          findsOneWidget,
        );
        expect(find.text('user not found'), findsNothing);
        expect(find.text('The resource was not found.'), findsNothing);

        // Flush the toast's 4s auto-dismiss Future.delayed so no timer leaks.
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets('sign up link navigates to the signup screen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildMagicLinkRouterUnderTest());
      await tester.pumpAndSettle();

      const linkText = 'Sign up';
      final paragraphFinder = find.textContaining(linkText, findRichText: true);
      final paragraph =
          paragraphFinder.evaluate().single.renderObject as RenderParagraph;
      final plainText = paragraph.text.toPlainText();
      final startOffset = plainText.indexOf(linkText);
      final box = paragraph
          .getBoxesForSelection(
            TextSelection(
              baseOffset: startOffset,
              extentOffset: startOffset + linkText.length,
            ),
          )
          .single
          .toRect();

      await tester.tapAt(
        tester.getTopLeft(paragraphFinder) +
            Offset(box.left + box.width / 2, box.top + box.height / 2),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign up screen'), findsOneWidget);
    });
  });
}
