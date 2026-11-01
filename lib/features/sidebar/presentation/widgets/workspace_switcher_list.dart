import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class WorkspaceSwitcherList extends ConsumerWidget {
  const WorkspaceSwitcherList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final workspaceState = ref.watch(workspaceProvider);
    final selectedWorkspace = workspaceState.selectedWorkspace;

    if (selectedWorkspace == null) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentWorkspaceHeader(context, selectedWorkspace),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onPressed: () {
                        final router = GoRouter.of(context);
                        Navigator.pop(context);
                        router.go(AppRouter.profile);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.person_add_alt,
                      label: 'Invite',
                      onPressed: () {
                        Navigator.pop(context);
                        showDialog<void>(
                          context: context,
                          builder: (context) => InviteTeammatesModal(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                'Switch Workspaces',
                style: TextStyle(
                  color: colors.textHint,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // The whole menu scrolls in WorkspaceSwitcherHeader, so the list
            // takes its natural height instead of scrolling on its own.
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: workspaceState.workspaces.length,
              itemBuilder: (context, index) {
                final workspace = workspaceState.workspaces[index];
                final isActive = selectedWorkspace.id == workspace.id;

                return _WorkspaceListItem(
                  workspace: workspace,
                  isActive: isActive,
                  onTap: () {
                    ref
                        .read(workspaceProvider.notifier)
                        .switchWorkspace(workspace);
                    Navigator.pop(context);
                  },
                );
              },
            ),
            Divider(height: 1, color: colors.divider),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentWorkspaceHeader(
    BuildContext context,
    Workspace workspace,
  ) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.grid_view_rounded,
              color: colors.onPrimary,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: workspace.name,
                  child: Text(
                    workspace.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  workspace.channelsLabel,
                  style: TextStyle(color: colors.textHint, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            'Current',
            style: TextStyle(
              color: colors.textHint.withValues(alpha: 0.75),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        context.push(AppRouter.createOrganization);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.add, color: colors.textHint, size: 20),
            const SizedBox(width: 8),
            Text(
              'Add a new organization',
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: colors.textPrimary),
      label: Text(
        label,
        style: TextStyle(color: colors.textPrimary, fontSize: 13),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8),
        side: BorderSide(color: colors.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}

class _WorkspaceListItem extends StatelessWidget {
  final Workspace workspace;
  final bool isActive;
  final VoidCallback onTap;

  const _WorkspaceListItem({
    required this.workspace,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isActive
            ? colors.textPrimary.withValues(alpha: 0.05)
            : Colors.transparent,
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _avatarColor(colors, workspace.name),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      workspace.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                if (workspace.unreadCount > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.error,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.background, width: 2),
                      ),
                      child: Text(
                        '${workspace.unreadCount}',
                        style: TextStyle(
                          color: colors.onPrimary,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Tooltip(
                message: workspace.name,
                child: Text(
                  workspace.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Icon(
              Icons.push_pin,
              size: 16,
              color: isActive
                  ? colors.textHint.withValues(alpha: 0.75)
                  : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }

  Color _avatarColor(AppPalette colors, String name) {
    final palette = [
      colors.accent,
      colors.success,
      colors.primary,
      colors.error,
      colors.borderOutline,
      colors.textSecondary,
    ];
    return palette[name.length % palette.length];
  }
}
