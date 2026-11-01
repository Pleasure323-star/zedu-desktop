import 'dart:async';

import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockChannelRepository extends Mock implements ChannelRepository {}

class FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Test org', avatar: ''),
  );
}

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

Channel _channel(String name) => Channel(
  id: 'channel-$name',
  name: name,
  description: '',
  organisationId: 'org-1',
  ownerId: 'user-1',
);

void main() {
  group('ChannelNotifier.createChannel', () {
    late MockChannelRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = MockChannelRepository();
      when(
        () => repository.fetchChannels(any()),
      ).thenAnswer((_) async => Success<List<Channel>>([_channel('general')]));

      container = ProviderContainer(
        overrides: [
          channelRepositoryProvider.overrideWithValue(repository),
          workspaceProvider.overrideWith(FakeWorkspaceNotifier.new),
          authNotifierProvider.overrideWith(FakeAuthNotifier.new),
        ],
      );
      addTearDown(container.dispose);
    });

    void stubCreateChannel(Result<Channel> result) {
      when(
        () => repository.createChannel(
          name: any(named: 'name'),
          description: any(named: 'description'),
          orgId: any(named: 'orgId'),
          username: any(named: 'username'),
          isPrivate: any(named: 'isPrivate'),
          topic: any(named: 'topic'),
        ),
      ).thenAnswer((_) async => result);
    }

    // Reads the notifier and waits for the first channel fetch to finish.
    Future<ChannelNotifier> loadNotifier() async {
      await container.read(channelProvider.future);
      return container.read(channelProvider.notifier);
    }

    test('adds the new channel to the list and returns the channel', () async {
      stubCreateChannel(Success<Channel>(_channel('team-heron')));
      final notifier = await loadNotifier();

      final result = await notifier.createChannel(
        name: 'team-heron',
        description: '',
        isPrivate: false,
      );

      final state = container.read(channelProvider);
      expect(result, isA<Success<Channel>>());
      expect(state.requireValue.map((c) => c.name), ['general', 'team-heron']);
      expect(state.isLoading, isFalse);
      expect(state.hasError, isFalse);
    });

    test(
      'keeps every channel when the server sends channels without ids',
      () async {
        Channel noId(String name) => Channel(
          id: '',
          name: name,
          description: '',
          organisationId: 'org-1',
          ownerId: 'user-1',
        );
        when(() => repository.fetchChannels(any())).thenAnswer(
          (_) async =>
              Success<List<Channel>>([noId('general'), noId('team-heron')]),
        );
        stubCreateChannel(Success<Channel>(noId('plan')));
        final notifier = await loadNotifier();

        final result = await notifier.createChannel(
          name: 'plan',
          description: '',
          isPrivate: false,
        );

        expect(result, isA<Success<Channel>>());
        expect(
          container.read(channelProvider).requireValue.map((c) => c.name),
          ['general', 'team-heron', 'plan'],
        );
      },
    );

    test(
      'returns the server message and leaves the list state alone',
      () async {
        stubCreateChannel(
          const Failure<Channel>(
            ApiFailure(message: 'Channel name already exists'),
          ),
        );
        final notifier = await loadNotifier();

        final result = await notifier.createChannel(
          name: 'general',
          description: '',
          isPrivate: false,
        );

        final state = container.read(channelProvider);
        expect(
          (result as Failure<Channel>).error.message,
          'Channel name already exists',
        );
        expect(state.requireValue.map((c) => c.name), ['general']);
        expect(state.isLoading, isFalse);
        // A create error must not look like a failed channel load.
        expect(state.hasError, isFalse);
      },
    );

    test('ignores a second create while one is still running', () async {
      final pending = Completer<Result<Channel>>();
      when(
        () => repository.createChannel(
          name: any(named: 'name'),
          description: any(named: 'description'),
          orgId: any(named: 'orgId'),
          username: any(named: 'username'),
          isPrivate: any(named: 'isPrivate'),
          topic: any(named: 'topic'),
        ),
      ).thenAnswer((_) => pending.future);
      final notifier = await loadNotifier();

      final first = notifier.createChannel(
        name: 'team-heron',
        description: '',
        isPrivate: false,
      );
      final second = await notifier.createChannel(
        name: 'team-heron-2',
        description: '',
        isPrivate: false,
      );
      pending.complete(Success<Channel>(_channel('team-heron')));

      expect(second, isA<Failure<Channel>>());
      expect(await first, isA<Success<Channel>>());
      verify(
        () => repository.createChannel(
          name: any(named: 'name'),
          description: any(named: 'description'),
          orgId: any(named: 'orgId'),
          username: any(named: 'username'),
          isPrivate: any(named: 'isPrivate'),
          topic: any(named: 'topic'),
        ),
      ).called(1);
    });
  });
}
