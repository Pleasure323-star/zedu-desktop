import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

Future<void> _pumpDialog(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authNotifierProvider.overrideWith(_FakeAuthNotifier.new)],
      child: MaterialApp(
        // The ink-sparkle shader isn't available under flutter_test.
        theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
        home: const Scaffold(body: SetStatusDialog()),
      ),
    ),
  );
}

Finder _checkIcon() => find.byIcon(Icons.check_circle);

void main() {
  group('SetStatusDialog suggested statuses', () {
    testWidgets('shows no selected suggestion initially', (tester) async {
      await _pumpDialog(tester);

      expect(_checkIcon(), findsNothing);
    });

    testWidgets('selecting a suggestion marks only that row', (tester) async {
      await _pumpDialog(tester);

      await tester.tap(find.text('In a meeting'));
      await tester.pump();

      expect(_checkIcon(), findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('In a meeting'),
            matching: find.byType(Row),
          ),
          matching: _checkIcon(),
        ),
        findsOneWidget,
      );
    });

    testWidgets('selecting another suggestion moves the selection', (
      tester,
    ) async {
      await _pumpDialog(tester);

      await tester.tap(find.text('In a meeting'));
      await tester.pump();
      await tester.tap(find.text('Commuting'));
      await tester.pump();

      expect(_checkIcon(), findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Commuting'),
            matching: find.byType(Row),
          ),
          matching: _checkIcon(),
        ),
        findsOneWidget,
      );
    });

    testWidgets('editing the status text clears the selection', (tester) async {
      await _pumpDialog(tester);

      await tester.tap(find.text('In a meeting'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'In a meeting now');
      await tester.pump();

      expect(_checkIcon(), findsNothing);
    });

    testWidgets('changing the expiry clears the selection', (tester) async {
      await _pumpDialog(tester);

      await tester.tap(find.text('In a meeting'));
      await tester.pump();
      await tester.tap(find.byType(DropdownButton<StatusTimeout>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('This week').last);
      await tester.pumpAndSettle();

      expect(_checkIcon(), findsNothing);
    });

    testWidgets('restoring matching values reselects the suggestion', (
      tester,
    ) async {
      await _pumpDialog(tester);

      await tester.tap(find.text('In a meeting'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'In a meeting x');
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'In a meeting');
      await tester.pump();

      expect(_checkIcon(), findsOneWidget);
    });
  });
}
