import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final currentOrgIdProvider = Provider<String>((ref) {
  final workspace = ref.watch(workspaceProvider).selectedWorkspace;
  return workspace?.id ?? '';
});

final dmListProvider =
    AsyncNotifierProvider<DmListNotifier, List<DmConversation>>(() {
      return DmListNotifier();
    });

class SelectedDmNotifier extends Notifier<DmConversation?> {
  @override
  DmConversation? build() => null;

  void select(DmConversation? conversation) {
    state = conversation;
  }
}

final selectedDmProvider =
    NotifierProvider<SelectedDmNotifier, DmConversation?>(
      SelectedDmNotifier.new,
    );

class DmConversationActions {
  final Set<String> pinnedIds;
  final Set<String> deletedIds;

  const DmConversationActions({
    this.pinnedIds = const {},
    this.deletedIds = const {},
  });

  DmConversationActions copyWith({
    Set<String>? pinnedIds,
    Set<String>? deletedIds,
  }) => DmConversationActions(
    pinnedIds: pinnedIds ?? this.pinnedIds,
    deletedIds: deletedIds ?? this.deletedIds,
  );
}

class DmConversationActionsNotifier extends Notifier<DmConversationActions> {
  @override
  DmConversationActions build() => const DmConversationActions();

  void togglePinned(String channelId) {
    final ids = Set<String>.from(state.pinnedIds);
    ids.contains(channelId) ? ids.remove(channelId) : ids.add(channelId);
    state = state.copyWith(pinnedIds: ids);
  }

  /// Deletes the conversation on the server, then hides it from the list
  /// until the next refresh drops it and discards its draft. Closes it only
  /// if it's still the open DM. Returns false if the request failed.
  Future<bool> delete(String channelId) async {
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId.isEmpty) return false;
    try {
      await ref
          .read(dmRepositoryProvider)
          .deleteConversation(orgId: orgId, channelId: channelId);
    } catch (_) {
      return false;
    }
    state = state.copyWith(deletedIds: {...state.deletedIds, channelId});
    ref.read(dmDraftStoreProvider).clear(channelId);
    if (ref.read(selectedDmProvider)?.channelId == channelId) {
      ref.read(selectedDmProvider.notifier).select(null);
    }
    return true;
  }
}

final dmConversationActionsProvider =
    NotifierProvider<DmConversationActionsNotifier, DmConversationActions>(
      DmConversationActionsNotifier.new,
    );

class DmListNotifier extends AsyncNotifier<List<DmConversation>> {
  int _currentPage = 1;
  bool _hasMore = true;

  bool get hasMore => _hasMore;

  @override
  Future<List<DmConversation>> build() async {
    final orgId = ref.watch(currentOrgIdProvider);
    if (orgId.isEmpty) return const [];

    _currentPage = 1;
    _hasMore = true;
    return _fetchPage(orgId, 1);
  }

  Future<List<DmConversation>> _fetchPage(String orgId, int page) async {
    final repository = ref.read(dmRepositoryProvider);
    final results = await repository.getConversations(orgId: orgId, page: page);
    if (results.length < DmRepository.pageSize) {
      _hasMore = false;
    }

    if (results.isEmpty && page == 1) {
      return [
        DmConversation(
          channelId: 'mock-channel-id-123',
          username: 'Test User',
          participantId: 'mock-user-id',
          previewMessage:
              'This is a test conversation. Tap to test the composer.',
          unreadCount: 0,
        ),
      ];
    }

    return results;
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId.isEmpty) return;

    final current = state.value ?? [];
    _currentPage++;
    final next = await _fetchPage(orgId, _currentPage);
    state = AsyncValue.data([...current, ...next]);
  }

  Future<void> refresh() async {
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId.isEmpty) return;

    _currentPage = 1;
    _hasMore = true;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchPage(orgId, 1));
  }
}
