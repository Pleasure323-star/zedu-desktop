import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class FakeBuzzRepository extends BuzzRepository {
  FakeBuzzRepository({this.buzzId = 'buzz-123', this.token = 'token-abc'});

  final String buzzId;
  final String token;
  final List<(String, bool)> directCallResponses = <(String, bool)>[];

  @override
  Future<Map<String, dynamic>> initiateDirectCall(String participantId) async {
    return <String, dynamic>{
      'success': true,
      'buzzId': buzzId,
      'token': token,
      'channelName': 'channel-$participantId',
    };
  }

  @override
  Future<bool> respondToDirectCall(String buzzId, bool accept) async {
    directCallResponses.add((buzzId, accept));
    return true;
  }
}

void main() {
  group('ActiveCallNotifier.initiateCall (#1281)', () {
    late FakeBuzzRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeBuzzRepository();
      container = ProviderContainer(
        overrides: [
          buzzRepositoryProvider.overrideWithValue(repository),
          activeCallProvider.overrideWith(
            (ref) => ActiveCallNotifier(
              ref,
              ringTimeout: const Duration(milliseconds: 250),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    test(
      'remains in calling status when no remote accept signal arrives',
      () async {
        final localContainer = ProviderContainer(
          overrides: [
            buzzRepositoryProvider.overrideWithValue(repository),
            activeCallProvider.overrideWith(
              (ref) => ActiveCallNotifier(
                ref,
                ringTimeout: const Duration(seconds: 30),
              ),
            ),
          ],
        );
        addTearDown(localContainer.dispose);

        final notifier = localContainer.read(activeCallProvider);
        await notifier.initiateCall(
          remoteUserId: 'user-2',
          remoteUserName: 'Bob',
          channelId: 'dm-1',
        );

        expect(notifier.state.status, CallStatus.calling);
        expect(notifier.state.buzzId, 'buzz-123');

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(notifier.state.status, CallStatus.calling);
      },
    );

    test(
      'transitions to active only on matching buzzId accept signal',
      () async {
        final notifier = container.read(activeCallProvider);
        await notifier.initiateCall(
          remoteUserId: 'user-2',
          remoteUserName: 'Bob',
          channelId: 'dm-1',
        );

        // Stale event for a different buzzId is ignored.
        repository.emitCallEvent(<String, dynamic>{
          'type': 'call_accepted',
          'buzzId': 'other-buzz-id',
        });
        await Future<void>.delayed(Duration.zero);
        expect(notifier.state.status, CallStatus.calling);

        // Matching accept event transitions to active.
        repository.emitCallEvent(<String, dynamic>{
          'type': 'call_accepted',
          'buzzId': 'buzz-123',
          'token': 'live-rtc-token',
        });
        await Future<void>.delayed(Duration.zero);

        expect(notifier.state.status, CallStatus.active);
        expect(notifier.state.token, 'live-rtc-token');
      },
    );

    test(
      'ends the call when the remote user declines or ring timeout elapses',
      () async {
        final notifier = container.read(activeCallProvider);
        await notifier.initiateCall(
          remoteUserId: 'user-2',
          remoteUserName: 'Bob',
          channelId: 'dm-1',
        );

        repository.emitCallEvent(<String, dynamic>{
          'type': 'call_declined',
          'buzzId': 'buzz-123',
        });
        await Future<void>.delayed(Duration.zero);
        expect(notifier.state.status, CallStatus.none);

        // Ring timeout also cancels an unanswered call.
        await notifier.initiateCall(
          remoteUserId: 'user-2',
          remoteUserName: 'Bob',
          channelId: 'dm-1',
        );
        expect(notifier.state.status, CallStatus.calling);

        await Future<void>.delayed(const Duration(milliseconds: 350));
        expect(notifier.state.status, CallStatus.none);
        expect(repository.directCallResponses, contains(('buzz-123', false)));
      },
    );
  });
}
