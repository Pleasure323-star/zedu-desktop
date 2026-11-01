import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class UserProfileView extends ConsumerWidget {
  const UserProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<UserProfileState>(userProfileNotifierProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          AppToastService.show(
            context,
            type: AppToastType.error,
            message: next.error!,
          );
        });
      }
      if (next.successMessage != null &&
          previous?.successMessage != next.successMessage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          AppToastService.show(
            context,
            type: AppToastType.success,
            message: next.successMessage!,
          );
        });
      }
    });

    final state = ref.watch(userProfileNotifierProvider);
    final notifier = ref.read(userProfileNotifierProvider.notifier);

    return ProfileSettingsShell(
      selectedSection: state.section,
      onSectionSelected: notifier.selectSection,
      child: _ProfileContent(state: state, notifier: notifier),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.state, required this.notifier});

  final UserProfileState state;
  final UserProfileNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final organization = state.organization;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 40, 48),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: switch (state.section) {
            UserProfileSection.account => AccountSection(
              account: state.account ?? ProfileAccount.empty(),
              isSaving: state.isSaving,
              onSave: notifier.updateAccount,
              onDelete: notifier.deleteAccount,
            ),
            UserProfileSection.notifications => NotificationsSection(
              preferences:
                  state.notifications ?? NotificationPreferences.empty(),
              isSaving: state.isSaving,
              onSave: notifier.updateNotificationPreferences,
              onRevert: notifier.revertNotificationPreferences,
            ),
            UserProfileSection.security => SecuritySection(
              sessions: state.securitySessions,
              isSaving: state.isSaving,
              onChangePassword: notifier.changePassword,
            ),
            UserProfileSection.organization =>
              organization == null
                  ? _OrganizationLoadError(
                      isLoading: state.isLoading,
                      onRetry: notifier.load,
                    )
                  : OrganizationSection(
                      organization: organization,
                      isSaving: state.isSaving,
                      onSave: notifier.updateOrganization,
                      onDelete: notifier.deleteOrganization,
                      onLeave: notifier.leaveOrganization,
                    ),
            UserProfileSection.userManagement => UserManagementSection(
              members: state.teamMembers,
              isSaving: state.isSaving,
              onInvite: notifier.inviteMember,
              onUpdate: notifier.updateMember,
              onRemove: notifier.removeMember,
            ),
            UserProfileSection.rolesAndPermissions =>
              RolesAndPermissionsSection(roles: state.rolesAndPermissions),
            UserProfileSection.billing => BillingSection(
              billing: state.billing ?? BillingInfo.empty(),
              onInvite: notifier.inviteMember,
            ),
          },
        ),
      ),
    );
  }
}

/// Shown instead of made-up values when the organization details can't be
/// loaded.
class _OrganizationLoadError extends StatelessWidget {
  const _OrganizationLoadError({
    required this.isLoading,
    required this.onRetry,
  });

  final bool isLoading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "We couldn't load your organization details.",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text('Check your connection and try again.'),
        const SizedBox(height: 16),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
