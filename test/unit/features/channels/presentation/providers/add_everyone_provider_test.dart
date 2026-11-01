import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockChannelRepository extends Mock implements ChannelRepository {}

class FakeWorkspaceNotifier extends WorkspaceNotifier {
  FakeWorkspaceNotifier(this._initial);
  final WorkspaceState _initial;

  @override
  WorkspaceState build() => _initial;
}

class FakeActiveChatNotifier extends ActiveChatNotifier {
  FakeActiveChatNotifier(this._initial);
  final ActiveChatState _initial;

  @override
  ActiveChatState build() => _initial;
}

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(this._initial);
  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

final _currentUser = User(
  id: 'me',
  firstName: 'Dave',
  lastName: 'Tolu',
  email: 'me@zedu.chat',
  phone: '',
  username: 'me',
  isVerified: true,
  isOnboarded: true,
  createdAt: DateTime(2026, 10, 16),
  currentOrg: 'org-1',
  currentOrganisationSlug: 'org-1',
  avatarUrl: '',
  defaultAvatarUrl: '',
);

Channel _channel(String id, String name, {bool archived = false}) {
  return Channel(
    id: id,
    name: name,
    description: '',
    organisationId: 'org-1',
    ownerId: 'owner',
    archived: archived,
  );
}

void main() {
  group('openChannelName', () {
    test('is the open channel', () {
      expect(
        openChannelName(
          const ActiveChatState(type: ActiveChatType.channel, id: 'design'),
        ),
        'design',
      );
    });

    test('is #general when no channel is open', () {
      expect(
        openChannelName(
          const ActiveChatState(type: ActiveChatType.directMessage, id: 'u1'),
        ),
        'general',
      );
      expect(openChannelName(ActiveChatState.channelDirectory), 'general');
      expect(
        openChannelName(
          const ActiveChatState(type: ActiveChatType.channel, id: ' '),
        ),
        'general',
      );
    });
  });

  group('usersToAddToChannel', () {
    test('skips channel members, the current user, repeats and empty ids', () {
      final ids = usersToAddToChannel(
        organisationMemberIds: ['me', 'u1', 'u2', 'u2', '', 'u3'],
        channelMemberIds: ['u1'],
        currentUserId: 'me',
      );

      expect(ids, ['u2', 'u3']);
    });

    test('returns an empty list when everyone is already in', () {
      final ids = usersToAddToChannel(
        organisationMemberIds: ['u1', 'u2'],
        channelMemberIds: ['u1', 'u2'],
      );

      expect(ids, isEmpty);
    });
  });

  group('AddEveryoneToChannel', () {
    late MockChannelRepository repository;

    setUp(() {
      repository = MockChannelRepository();
      when(
        () => repository.fetchChannels('org-1'),
      ).thenAnswer((_) async => Success([_channel('ch-gen', 'general')]));
      when(
        () => repository.fetchOrganisationMemberIds('org-1'),
      ).thenAnswer((_) async => const Success(['me', 'u1', 'u2', 'u3']));
      when(
        () => repository.fetchChannelMemberIds('ch-gen'),
      ).thenAnswer((_) async => const Success(['me', 'u1']));
      when(
        () => repository.addMembersToChannel(
          channelId: any(named: 'channelId'),
          userIds: any(named: 'userIds'),
        ),
      ).thenAnswer((_) async => const Success(null));
    });

    ProviderContainer makeContainer({
      String? orgId = 'org-1',
      ActiveChatState? chat,
    }) {
      final container = ProviderContainer(
        overrides: [
          channelRepositoryProvider.overrideWithValue(repository),
          if (chat != null)
            activeChatProvider.overrideWith(() => FakeActiveChatNotifier(chat)),
          workspaceProvider.overrideWith(
            () => FakeWorkspaceNotifier(
              WorkspaceState(
                selectedWorkspace: orgId == null
                    ? null
                    : Workspace(id: orgId, name: 'Cybertron', avatar: ''),
              ),
            ),
          ),
          authNotifierProvider.overrideWith(
            () => FakeAuthNotifier(
              AuthState(status: AuthStatus.authenticated, user: _currentUser),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('adds only the organisation members not in #general yet', () async {
      final result = await makeContainer()
          .read(addEveryoneToChannelProvider)
          .call();

      expect(result, isA<AddEveryoneAdded>());
      expect((result as AddEveryoneAdded).count, 2);
      expect(result.channelName, 'general');
      verify(
        () => repository.addMembersToChannel(
          channelId: 'ch-gen',
          userIds: ['u2', 'u3'],
        ),
      ).called(1);
    });

    test('adds to the channel that is open, not #general', () async {
      when(() => repository.fetchChannels('org-1')).thenAnswer(
        (_) async => Success([
          _channel('ch-gen', 'general'),
          _channel('ch-design', 'design'),
        ]),
      );
      when(
        () => repository.fetchChannelMemberIds('ch-design'),
      ).thenAnswer((_) async => const Success(['me']));

      final result = await makeContainer(
        chat: const ActiveChatState(type: ActiveChatType.channel, id: 'design'),
      ).read(addEveryoneToChannelProvider).call();

      expect(result, isA<AddEveryoneAdded>());
      expect((result as AddEveryoneAdded).count, 3);
      expect(result.channelName, 'design');
      verify(
        () => repository.addMembersToChannel(
          channelId: 'ch-design',
          userIds: ['u1', 'u2', 'u3'],
        ),
      ).called(1);
      verifyNever(() => repository.fetchChannelMemberIds('ch-gen'));
    });

    test('falls back to #general when a direct message is open', () async {
      final result = await makeContainer(
        chat: const ActiveChatState(
          type: ActiveChatType.directMessage,
          id: 'u1',
        ),
      ).read(addEveryoneToChannelProvider).call();

      expect((result as AddEveryoneAdded).channelName, 'general');
      verify(
        () => repository.addMembersToChannel(
          channelId: 'ch-gen',
          userIds: ['u2', 'u3'],
        ),
      ).called(1);
    });

    test(
      'says which channel is missing when the open one is not found',
      () async {
        final result = await makeContainer(
          chat: const ActiveChatState(
            type: ActiveChatType.channel,
            id: 'design',
          ),
        ).read(addEveryoneToChannelProvider).call();

        expect(
          (result as AddEveryoneFailed).message,
          'Could not find #design in this organisation.',
        );
      },
    );

    test(
      'ignores archived channels and matches the name in any case',
      () async {
        when(() => repository.fetchChannels('org-1')).thenAnswer(
          (_) async => Success([
            _channel('ch-old', 'general', archived: true),
            _channel('ch-random', 'random'),
            _channel('ch-gen', 'General'),
          ]),
        );

        await makeContainer().read(addEveryoneToChannelProvider).call();

        verify(
          () => repository.addMembersToChannel(
            channelId: 'ch-gen',
            userIds: any(named: 'userIds'),
          ),
        ).called(1);
      },
    );

    test('does not call the API when everyone is already in', () async {
      when(
        () => repository.fetchChannelMemberIds('ch-gen'),
      ).thenAnswer((_) async => const Success(['me', 'u1', 'u2', 'u3']));

      final result = await makeContainer()
          .read(addEveryoneToChannelProvider)
          .call();

      expect(result, isA<AddEveryoneNobodyToAdd>());
      verifyNever(
        () => repository.addMembersToChannel(
          channelId: any(named: 'channelId'),
          userIds: any(named: 'userIds'),
        ),
      );
    });

    test('fails when the organisation has no #general', () async {
      when(
        () => repository.fetchChannels('org-1'),
      ).thenAnswer((_) async => Success([_channel('ch-random', 'random')]));

      final result = await makeContainer()
          .read(addEveryoneToChannelProvider)
          .call();

      expect(result, isA<AddEveryoneFailed>());
      expect(
        (result as AddEveryoneFailed).message,
        'Could not find #general in this organisation.',
      );
    });

    test('fails with the API message when adding fails', () async {
      when(
        () => repository.addMembersToChannel(
          channelId: any(named: 'channelId'),
          userIds: any(named: 'userIds'),
        ),
      ).thenAnswer(
        (_) async => const Failure(
          ApiFailure(message: 'failed to add users to channel'),
        ),
      );

      final result = await makeContainer()
          .read(addEveryoneToChannelProvider)
          .call();

      expect(
        (result as AddEveryoneFailed).message,
        'failed to add users to channel',
      );
    });

    test(
      'fails without calling the API when no organisation is selected',
      () async {
        final result = await makeContainer(
          orgId: null,
        ).read(addEveryoneToChannelProvider).call();

        expect(result, isA<AddEveryoneFailed>());
        verifyNever(() => repository.fetchChannels(any()));
      },
    );
  });
}
