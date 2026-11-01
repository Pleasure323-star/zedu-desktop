import 'package:zedu/core/core.dart';

import '../../data/models/workspace.dart';
import 'workspace_state.dart';

class WorkspaceNotifier extends Notifier<WorkspaceState> {
  static const loadErrorMessage = "Couldn't load your organisations";

  @override
  WorkspaceState build() {
    Future.microtask(fetchWorkspaces);
    return const WorkspaceState(isLoading: true);
  }

  Future<void> fetchWorkspaces() async {
    if (locator<AppConfig>().usesMockData) {
      state = _mockState();
      return;
    }

    state = WorkspaceState(
      workspaces: state.workspaces,
      selectedWorkspace: state.selectedWorkspace,
      isLoading: true,
    );
    try {
      final api = locator<ApiBaseService>();
      final response = await api.get<Map<String, dynamic>>(
        path: '/users/organisations',
      );
      final data = response.data['data'] as List<dynamic>? ?? [];

      final List<Workspace> workspaces = [];
      for (var item in data) {
        if (item is Map<String, dynamic>) {
          workspaces.add(
            Workspace(
              id: item['id'] as String? ?? '1',
              name: item['name'] as String? ?? 'Workspace',
              avatar: item['logo_url'] as String? ?? '',
              channelsCount: (item['channels_count'] as num?)?.toInt() ?? 0,
            ),
          );
        }
      }

      // Keep the current selection if it's still in the list (e.g. an org
      // created while this request was in flight).
      final previousId = state.selectedWorkspace?.id;
      final selected = workspaces.isEmpty
          ? null
          : workspaces.firstWhere(
              (ws) => ws.id == previousId,
              orElse: () => workspaces.first,
            );

      state = WorkspaceState(
        workspaces: workspaces,
        selectedWorkspace: selected,
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to load organisations',
        tag: 'WorkspaceNotifier',
        error: e,
        stackTrace: stackTrace,
      );
      state = const WorkspaceState(errorMessage: loadErrorMessage);
    }
  }

  // Demo organisations, only used when the app runs with USE_MOCK_DATA.
  WorkspaceState _mockState() {
    final workspaces = [
      const Workspace(
        id: '1',
        name: 'HNG Workspace',
        avatar: '',
        unreadCount: 1351,
        channelsCount: 1351,
      ),
      const Workspace(
        id: '2',
        name: 'TeamFlow Collective',
        avatar: '',
        unreadCount: 15,
        channelsCount: 42,
      ),
      const Workspace(
        id: '3',
        name: 'Coffee & Code House',
        avatar: '',
        unreadCount: 0,
        channelsCount: 12,
      ),
      const Workspace(
        id: '4',
        name: 'ConnectHub',
        avatar: '',
        unreadCount: 3,
        channelsCount: 89,
      ),
    ];

    return WorkspaceState(
      workspaces: workspaces,
      selectedWorkspace: workspaces.first,
    );
  }

  void addWorkspace(Workspace workspace, {bool switchTo = true}) {
    final current = state.workspaces;
    if (current.any((w) => w.id == workspace.id)) return;
    final updated = [...current, workspace];
    state = state.copyWith(
      workspaces: updated,
      selectedWorkspace: switchTo ? workspace : state.selectedWorkspace,
    );
  }

  Future<void> switchWorkspace(Workspace workspace) async {
    if (state.selectedWorkspace?.id == workspace.id) return;

    state = state.copyWith(isLoading: true);

    await Future<void>.delayed(const Duration(milliseconds: 300));

    state = state.copyWith(selectedWorkspace: workspace, isLoading: false);
  }

  void removeWorkspace(String id) {
    final updatedWorkspaces = state.workspaces
        .where((w) => w.id != id)
        .toList();
    Workspace? nextSelected = state.selectedWorkspace;
    if (state.selectedWorkspace?.id == id) {
      nextSelected = updatedWorkspaces.isNotEmpty
          ? updatedWorkspaces.first
          : null;
    }
    state = state.copyWith(
      workspaces: updatedWorkspaces,
      selectedWorkspace: nextSelected,
    );
  }
}

final workspaceProvider = NotifierProvider<WorkspaceNotifier, WorkspaceState>(
  WorkspaceNotifier.new,
);
