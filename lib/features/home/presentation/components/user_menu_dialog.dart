import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class UserMenuDialog extends ConsumerWidget {
  const UserMenuDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final authUser = ref.watch(authNotifierProvider).user;
    final balance = ref.watch(orgCreditBalanceProvider);
    final displayName = authUser?.fullname ?? 'AnonymousUser';
    final status = authUser?.status ?? UserStatus.empty;
    final orgSlug = authUser?.currentOrganisationSlug ?? '';
    final signOutTarget = orgSlug.isEmpty ? 'Zedu' : orgSlug;
    final isOnline = status.online;

    return Dialog(
      insetPadding: const EdgeInsets.only(bottom: 24, left: 74),
      alignment: Alignment.bottomLeft,
      backgroundColor: colors.background,
      child: Container(
        width: 320,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Profile header ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    // Avatar with presence dot overlay
                    Stack(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colors.sidebar,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: PresenceDot(online: isOnline, size: 12),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // Presence label
                          Text(
                            isOnline ? 'Active' : 'Away',
                            style: TextStyle(
                              color: isOnline
                                  ? colors.presenceActive
                                  : colors.textHint,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$balance AI credits',
                                style: TextStyle(
                                  color: colors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 0, color: colors.divider),
              const SizedBox(height: 8),

              // ── Custom status row ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    Navigator.pop(context);
                    await showDialog<void>(
                      context: context,
                      builder: (_) => const SetStatusDialog(),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        if (status.hasCustomStatus)
                          Text(
                            status.emoji ?? '😶',
                            style: const TextStyle(fontSize: 18),
                          )
                        else
                          Icon(
                            Icons.sentiment_satisfied_alt_outlined,
                            color: colors.textHint,
                            size: 20,
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            status.hasCustomStatus
                                ? (status.text ?? 'Status set')
                                : 'Update your status',
                            style: TextStyle(
                              color: status.hasCustomStatus
                                  ? colors.textPrimary
                                  : colors.textHint,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Clear status (only visible when status is set) ─────────────
              if (status.hasCustomStatus)
                _MenuItemButton(
                  icon: Icons.clear_all_outlined,
                  label: 'Clear status',
                  onTap: () async {
                    Navigator.pop(context);
                    await ref.read(authNotifierProvider.notifier).clearStatus();
                  },
                ),

              // ── Set yourself as active / away toggle ──────────────────────
              _MenuItemButton(
                icon: isOnline
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                label: isOnline
                    ? 'Set yourself as away'
                    : 'Set yourself as active',
                iconColor: isOnline ? colors.presenceActive : colors.textHint,
                onTap: () async {
                  Navigator.pop(context);
                  await ref
                      .read(authNotifierProvider.notifier)
                      .toggleOnlineStatus();
                },
              ),

              // ── Pause notifications ────────────────────────────────────────
              _MenuItemButton(
                icon: Icons.notifications_off_outlined,
                label: 'Pause notifications',
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(notificationSettingsProvider.notifier)
                      .setDndMode(const Duration(hours: 1));
                },
              ),
              const SizedBox(height: 8),
              Divider(height: 0, color: colors.divider),
              const SizedBox(height: 8),

              // ── Settings shortcuts ─────────────────────────────────────────
              _MenuItemButton(
                icon: Icons.person_outline,
                label: 'Profile…',
                onTap: () {
                  Navigator.pop(context);
                  ref.read(personalProfilePanelProvider.notifier).state = true;
                },
              ),
              _MenuItemButton(
                icon: Icons.settings_outlined,
                label: 'Preferences…',
                onTap: () {
                  Navigator.pop(context);
                  if (context.mounted) context.go(AppRouter.profile);
                },
              ),
              _MenuItemButton(
                icon: Icons.shopping_cart_outlined,
                label: 'Buy AI credits',
                isHighlight: true,
                onTap: () {
                  Navigator.pop(context);
                  if (context.mounted) context.go(AppRouter.buyCredits);
                },
              ),
              const SizedBox(height: 8),
              Divider(height: 0, color: colors.divider),
              const SizedBox(height: 8),

              // ── Sign out ───────────────────────────────────────────────────
              _MenuItemButton(
                icon: Icons.logout_rounded,
                label: 'Sign out of $signOutTarget',
                isError: true,
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(authNotifierProvider.notifier).logout();
                  if (context.mounted) context.go(AppRouter.login);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Internal helper widget ─────────────────────────────────────────────────────

class _MenuItemButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool isHighlight;
  final bool isError;

  const _MenuItemButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.isHighlight = false,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final itemColor = isError
        ? colors.error
        : (isHighlight ? colors.accent : colors.textPrimary);
    final resolvedIconColor = iconColor ?? itemColor;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: resolvedIconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: itemColor,
                  fontSize: 13,
                  fontWeight: isHighlight || isError
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
