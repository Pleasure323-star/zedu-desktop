import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _FakeChatStorage extends Fake implements ChatStorageService {
  final Map<String, List<String>> stored = {};
  bool failWrites = false;

  @override
  Future<void> appendMessage(
    String groupDmId,
    String message, {
    String? orgId,
    String? userId,
  }) async {
    if (failWrites) throw StateError('storage unavailable');
    stored.putIfAbsent(groupDmId, () => <String>[]).add(message);
  }
}

class _SilentChatWebsocket extends Fake implements ChatWebsocketService {
  @override
  Stream<ChatWebsocketMessage> get messageStream => const Stream.empty();
}

void main() {
  group('GroupDmNotifier offline queue', () {
    late _FakeChatStorage storage;
    late ProviderContainer container;

    setUp(() {
      storage = _FakeChatStorage();
      container = ProviderContainer(
        overrides: [
          chatStorageProvider.overrideWithValue(storage),
          chatWebsocketProvider.overrideWithValue(_SilentChatWebsocket()),
        ],
      );
      addTearDown(container.dispose);
    });

    test(
      'sends and persists a queued message when the connection returns',
      () async {
        final notifier = container.read(groupDmProvider.notifier);
        container.read(networkStatusProvider.notifier).setOffline();

        await notifier.sendMessage('group-1', 'see you at 5');
        expect(storage.stored, isEmpty);

        container.read(networkStatusProvider.notifier).setOnline();
        await Future<void>.delayed(const Duration(milliseconds: 700));

        expect(storage.stored['group-1'], ['see you at 5']);
      },
    );

    test('keeps a message queued when the retry also fails', () async {
      final notifier = container.read(groupDmProvider.notifier);
      container.read(networkStatusProvider.notifier).setOffline();
      await notifier.sendMessage('group-1', 'retry me');

      storage.failWrites = true;
      container.read(networkStatusProvider.notifier).setOnline();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(storage.stored, isEmpty);

      storage.failWrites = false;
      container.read(networkStatusProvider.notifier).setOffline();
      container.read(networkStatusProvider.notifier).setOnline();
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(storage.stored['group-1'], ['retry me']);
    });
  });
}
