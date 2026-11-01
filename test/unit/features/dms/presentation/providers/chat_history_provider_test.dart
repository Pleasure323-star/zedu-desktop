import 'dart:async';

import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockDmRepository extends Mock implements DmRepository {}

void main() {
  _deleteTests();
  group('ChatHistoryNotifier.saveEdit', () {
    late MockDmRepository mockRepository;
    late ProviderContainer container;
    late ChatHistoryNotifier notifier;

    final initialMessages = <Map<String, dynamic>>[
      {'id': 'm1', 'content': 'hello', 'user_id': 'u1'},
    ];

    setUp(() async {
      mockRepository = MockDmRepository();
      when(
        () => mockRepository.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer(
        (_) async => List<Map<String, dynamic>>.from(initialMessages),
      );

      container = ProviderContainer(
        overrides: [dmRepositoryProvider.overrideWithValue(mockRepository)],
      );
      notifier = container.read(chatHistoryProvider('ch-1'));
      await pumpEventQueue();
    });

    tearDown(() {
      container.dispose();
    });

    test('keeps the new content when the edit request succeeds', () async {
      when(
        () => mockRepository.editMessage(any(), content: any(named: 'content')),
      ).thenAnswer((_) async {});

      notifier.startEditing('m1');
      await notifier.saveEdit('m1', 'edited');

      expect(notifier.editingMessageId, isNull);
      expect(notifier.messages.single['content'], 'edited');
    });

    test(
      'reverts to the original content when the edit request fails',
      () async {
        when(
          () =>
              mockRepository.editMessage(any(), content: any(named: 'content')),
        ).thenThrow(Exception('network error'));

        notifier.startEditing('m1');
        await notifier.saveEdit('m1', 'edited');

        expect(notifier.editingMessageId, isNull);
        expect(notifier.messages.single['content'], 'hello');
      },
    );

    test(
      'reverts to null content when the edited message had no content',
      () async {
        when(
          () =>
              mockRepository.editMessage(any(), content: any(named: 'content')),
        ).thenThrow(Exception('network error'));

        notifier.messages = [
          {'id': 'm1', 'content': null, 'user_id': 'u1'},
        ];

        notifier.startEditing('m1');
        await notifier.saveEdit('m1', 'edited');

        expect(notifier.editingMessageId, isNull);
        expect(notifier.messages.single['content'], isNull);
      },
    );

    test(
      'keeps the newer edit when an older pending edit fails later',
      () async {
        final firstRequest = Completer<void>();
        var callCount = 0;
        when(
          () =>
              mockRepository.editMessage(any(), content: any(named: 'content')),
        ).thenAnswer((_) {
          callCount++;
          if (callCount == 1) return firstRequest.future;
          return Future.value();
        });

        notifier.startEditing('m1');
        final first = notifier.saveEdit('m1', 'edited1');
        notifier.startEditing('m1');
        final second = notifier.saveEdit('m1', 'edited2');

        firstRequest.completeError(Exception('network error'));
        await second;
        await first;

        expect(notifier.messages.single['content'], 'edited2');
      },
    );

    test(
      'keeps the newer save when an older edit with the same content fails',
      () async {
        final firstRequest = Completer<void>();
        var callCount = 0;
        when(
          () =>
              mockRepository.editMessage(any(), content: any(named: 'content')),
        ).thenAnswer((_) {
          callCount++;
          if (callCount == 1) return firstRequest.future;
          return Future.value();
        });

        notifier.startEditing('m1');
        final first = notifier.saveEdit('m1', 'edited');
        notifier.startEditing('m1');
        final second = notifier.saveEdit('m1', 'edited');

        firstRequest.completeError(Exception('network error'));
        await second;
        await first;

        expect(notifier.messages.single['content'], 'edited');
      },
    );

    test(
      'keeps another message being edited when a queued save starts',
      () async {
        final firstRequest = Completer<void>();
        var callCount = 0;
        when(
          () =>
              mockRepository.editMessage(any(), content: any(named: 'content')),
        ).thenAnswer((_) {
          callCount++;
          if (callCount == 1) return firstRequest.future;
          return Future.value();
        });

        notifier.messages = [
          {'id': 'm1', 'content': 'hello', 'user_id': 'u1'},
          {'id': 'm2', 'content': 'other', 'user_id': 'u1'},
        ];

        notifier.startEditing('m1');
        final first = notifier.saveEdit('m1', 'edited1');
        notifier.startEditing('m2');
        final second = notifier.saveEdit('m1', 'edited1b');

        firstRequest.complete();
        await first;
        await second;

        expect(notifier.editingMessageId, 'm2');
        expect(notifier.messages.first['content'], 'edited1b');
      },
    );

    test('reverts when two overlapping edits both fail', () async {
      when(
        () => mockRepository.editMessage(any(), content: any(named: 'content')),
      ).thenThrow(Exception('network error'));

      notifier.startEditing('m1');
      final first = notifier.saveEdit('m1', 'edited1');
      notifier.startEditing('m1');
      final second = notifier.saveEdit('m1', 'edited2');

      await first;
      await second;

      expect(notifier.messages.single['content'], 'hello');
    });
  });
}

void _deleteTests() {
  group('ChatHistoryNotifier.deleteMessage', () {
    late MockDmRepository mockRepository;
    late ProviderContainer container;
    late ChatHistoryNotifier notifier;

    setUp(() async {
      mockRepository = MockDmRepository();
      when(
        () => mockRepository.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer(
        (_) async => [
          {'id': 'm1', 'content': 'hello', 'user_id': 'u1'},
          {'id': 'm2', 'content': 'again', 'user_id': 'u1'},
        ],
      );
      container = ProviderContainer(
        overrides: [dmRepositoryProvider.overrideWithValue(mockRepository)],
      );
      notifier = container.read(chatHistoryProvider('ch-1'));
      await pumpEventQueue();
    });

    tearDown(() => container.dispose());

    test('removes the message and calls the delete endpoint', () async {
      when(
        () => mockRepository.deleteMessage(
          threadId: any(named: 'threadId'),
          channelId: any(named: 'channelId'),
        ),
      ).thenAnswer((_) async {});

      await notifier.deleteMessage('m1');

      expect(notifier.messages.map((m) => m['id']), ['m2']);
      verify(
        () => mockRepository.deleteMessage(threadId: 'm1', channelId: 'ch-1'),
      ).called(1);
    });

    test('does not bring a deleted message back when polling', () async {
      when(
        () => mockRepository.deleteMessage(
          threadId: any(named: 'threadId'),
          channelId: any(named: 'channelId'),
        ),
      ).thenAnswer((_) async {});

      await notifier.deleteMessage('m1');
      await notifier.loadMore();

      expect(notifier.messages.map((m) => m['id']), isNot(contains('m1')));
    });

    test('puts the message back when the request fails', () async {
      when(
        () => mockRepository.deleteMessage(
          threadId: any(named: 'threadId'),
          channelId: any(named: 'channelId'),
        ),
      ).thenThrow(Exception('network error'));

      await notifier.deleteMessage('m1');

      expect(notifier.messages.map((m) => m['id']), ['m1', 'm2']);
    });
  });
}
