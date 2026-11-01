import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class _Auth extends AuthNotifier {
  _Auth(this.status);

  final AuthStatus status;

  @override
  AuthState build() => AuthState(status: status);
}

class _Channels extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [
    _channel('c-general', 'general'),
    _channel('c-old', 'old-launch', archived: true),
  ];
}

class _Dms extends DmListNotifier {
  @override
  Future<List<DmConversation>> build() async => [
    DmConversation(
      channelId: 'c-gideon',
      username: 'Gideon',
      participantId: 'p-gideon',
      previewMessage: '',
      unreadCount: 0,
    ),
  ];
}

class _FailingChannels extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => throw Exception('offline');
}

/// The real notifier follows the selected workspace, which loads from the API.
class _ActiveChat extends ActiveChatNotifier {
  @override
  ActiveChatState build() => ActiveChatState.channelDirectory;
}

Channel _channel(String id, String name, {bool archived = false}) => Channel(
  id: id,
  name: name,
  description: '',
  organisationId: 'org-1',
  ownerId: 'owner',
  archived: archived,
);

GoRouter _router({required bool withTextField}) => GoRouter(
  initialLocation: '/settings',
  routes: [
    GoRoute(
      path: AppRouter.home,
      builder: (_, _) => const Scaffold(body: Text('home screen')),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, _) => Scaffold(
        body: withTextField
            ? const TextField(autofocus: true)
            : const Text('settings screen'),
      ),
    ),
  ],
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  AuthStatus status = AuthStatus.authenticated,
  bool withTextField = true,
  bool channelsFail = false,
}) async {
  final router = _router(withTextField: withTextField);
  final container = ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(() => _Auth(status)),
      channelProvider.overrideWith(
        channelsFail ? _FailingChannels.new : _Channels.new,
      ),
      dmListProvider.overrideWith(_Dms.new),
      activeChatProvider.overrideWith(_ActiveChat.new),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => QuickSwitcherShortcut(
          router: router,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _pressCtrlK(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  group('QuickSwitcherShortcut', () {
    testWidgets(
      'Ctrl+K opens the switcher with channels and DMs, not archived channels',
      (tester) async {
        await _pump(tester);

        await _pressCtrlK(tester);

        expect(find.byType(QuickSwitcherDialog), findsOneWidget);
        expect(find.text('general'), findsOneWidget);
        expect(find.text('Gideon'), findsOneWidget);
        expect(find.text('old-launch'), findsNothing);
      },
    );

    testWidgets('picking a channel opens it and goes home', (tester) async {
      final container = await _pump(tester);

      await _pressCtrlK(tester);
      await tester.tap(find.text('general'));
      await tester.pumpAndSettle();

      expect(find.byType(QuickSwitcherDialog), findsNothing);
      expect(container.read(homeSidebarProvider), HomeSidebarType.home);
      expect(container.read(activeChatProvider).id, 'general');
      expect(find.text('home screen'), findsOneWidget);
    });

    testWidgets('picking a DM opens it in the DMs tab', (tester) async {
      final container = await _pump(tester);

      await _pressCtrlK(tester);
      await tester.tap(find.text('Gideon'));
      await tester.pumpAndSettle();

      expect(container.read(homeSidebarProvider), HomeSidebarType.dms);
      expect(container.read(selectedDmProvider)?.username, 'Gideon');
      expect(find.text('home screen'), findsOneWidget);
    });

    testWidgets('does nothing when signed out', (tester) async {
      await _pump(tester, status: AuthStatus.unauthenticated);

      await _pressCtrlK(tester);

      expect(find.byType(QuickSwitcherDialog), findsNothing);
    });

    testWidgets('a second Ctrl+K while it is open does not stack another', (
      tester,
    ) async {
      await _pump(tester);

      await _pressCtrlK(tester);
      await _pressCtrlK(tester);

      expect(find.byType(QuickSwitcherDialog), findsOneWidget);
    });

    testWidgets('tells the user when the channels could not be loaded', (
      tester,
    ) async {
      await _pump(tester, channelsFail: true);

      await _pressCtrlK(tester);

      expect(find.byType(QuickSwitcherDialog), findsOneWidget);
      expect(find.text('Gideon'), findsOneWidget);
      expect(
        find.text("Couldn't load all your channels and DMs."),
        findsOneWidget,
      );

      // Let the toast close itself before the test ends.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('fires when nothing on the screen has focus', (tester) async {
      await _pump(tester, withTextField: false);
      // No text field or other control holds focus, only the page itself.
      expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());

      await _pressCtrlK(tester);

      expect(find.byType(QuickSwitcherDialog), findsOneWidget);
    });
  });
}
