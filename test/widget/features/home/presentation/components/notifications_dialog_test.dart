import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

void main() {
  group('NotificationsDialog', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestMaterialApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => const NotificationsDialog(),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the heading and empty state', (tester) async {
      await openDialog(tester);

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text("You're all caught up"), findsOneWidget);
      expect(find.text("There's nothing to show here yet."), findsOneWidget);
    });

    testWidgets('close button is labelled and closes it', (tester) async {
      await openDialog(tester);

      final close = find.widgetWithIcon(IconButton, Icons.close);
      expect(close, findsOneWidget);
      expect(tester.widget<IconButton>(close).tooltip, 'Close');

      await tester.tap(close);
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsDialog), findsNothing);
    });

    testWidgets('sidebar bell opens the panel', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: buildTestMaterialApp(
            const Scaffold(
              body: Row(
                children: [AppSidebarRail(activeType: HomeSidebarType.home)],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsDialog), findsOneWidget);
    });
  });
}
