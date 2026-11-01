import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class OrganizationSection extends StatelessWidget {
  const OrganizationSection({
    super.key,
    required this.organization,
    required this.isSaving,
    required this.onSave,
    required this.onDelete,
    required this.onLeave,
  });

  final OrganizationProfile organization;
  final bool isSaving;
  final ValueChanged<OrganizationProfile> onSave;
  final Future<void> Function() onDelete;
  final Future<void> Function() onLeave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionHeader(
          title: 'Your Organization Information',
          subtitle: 'Manage your organization details.',
        ),
        const SizedBox(height: 28),
        ProfileCard(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 480,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OrganizationAvatar(initials: organization.initials),
                    const SizedBox(height: 24),
                    const ProfileFieldLabel('Name'),
                    const SizedBox(height: 4),
                    Text(
                      organization.name,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const ProfileFieldLabel('Nature of business'),
                    const SizedBox(height: 4),
                    Text(
                      organization.natureOfBusiness,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const ProfileFieldLabel('Country'),
                    const SizedBox(height: 4),
                    Text(
                      organization.country,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: SquareIconButton(
                    icon: Icons.edit_outlined,
                    onTap: () => showEditOrganizationDialog(
                      context,
                      organization,
                      onSave,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 48),
        Row(
          children: [
            AppButton.outlined(
              label: 'Sign out of workspace',
              expand: false,
              height: 44,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.textPrimary,
                side: BorderSide(color: context.colors.divider),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              loading: isSaving,
              onPressed: () => _confirmLeave(context, onLeave),
            ),
            const SizedBox(width: 16),
            AppButton.outlined(
              label: 'Delete organization',
              expand: false,
              height: 44,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              loading: isSaving,
              onPressed: () => _confirmDelete(context, onDelete),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmLeave(
    BuildContext context,
    Future<void> Function() onConfirm,
  ) => showProfileConfirmDialog(
    context,
    title: 'Sign out of workspace?',
    message:
        'This will securely sign you out and remove your access from this workspace. You will need to be re-invited to join again.',
    confirmLabel: 'Sign out',
    onConfirm: onConfirm,
    destructive: true,
  );

  Future<void> _confirmDelete(
    BuildContext context,
    Future<void> Function() onConfirm,
  ) => showProfileConfirmDialog(
    context,
    title: 'Delete organization?',
    message:
        'This will remove the organization and its related workspace data.',
    confirmLabel: 'Delete organization',
    onConfirm: onConfirm,
    destructive: true,
  );
}

class _OrganizationAvatar extends StatelessWidget {
  const _OrganizationAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w600,
            color: context.colors.sidebar,
          ),
        ),
      ),
    );
  }
}
