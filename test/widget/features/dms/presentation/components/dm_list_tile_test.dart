import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

const _palette = AppPalette.light;

class FakeSecureStorageService extends Fake implements SecureStorageService {
  final _values = <String, String>{};

  @override
  Future<String?> readData(String key) async => _values[key];

  @override
  Future<void> writeData(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> deleteValue(String key) async => _values.remove(key);
}

class FakeSelectedDmNotifier extends SelectedDmNotifier {
  FakeSelectedDmNotifier(this._initial);

  final DmConversation? _initial;

  @override
  DmConversation? build() => _initial;
}

class FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState();
}

class FakeDmListNotifier extends DmListNotifier {
  FakeDmListNotifier(this._conversations);

  final List<DmConversation> _conversations;

  @override
  Future<List<DmConversation>> build() async => _conversations;
}

DmConversation buildConversation({
  String channelId = 'channel-1',
  String username = 'Ada Okafor',
  String previewMessage = 'See you at standup',
  int unreadCount = 0,
}) {
  return DmConversation(
    channelId: channelId,
    username: username,
    participantId: 'user-$channelId',
    previewMessage: previewMessage,
    unreadCount: unreadCount,
  );
}

Widget buildTileUnderTest(
  DmConversation conversation, {
  DmConversation? selected,
}) {
  return ProviderScope(
    overrides: [
      selectedDmProvider.overrideWith(() => FakeSelectedDmNotifier(selected)),
      dmDraftStoreProvider.overrideWith(
        (ref) => DmDraftStore(
          FakeSecureStorageService(),
          userId: 'user-1',
          orgId: 'org-1',
        ),
      ),
    ],
    child: buildTestMaterialApp(
      Scaffold(
        backgroundColor: _palette.sidebar,
        body: Column(children: [DmListTile(conversation: conversation)]),
      ),
    ),
  );
}

TextStyle textStyleOf(WidgetTester tester, String text) {
  return tester.widget<Text>(find.text(text)).style!;
}

void main() {
  final selectedFill = _palette.onPrimary.withValues(alpha: 0.16);
  final hoverFill = _palette.onPrimary.withValues(alpha: 0.06);

  testWidgets('read and unread rows have distinct emphasis', (tester) async {
    await tester.pumpWidget(buildTileUnderTest(buildConversation()));
    expect(textStyleOf(tester, 'Ada Okafor').fontWeight, FontWeight.w500);
    expect(
      textStyleOf(tester, 'See you at standup').color,
      _palette.onPrimary.withValues(alpha: 0.72),
    );
    expect(find.text('0'), findsNothing);

    await tester.pumpWidget(
      buildTileUnderTest(buildConversation(unreadCount: 3)),
    );
    expect(textStyleOf(tester, 'Ada Okafor').fontWeight, FontWeight.w700);
    expect(
      textStyleOf(tester, 'See you at standup').fontWeight,
      FontWeight.w700,
    );
    expect(textStyleOf(tester, '3').color, _palette.textPrimary);
    final badge = tester.widget<Container>(
      find.ancestor(of: find.text('3'), matching: find.byType(Container)).first,
    );
    expect((badge.decoration! as BoxDecoration).color, _palette.accent);
  });

  testWidgets('tapping a row selects and highlights it', (tester) async {
    final conversation = buildConversation();
    await tester.pumpWidget(buildTileUnderTest(conversation));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DmListTile)),
    );

    await tester.tap(find.byType(DmListTile));
    await tester.pumpAndSettle();

    expect(container.read(selectedDmProvider), same(conversation));
    final ink = tester.widget<Ink>(find.byType(Ink));
    expect((ink.decoration! as BoxDecoration).color, selectedFill);
    final marker = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          (w.decoration as BoxDecoration).color == _palette.accent,
    );
    expect(marker, findsOneWidget);
    expect(
      tester.widget<InkWell>(find.byType(InkWell)).borderRadius,
      BorderRadius.circular(6),
    );
  });

  testWidgets('hover uses the subtle highlight and click cursor', (
    tester,
  ) async {
    await tester.pumpWidget(buildTileUnderTest(buildConversation()));
    final inkWell = tester.widget<InkWell>(find.byType(InkWell));
    expect(inkWell.hoverColor, hoverFill);
    expect(inkWell.mouseCursor, SystemMouseCursors.click);
  });

  testWidgets('sidebar keeps row ink on a transparent Material', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceProvider.overrideWith(FakeWorkspaceNotifier.new),
          dmDraftStoreProvider.overrideWith(
            (ref) => DmDraftStore(
              FakeSecureStorageService(),
              userId: 'user-1',
              orgId: 'org-1',
            ),
          ),
          dmListProvider.overrideWith(
            () => FakeDmListNotifier([buildConversation()]),
          ),
        ],
        child: buildTestMaterialApp(const Scaffold(body: DmSidebarList())),
      ),
    );
    await tester.pumpAndSettle();
    final material = find
        .ancestor(of: find.byType(DmListTile), matching: find.byType(Material))
        .first;
    expect(tester.widget<Material>(material).type, MaterialType.transparency);
    final sidebar = find.byWidgetPredicate(
      (w) => w is Container && w.color == _palette.sidebar,
    );
    expect(find.descendant(of: sidebar, matching: material), findsOneWidget);
  });

  group('DmListTile time', () {
    DmConversation conversation({
      List<DmPreviewThread> previewThreads = const [],
      DateTime? lastReadAt,
    }) {
      return DmConversation(
        channelId: 'channel-1',
        username: 'Ada',
        participantId: 'user-1',
        previewMessage: '',
        previewThreads: previewThreads,
        lastReadAt: lastReadAt,
        unreadCount: 0,
      );
    }

    Future<void> pumpTile(WidgetTester tester, DmConversation dm) async {
      await tester.pumpWidget(buildTileUnderTest(dm));
    }

    testWidgets('shows no time for a conversation with no activity', (
      tester,
    ) async {
      await pumpTile(tester, conversation());

      expect(find.text('1/1/1970'), findsNothing);
      expect(find.textContaining('1970'), findsNothing);
      expect(find.text('Ada'), findsOneWidget);
    });

    testWidgets('shows the date of the last message', (tester) async {
      await pumpTile(
        tester,
        conversation(
          previewThreads: [
            DmPreviewThread(
              threadId: 'thread-1',
              message: 'Hello',
              userId: 'user-1',
              username: 'Ada',
              createdAt: DateTime(2026, 3, 5, 9, 30),
            ),
          ],
        ),
      );

      expect(find.text('5/3/2026'), findsOneWidget);
    });

    testWidgets('shows the last read date when there are no messages', (
      tester,
    ) async {
      await pumpTile(tester, conversation(lastReadAt: DateTime(2026, 4, 2)));

      expect(find.text('2/4/2026'), findsOneWidget);
    });
  });
}
