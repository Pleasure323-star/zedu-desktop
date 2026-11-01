import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

void main() {
  group('DmEmptyState', () {
    testWidgets('shows icon, heading and helper line', (tester) async {
      await tester.pumpWidget(buildTestMaterialApp(const DmEmptyState()));

      expect(
        find.descendant(
          of: find.byType(DmEmptyState),
          matching: find.byType(SvgPicture),
        ),
        findsWidgets,
      );
      expect(find.text('Your messages'), findsOneWidget);
      expect(
        find.text('Select a conversation from the list to start messaging.'),
        findsOneWidget,
      );
    });

    testWidgets('does not overflow in a small window', (tester) async {
      tester.view.physicalSize = const Size(300, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildTestMaterialApp(const DmEmptyState()));

      expect(tester.takeException(), isNull);
    });
  });
}
