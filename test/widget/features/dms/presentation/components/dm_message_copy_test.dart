import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'user-1',
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      phone: '',
      username: 'testuser',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026),
      currentOrg: 'org-1',
      currentOrganisationSlug: 'test-org',
      avatarUrl: '',
      defaultAvatarUrl: '',
    ),
  );
}

class _MockDmRepository extends Mock implements DmRepository {}

class _MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  testWidgets('hover Copy puts the plain message text on the clipboard', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add(call.arguments['text'] as String? ?? '');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MockDmRepository();
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer(
      (_) async => [
        {
          'id': 'm1',
          'type': 'user',
          'content': '<p><b>Reach me</b> at gateway 7</p>',
          'user_id': 'user-2',
          'created_at': '2026-10-17T08:00:00Z',
        },
      ],
    );

    final storage = _MockSecureStorageService();
    when(() => storage.readData(any())).thenAnswer((_) async => null);
    when(() => storage.writeData(any(), any())).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dmRepositoryProvider.overrideWithValue(repository),
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          dmDraftStoreProvider.overrideWith(
            (ref) => DmDraftStore(storage, userId: 'user-1', orgId: 'org-1'),
          ),
        ],
        child: buildTestMaterialApp(
          Scaffold(
            body: DmChatArea(
              conversation: DmConversation(
                channelId: 'ch-1',
                username: 'Ada Lovelace',
                participantId: 'u-2',
                previewMessage: '',
                unreadCount: 0,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The message is selectable text, so the right-click menu comes from the
    // selection; hover shows the one-tap Copy button.
    expect(find.byType(SelectionArea), findsOneWidget);
    final copyButton = find.byTooltip('Copy message');
    expect(copyButton, findsOneWidget);

    // Hover with a real mouse pointer so MouseRegion shows the button.
    final pointer = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: 1,
    );
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);

    final hiddenBefore = tester.widget<Opacity>(
      find.ancestor(of: copyButton, matching: find.byType(Opacity)),
    );
    expect(hiddenBefore.opacity, 0);

    await pointer.moveTo(tester.getCenter(copyButton));
    await tester.pump();

    final shownOnHover = tester.widget<Opacity>(
      find.ancestor(of: copyButton, matching: find.byType(Opacity)),
    );
    expect(shownOnHover.opacity, 1);

    await tester.tap(copyButton, warnIfMissed: false);
    await tester.pump();
    // The toast's auto-dismiss timer needs fake time to finish cleanly.
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(copied, hasLength(1));
    expect(copied.single, 'Reach me at gateway 7');
  });
}
