import 'dart:async';

import 'package:zedu/core/core.dart';

final buzzRepositoryProvider = Provider<BuzzRepository>((ref) {
  final repo = BuzzRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

class BuzzRepository {
  final StreamController<Map<String, dynamic>> _callEventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get callEvents => _callEventsController.stream;

  void emitCallEvent(Map<String, dynamic> event) {
    if (!_callEventsController.isClosed) {
      _callEventsController.add(event);
    }
  }

  void dispose() {
    if (!_callEventsController.isClosed) {
      _callEventsController.close();
    }
  }

  Future<Map<String, dynamic>> initiateDirectCall(String participantId) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return <String, dynamic>{
      'success': true,
      'buzzId': 'mock-buzz-id-${DateTime.now().millisecondsSinceEpoch}',
      'token': 'mock-agora-token',
      'channelName': 'mock-channel-$participantId',
    };
  }

  Future<bool> respondToInvitation(String buzzId, bool accept) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return true;
  }

  Future<bool> respondToDirectCall(String buzzId, bool accept) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return true;
  }
}
