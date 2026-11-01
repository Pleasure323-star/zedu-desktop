import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

DmConversation _dm(String username) => DmConversation(
  channelId: 'c-$username',
  username: username,
  participantId: 'p-$username',
  previewMessage: '',
  unreadCount: 0,
);

void main() {
  final entries = [
    const QuickSwitcherEntry.channel('general'),
    const QuickSwitcherEntry.channel('design'),
    QuickSwitcherEntry.dm(_dm('Gideon')),
  ];

  group('filterQuickSwitcherEntries', () {
    test('keeps every entry for an empty query', () {
      expect(filterQuickSwitcherEntries(entries, '  '), entries);
    });

    test('matches channels and DMs by name, ignoring case', () {
      final labels = filterQuickSwitcherEntries(
        entries,
        'GE',
      ).map((e) => e.label);
      final dmLabels = filterQuickSwitcherEntries(
        entries,
        'gid',
      ).map((e) => e.label);

      expect(labels, ['general']);
      expect(dmLabels, ['Gideon']);
    });

    test('lists names that start with the query before the rest', () {
      final labels = filterQuickSwitcherEntries([
        const QuickSwitcherEntry.channel('web-design'),
        const QuickSwitcherEntry.channel('design'),
      ], 'design').map((e) => e.label);

      expect(labels, ['design', 'web-design']);
    });

    test('returns nothing when no name matches', () {
      expect(filterQuickSwitcherEntries(entries, 'zzz'), isEmpty);
    });
  });

  group('QuickSwitcherDialog', () {
    Future<List<QuickSwitcherEntry>> pumpDialog(WidgetTester tester) async {
      final selected = <QuickSwitcherEntry>[];
      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: QuickSwitcherDialog(
              entries: entries,
              onSelected: selected.add,
            ),
          ),
        ),
      );
      return selected;
    }

    testWidgets('lists channels and DMs', (tester) async {
      await pumpDialog(tester);

      expect(find.text('general'), findsOneWidget);
      expect(find.text('design'), findsOneWidget);
      expect(find.text('Gideon'), findsOneWidget);
    });

    testWidgets('typing filters the list', (tester) async {
      await pumpDialog(tester);

      await tester.enterText(find.byType(TextField), 'gid');
      await tester.pump();

      expect(find.text('Gideon'), findsOneWidget);
      expect(find.text('general'), findsNothing);
      expect(find.text('design'), findsNothing);
    });

    testWidgets('shows a message when nothing matches', (tester) async {
      await pumpDialog(tester);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();

      expect(find.text('No matches'), findsOneWidget);
    });

    testWidgets('Enter opens the first match', (tester) async {
      final selected = await pumpDialog(tester);

      await tester.enterText(find.byType(TextField), 'd');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(selected.single.label, 'design');
    });

    testWidgets('arrow down moves the highlight before Enter', (tester) async {
      final selected = await pumpDialog(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(selected.single.label, 'design');
    });

    testWidgets('tapping a row opens it', (tester) async {
      final selected = await pumpDialog(tester);

      await tester.tap(find.text('Gideon'));
      await tester.pump();

      expect(selected.single.conversation?.username, 'Gideon');
    });
  });
}
