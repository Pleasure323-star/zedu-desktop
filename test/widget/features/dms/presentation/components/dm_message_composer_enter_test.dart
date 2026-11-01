import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class MockSecureStorageService extends Mock implements SecureStorageService {}

Widget buildComposerUnderTest() {
  // The composer reads the draft store, which needs the signed-in user and
  // secure storage, so give it the same fakes the chat area test uses.
  final storage = MockSecureStorageService();
  when(() => storage.readData(any())).thenAnswer((_) async => null);
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(FakeAuthNotifier.new),
      dmDraftStoreProvider.overrideWith(
        (ref) => DmDraftStore(storage, userId: 'u', orgId: 'o'),
      ),
    ],
    child: buildTestMaterialApp(
      Scaffold(
        body: DmMessageComposer(
          recipientName: 'Ada',
          channelId: 'channel-1',
          participants: [
            DmParticipant(
              userId: 'user-1',
              username: 'ada_test',
              email: 'ada@example.com',
            ),
          ],
        ),
      ),
    ),
  );
}

TextEditingController composerController(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller;

void main() {
  group('DmMessageComposer Enter with the @mention list open', () {
    testWidgets('inserts the suggested mention instead of sending', (
      tester,
    ) async {
      await tester.pumpWidget(buildComposerUnderTest());
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'hi @ad');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(composerController(tester).text, 'hi @ada_test ');
    });
  });
}
