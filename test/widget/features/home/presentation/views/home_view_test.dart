import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

Channel _channel(String name) => Channel(
  id: 'channel-$name',
  name: name,
  description: '',
  organisationId: 'org-1',
  ownerId: 'user-1',
);

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

class _FakeChannelNotifier extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [
    _channel('general'),
    _channel('random'),
  ];
}

final _longName = List.filled(61, 'a').join();

class _LongNameChannelNotifier extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [_channel(_longName)];
}

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Workspace A', avatar: ''),
  );

  void switchTo(String id) {
    state = WorkspaceState(
      selectedWorkspace: Workspace(id: id, name: 'Workspace $id', avatar: ''),
    );
  }
}

void main() {
  group('HomeChatArea', () {
    Future<void> pumpSidebarAndChat(
      WidgetTester tester, {
      ChannelNotifier Function() channels = _FakeChannelNotifier.new,
      double width = 1600,
    }) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            channelProvider.overrideWith(channels),
            workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
            dmDraftStoreProvider.overrideWith(
              (ref) => DmDraftStore(
                FakeSecureStorageService(),
                userId: 'user-1',
                orgId: 'org-1',
              ),
            ),
          ],
          child: buildTestMaterialApp(
            const Scaffold(
              body: Row(
                children: [
                  SizedBox(width: 320, child: SidebarChannelList()),
                  Expanded(child: HomeChatArea()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows #general until another channel is picked', (
      tester,
    ) async {
      await pumpSidebarAndChat(tester);

      expect(find.text('# general'), findsOneWidget);
      expect(find.text('Welcome to #general'), findsOneWidget);
    });

    testWidgets('clicking a sidebar channel opens it in the chat area', (
      tester,
    ) async {
      await pumpSidebarAndChat(tester);

      await tester.tap(find.text('random'));
      await tester.pumpAndSettle();

      expect(find.text('# random'), findsOneWidget);
      expect(find.text('Welcome to #random'), findsOneWidget);
      expect(find.text('# general'), findsNothing);
    });

    testWidgets('goes back to #general when the workspace changes', (
      tester,
    ) async {
      await pumpSidebarAndChat(tester);
      await tester.tap(find.text('random'));
      await tester.pumpAndSettle();
      expect(find.text('# random'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeChatArea)),
      );
      (container.read(workspaceProvider.notifier) as _FakeWorkspaceNotifier)
          .switchTo('org-2');
      await tester.pumpAndSettle();

      expect(find.text('# general'), findsOneWidget);
      expect(find.text('# random'), findsNothing);
    });

    testWidgets('a very long channel name does not overflow', (tester) async {
      await pumpSidebarAndChat(
        tester,
        channels: _LongNameChannelNotifier.new,
        width: 1000,
      );

      await tester.tap(find.text(_longName));
      await tester.pumpAndSettle();

      // The name shows in the sidebar row and in the chat header.
      expect(find.text('# $_longName'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
