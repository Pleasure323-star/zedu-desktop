import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class PersonalProfilePanel extends ConsumerWidget {
  const PersonalProfilePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profileState = ref.watch(userProfileNotifierProvider);
    final account = profileState.account ?? ProfileAccount.empty();
    // Same sources as the avatar menu, so the status here and there always agree.
    final status =
        ref.watch(authNotifierProvider).user?.status ?? UserStatus.empty;
    final isOnline = status.online;
    final notificationsPaused = ref
        .watch(notificationSettingsProvider)
        .isDndActive;

    final displayName = account.displayName.isNotEmpty
        ? account.displayName
        : account.name;
    final roleTitle = account.title.isNotEmpty ? account.title : 'Member';

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: colors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(-4, 0),
          ),
        ],
        border: Border(left: BorderSide(color: colors.divider)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                Text(
                  'Profile',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    ref.read(personalProfilePanelProvider.notifier).state =
                        false;
                  },
                  icon: Icon(Icons.close, size: 18, color: colors.textHint),
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ],
            ),
          ),

          // Scrollable body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(Icons.person, size: 80, color: colors.accent),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name and edit button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _openEditDialog(context, ref, account),
                        borderRadius: BorderRadius.circular(4),
                        child: Text(
                          'Edit',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Role/Title
                  Text(
                    roleTitle,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Status row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        notificationsPaused
                            ? Icons.notifications_off_outlined
                            : Icons.notifications_none,
                        size: 14,
                        color: colors.textHint,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          notificationsPaused
                              ? '${isOnline ? 'Active' : 'Away'}, Notifications paused'
                              : (isOnline ? 'Active' : 'Away'),
                          textAlign: TextAlign.center,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: colors.textHint,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Time icon
                  Icon(Icons.access_time, size: 14, color: colors.textHint),
                  const SizedBox(height: 16),

                  // Your own profile: no Favourite (that's for other people).
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ActionChip(
                        icon: notificationsPaused
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        label: notificationsPaused ? 'Unmute' : 'Mute',
                        tooltip: notificationsPaused
                            ? 'Resume notifications'
                            : 'Pause notifications for 1 hour',
                        colors: colors,
                        onTap: () => _toggleNotifications(
                          context,
                          ref,
                          notificationsPaused,
                        ),
                      ),
                      _ActionChip(
                        icon: isOnline
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        label: isOnline ? 'Hide' : 'Show',
                        tooltip: isOnline
                            ? 'Set yourself as away'
                            : 'Set yourself as active',
                        colors: colors,
                        onTap: () => _toggleAway(context, ref, isOnline),
                      ),
                      _ActionChip(
                        icon: Icons.description_outlined,
                        label: 'View Files',
                        tooltip: 'Open your files',
                        colors: colors,
                        onTap: () => _viewFiles(ref),
                      ),
                      _ActionChip(
                        icon: Icons.copy_outlined,
                        label: '',
                        tooltip: account.username.trim().isNotEmpty
                            ? 'Copy your username'
                            : 'Copy your email',
                        colors: colors,
                        onTap: () => _copyHandle(context, account),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Contact Information section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Contact Information',
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Phone
                  _ContactRow(
                    icon: Icons.phone_outlined,
                    label: account.phoneNumber.isNotEmpty
                        ? account.phoneNumber
                        : 'Not provided',
                    colors: colors,
                    context: context,
                  ),
                  const SizedBox(height: 8),

                  // Email
                  _ContactRow(
                    icon: Icons.email_outlined,
                    label: account.email,
                    colors: colors,
                    context: context,
                    isLink: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Like "Pause notifications" in the avatar menu, or resumes them.
  void _toggleNotifications(BuildContext context, WidgetRef ref, bool paused) {
    final settings = ref.read(notificationSettingsProvider.notifier);
    if (paused) {
      settings.clearDndMode();
    } else {
      settings.setDndMode(const Duration(hours: 1));
    }
    AppToastService.show(
      context,
      type: AppToastType.success,
      message: paused
          ? 'Notifications resumed'
          : 'Notifications paused for 1 hour',
    );
  }

  /// Like "Set yourself as away" in the avatar menu; says if it fails.
  Future<void> _toggleAway(
    BuildContext context,
    WidgetRef ref,
    bool wasOnline,
  ) async {
    await ref.read(authNotifierProvider.notifier).toggleOnlineStatus();
    if (!context.mounted) return;
    final online =
        (ref.read(authNotifierProvider).user?.status ?? UserStatus.empty)
            .online;
    final changed = online != wasOnline;
    AppToastService.show(
      context,
      type: changed ? AppToastType.success : AppToastType.error,
      message: changed
          ? (online ? 'You are now active' : 'You are now away')
          : "Couldn't change your status. Please try again.",
    );
  }

  /// Opens the Files tab (like the sidebar's Files button) and closes the panel.
  void _viewFiles(WidgetRef ref) {
    ref.read(homeSidebarProvider.notifier).setType(HomeSidebarType.files);
    ref.read(personalProfilePanelProvider.notifier).state = false;
  }

  /// Copies the user's @username, or their email when there's no username.
  Future<void> _copyHandle(BuildContext context, ProfileAccount account) async {
    final username = account.username.trim();
    final text = username.isNotEmpty ? '@$username' : account.email.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    AppToastService.show(
      context,
      type: AppToastType.success,
      message: 'Copied $text',
    );
  }

  void _openEditDialog(
    BuildContext context,
    WidgetRef ref,
    ProfileAccount account,
  ) {
    showEditProfileDialog(context, account, (updated) {
      ref.read(userProfileNotifierProvider.notifier).updateAccount(updated);
    });
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final AppPalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: colors.divider),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: colors.textSecondary),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.colors,
    required this.context,
    this.isLink = false,
  });

  final IconData icon;
  final String label;
  final AppPalette colors;
  final BuildContext context;
  final bool isLink;

  @override
  Widget build(BuildContext buildContext) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.textHint),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: buildContext.textTheme.bodySmall?.copyWith(
              color: isLink ? colors.primary : colors.textPrimary,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(4),
          child: Icon(Icons.copy_outlined, size: 14, color: colors.textHint),
        ),
      ],
    );
  }
}
