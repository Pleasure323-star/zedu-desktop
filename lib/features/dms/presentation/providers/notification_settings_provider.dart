import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class NotificationSettings {
  final DateTime? dndUntil;
  final Set<String> mutedParticipantIds;

  const NotificationSettings({
    this.dndUntil,
    this.mutedParticipantIds = const {},
  });

  bool get isDndActive => dndUntil != null && dndUntil!.isAfter(DateTime.now());
  bool isMuted(String participantId) =>
      mutedParticipantIds.contains(participantId);

  NotificationSettings copyWith({
    DateTime? dndUntil,
    Set<String>? mutedParticipantIds,
  }) {
    return NotificationSettings(
      dndUntil: dndUntil ?? this.dndUntil,
      mutedParticipantIds: mutedParticipantIds ?? this.mutedParticipantIds,
    );
  }
}

class NotificationSettingsNotifier extends Notifier<NotificationSettings> {
  static const _mutesKey = 'mutedParticipantIds';
  Timer? _dndExpiry;

  /// Bumped on every rebuild (user or org change); an in-flight load must not
  /// apply state to the next generation's build.
  int _generation = 0;

  @override
  NotificationSettings build() {
    ref.onDispose(() => _dndExpiry?.cancel());
    final generation = ++_generation;
    final store = ref.watch(dmPreferenceStoreProvider);
    if (store != null) {
      unawaited(() async {
        final restored = await store.load(_mutesKey);
        if (_generation != generation || restored.isEmpty) return;
        state = NotificationSettings(
          dndUntil: state.dndUntil,
          mutedParticipantIds: restored,
        );
      }());
    }
    return const NotificationSettings();
  }

  /// Pauses notifications; the pause ends by itself when it runs out.
  void setDndMode(Duration duration) {
    state = state.copyWith(dndUntil: DateTime.now().add(duration));
    _dndExpiry?.cancel();
    _dndExpiry = Timer(duration, clearDndMode);
  }

  void clearDndMode() {
    _dndExpiry?.cancel();
    _dndExpiry = null;
    state = NotificationSettings(
      dndUntil: null,
      mutedParticipantIds: state.mutedParticipantIds,
    );
  }

  void muteParticipant(String participantId) {
    final newMuted = Set<String>.from(state.mutedParticipantIds)
      ..add(participantId);
    state = state.copyWith(mutedParticipantIds: newMuted);
    // Persist so mutes survive a restart; storage failures are ignored.
    final store = ref.read(dmPreferenceStoreProvider);
    if (store != null) unawaited(store.save(_mutesKey, newMuted));
  }

  void unmuteParticipant(String participantId) {
    final newMuted = Set<String>.from(state.mutedParticipantIds)
      ..remove(participantId);
    state = state.copyWith(mutedParticipantIds: newMuted);
    final store = ref.read(dmPreferenceStoreProvider);
    if (store != null) unawaited(store.save(_mutesKey, newMuted));
  }

  bool isMuted(String participantId) {
    return state.mutedParticipantIds.contains(participantId);
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
      NotificationSettingsNotifier.new,
    );
