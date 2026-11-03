import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockSecureStorage extends Mock implements SecureStorageService {}

void main() {
  late _MockSecureStorage storage;
  late Map<String, String> backing;
  late List<String> writes;

  setUpAll(() {
    registerFallbackValue('');
  });

  setUp(() {
    storage = _MockSecureStorage();
    backing = {};
    writes = [];
    when(() => storage.readData(any<String>())).thenAnswer(
      (inv) async => backing[inv.positionallyTypedArgs<String>().first],
    );
    when(() => storage.writeData(any<String>(), any<String>())).thenAnswer((
      inv,
    ) async {
      final key = inv.positionallyTypedArgs<String>().first;
      final value = inv.positionallyTypedArgs<String>()[1];
      writes.add(key);
      backing[key] = value;
    });
    when(() => storage.deleteValue(any<String>())).thenAnswer((inv) async {
      backing.remove(inv.positionallyTypedArgs<String>().first);
    });
  });

  DmPreferenceStore store({String userId = 'u1', String orgId = 'org1'}) =>
      DmPreferenceStore(storage, userId: userId, orgId: orgId);

  Future<ProviderContainer> makeContainer() async {
    final c = ProviderContainer(
      overrides: [
        dmPreferenceStoreProvider.overrideWith(
          (ref) => DmPreferenceStore(storage, userId: 'u1', orgId: 'org1'),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> flushStorageTasks() =>
      Future<void>.delayed(const Duration(milliseconds: 10));

  test('load returns an empty set when nothing was saved', () async {
    expect(await store().load('pinnedIds'), const <String>{});
  });

  test('load returns an empty set when storage holds junk', () async {
    backing['dm_prefs_u1_org1_pinnedIds'] = '{not json';
    expect(await store().load('pinnedIds'), const <String>{});
  });

  test('save writes the ids and load reads them back', () async {
    final s = store();
    await s.save('pinnedIds', {'a', 'b'});
    expect(await s.load('pinnedIds'), {'a', 'b'});
    await s.save('mutedParticipantIds', {'x', 'y'});
    expect(await s.load('mutedParticipantIds'), {'x', 'y'});
  });

  test('saving an empty set deletes the stored value', () async {
    final s = store();
    await s.save('pinnedIds', {'a'});
    expect(backing['dm_prefs_u1_org1_pinnedIds'], isNotNull);
    await s.save('pinnedIds', const {});
    expect(backing['dm_prefs_u1_org1_pinnedIds'], isNull);
    expect(await s.load('pinnedIds'), const <String>{});
  });

  test('keys are namespaced per user and organisation', () async {
    final s = store();
    await s.save('pinnedIds', {'a'});
    expect(backing['dm_prefs_u1_org1_pinnedIds'], jsonEncode(['a']));

    final other = store(userId: 'u2', orgId: 'org9');
    expect(await other.load('pinnedIds'), const <String>{});
    await other.save('pinnedIds', {'b'});
    expect(backing['dm_prefs_u2_org9_pinnedIds'], jsonEncode(['b']));
    // The first account's value is untouched.
    expect(await s.load('pinnedIds'), {'a'});
  });

  test(
    '#2356 pins survive a restart (save on toggle, load on rebuild)',
    () async {
      // "First session": pin one conversation.
      final first = await makeContainer();
      expect(writes.where((k) => k.endsWith('pinnedIds')), isEmpty);
      first.read(dmConversationActionsProvider.notifier).togglePinned('ch1');
      expect(first.read(dmConversationActionsProvider).pinnedIds, {'ch1'});
      await flushStorageTasks();
      expect(writes.where((k) => k.endsWith('pinnedIds')), isNotEmpty);
      expect(backing['dm_prefs_u1_org1_pinnedIds'], jsonEncode(['ch1']));

      // "Restart": a fresh container (same saved storage) restores the pin.
      final second = await makeContainer();
      second.read(dmConversationActionsProvider);
      await flushStorageTasks();
      expect(second.read(dmConversationActionsProvider).pinnedIds, {'ch1'});
    },
  );

  test('#2356 unpin persists too: the pin does not come back', () async {
    backing['dm_prefs_u1_org1_pinnedIds'] = jsonEncode(['ch1', 'ch2']);
    final c = await makeContainer();
    c.read(dmConversationActionsProvider);
    await flushStorageTasks();
    expect(c.read(dmConversationActionsProvider).pinnedIds, {'ch1', 'ch2'});

    c.read(dmConversationActionsProvider.notifier).togglePinned('ch1');
    await flushStorageTasks();
    expect(backing['dm_prefs_u1_org1_pinnedIds'], jsonEncode(['ch2']));

    final second = await makeContainer();
    second.read(dmConversationActionsProvider);
    await flushStorageTasks();
    expect(second.read(dmConversationActionsProvider).pinnedIds, {'ch2'});
  });

  test('#2356 mutes survive a restart and unmuting persists', () async {
    backing['dm_prefs_u1_org1_mutedParticipantIds'] = jsonEncode(['p1']);
    final c = await makeContainer();
    c.read(notificationSettingsProvider);
    await flushStorageTasks();
    expect(c.read(notificationSettingsProvider).isMuted('p1'), isTrue);

    c.read(notificationSettingsProvider.notifier).muteParticipant('p2');
    expect(writes.where((k) => k.endsWith('mutedParticipantIds')), isNotEmpty);
    await flushStorageTasks();
    expect(
      backing['dm_prefs_u1_org1_mutedParticipantIds'],
      jsonEncode(['p1', 'p2']),
    );

    c.read(notificationSettingsProvider.notifier).unmuteParticipant('p1');
    await flushStorageTasks();
    expect(backing['dm_prefs_u1_org1_mutedParticipantIds'], jsonEncode(['p2']));

    final second = await makeContainer();
    second.read(notificationSettingsProvider);
    await flushStorageTasks();
    final settings = second.read(notificationSettingsProvider);
    expect(settings.isMuted('p2'), isTrue);
    expect(settings.isMuted('p1'), isFalse);
  });
}

extension on Invocation {
  List<T> positionallyTypedArgs<T>() =>
      positionalArguments.whereType<T>().toList();
}
