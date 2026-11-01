import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockDmRepository extends Mock implements DmRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class FakeAuthNotifier extends AuthNotifier {
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

class CallingActiveCallNotifier extends ActiveCallNotifier {
  CallingActiveCallNotifier(super.ref);

  @override
  ActiveCallState get state => const ActiveCallState(
    status: CallStatus.calling,
    remoteUserName: 'Ada Lovelace',
  );
}

Widget buildCallingDmChatArea() {
  final repository = MockDmRepository();
  when(
    () => repository.getMessages(any(), page: any(named: 'page')),
  ).thenAnswer((_) async => <Map<String, dynamic>>[]);
  final storage = MockSecureStorageService();
  when(() => storage.readData(any())).thenAnswer((_) async => null);

  return ProviderScope(
    overrides: [
      dmRepositoryProvider.overrideWithValue(repository),
      authNotifierProvider.overrideWith(FakeAuthNotifier.new),
      activeCallProvider.overrideWith(CallingActiveCallNotifier.new),
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
  );
}

void main() {
  testWidgets('the Calling banner hang-up button has a Cancel call tooltip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildCallingDmChatArea());
    await tester.pump();

    expect(find.text('Calling...'), findsOneWidget);
    expect(find.byTooltip('Cancel call'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byIcon(Icons.call_end),
        matching: find.byTooltip('Cancel call'),
      ),
      findsOneWidget,
    );
  });
}
