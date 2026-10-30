import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

enum CallStatus { none, calling, incoming, active }

class ActiveCallState {
  final CallStatus status;
  final String? buzzId;
  final String? channelId;
  final String? remoteUserName;
  final String? remoteUserId;
  final String? remoteAvatarUrl;
  final String? token;
  final bool isFullPage;
  final DateTime? lastCallAt;

  const ActiveCallState({
    this.status = CallStatus.none,
    this.buzzId,
    this.channelId,
    this.remoteUserName,
    this.remoteUserId,
    this.remoteAvatarUrl,
    this.token,
    this.isFullPage = false,
    this.lastCallAt,
  });

  ActiveCallState copyWith({
    CallStatus? status,
    String? buzzId,
    String? channelId,
    String? remoteUserName,
    String? remoteUserId,
    String? remoteAvatarUrl,
    String? token,
    bool? isFullPage,
    DateTime? lastCallAt,
  }) {
    return ActiveCallState(
      status: status ?? this.status,
      buzzId: buzzId ?? this.buzzId,
      channelId: channelId ?? this.channelId,
      remoteUserName: remoteUserName ?? this.remoteUserName,
      remoteUserId: remoteUserId ?? this.remoteUserId,
      remoteAvatarUrl: remoteAvatarUrl ?? this.remoteAvatarUrl,
      token: token ?? this.token,
      isFullPage: isFullPage ?? this.isFullPage,
      lastCallAt: lastCallAt ?? this.lastCallAt,
    );
  }
}

class ActiveCallNotifier extends ChangeNotifier {
  static const Duration defaultRingTimeout = Duration(seconds: 30);

  final Ref _ref;
  final Duration ringTimeout;
  ActiveCallState _state = const ActiveCallState();
  StreamSubscription<Map<String, dynamic>>? _callEventsSub;
  Timer? _ringTimer;

  ActiveCallNotifier(this._ref, {this.ringTimeout = defaultRingTimeout});

  ActiveCallState get state => _state;

  void setFullPage(bool isFullPage) {
    _state = _state.copyWith(isFullPage: isFullPage);
    notifyListeners();
  }

  Future<void> initiateCall({
    required String remoteUserId,
    required String remoteUserName,
    required String channelId,
    String? remoteAvatarUrl,
  }) async {
    _cancelTimersAndSubscriptions();
    _state = ActiveCallState(
      status: CallStatus.calling,
      channelId: channelId,
      remoteUserId: remoteUserId,
      remoteUserName: remoteUserName,
      remoteAvatarUrl: remoteAvatarUrl,
      lastCallAt: DateTime.now(),
    );
    notifyListeners();

    try {
      final repo = _ref.read(buzzRepositoryProvider);
      final res = await repo.initiateDirectCall(remoteUserId);
      if (_state.status != CallStatus.calling ||
          _state.remoteUserId != remoteUserId) {
        return;
      }

      final buzzId = res['buzzId'] as String?;
      final token = res['token'] as String?;

      _state = _state.copyWith(buzzId: buzzId, token: token);
      notifyListeners();

      _callEventsSub = repo.callEvents.listen(_handleCallSignal);
      _ringTimer = Timer(ringTimeout, () {
        if (_state.status == CallStatus.calling && _state.buzzId == buzzId) {
          unawaited(cancelCall());
        }
      });
    } catch (e) {
      endCall();
    }
  }

  void _handleCallSignal(Map<String, dynamic> event) {
    final Object? rawBuzzId =
        event['buzzId'] ?? event['buzz_id'] ?? event['id'];
    final String? eventBuzzId = rawBuzzId is String ? rawBuzzId : null;
    final Object? rawToken = event['token'];
    final String? token = rawToken is String ? rawToken : null;
    final String type =
        (event['type'] ?? event['event'] ?? event['status'] ?? '')
            .toString()
            .toLowerCase();

    if (type == 'accepted' ||
        type == 'accept' ||
        type == 'call_accepted' ||
        type == 'direct_call_accepted' ||
        type == 'buzz_accepted') {
      onRemoteCallAccepted(buzzId: eventBuzzId, token: token);
    } else if (type == 'declined' ||
        type == 'decline' ||
        type == 'rejected' ||
        type == 'reject' ||
        type == 'call_declined' ||
        type == 'direct_call_declined' ||
        type == 'ended' ||
        type == 'call_ended' ||
        type == 'buzz_ended' ||
        type == 'missed') {
      onRemoteCallDeclined(buzzId: eventBuzzId);
    }
  }

  void onRemoteCallAccepted({String? buzzId, String? token}) {
    if (_state.status != CallStatus.calling) return;
    if (_state.buzzId != null && buzzId != null && _state.buzzId != buzzId) {
      return;
    }

    _ringTimer?.cancel();
    _ringTimer = null;
    _state = _state.copyWith(
      status: CallStatus.active,
      token: token ?? _state.token,
    );
    notifyListeners();
  }

  void onRemoteCallDeclined({String? buzzId}) {
    if (_state.status != CallStatus.calling &&
        _state.status != CallStatus.active) {
      return;
    }
    if (_state.buzzId != null && buzzId != null && _state.buzzId != buzzId) {
      return;
    }

    endCall();
  }

  void receiveIncomingCall({
    required String buzzId,
    required String remoteUserId,
    required String remoteUserName,
    required String channelId,
    String? remoteAvatarUrl,
  }) {
    if (_state.status != CallStatus.none) {
      _ref.read(buzzRepositoryProvider).respondToInvitation(buzzId, false);
      return;
    }

    _state = ActiveCallState(
      status: CallStatus.incoming,
      buzzId: buzzId,
      channelId: channelId,
      remoteUserId: remoteUserId,
      remoteUserName: remoteUserName,
      remoteAvatarUrl: remoteAvatarUrl,
      isFullPage: false,
      lastCallAt: DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> acceptCall() async {
    if (_state.status != CallStatus.incoming) return;

    if (_state.buzzId != null) {
      await _ref
          .read(buzzRepositoryProvider)
          .respondToInvitation(_state.buzzId!, true);
      _state = _state.copyWith(
        status: CallStatus.active,
        token: 'mock-agora-token',
      );
      notifyListeners();
    }
  }

  Future<void> declineCall() async {
    if (_state.status != CallStatus.incoming) return;

    if (_state.buzzId != null) {
      await _ref
          .read(buzzRepositoryProvider)
          .respondToInvitation(_state.buzzId!, false);
    }
    endCall();
  }

  Future<void> cancelCall() async {
    if (_state.status != CallStatus.calling) return;

    final String? buzzId = _state.buzzId;
    if (buzzId != null) {
      await _ref
          .read(buzzRepositoryProvider)
          .respondToDirectCall(buzzId, false);
    }
    endCall();
  }

  void endCall() {
    _cancelTimersAndSubscriptions();
    _state = ActiveCallState(lastCallAt: _state.lastCallAt);
    notifyListeners();
  }

  void _cancelTimersAndSubscriptions() {
    _ringTimer?.cancel();
    _ringTimer = null;
    unawaited(_callEventsSub?.cancel());
    _callEventsSub = null;
  }

  @override
  void dispose() {
    _cancelTimersAndSubscriptions();
    super.dispose();
  }
}

final activeCallProvider = ChangeNotifierProvider<ActiveCallNotifier>((ref) {
  return ActiveCallNotifier(ref);
});
