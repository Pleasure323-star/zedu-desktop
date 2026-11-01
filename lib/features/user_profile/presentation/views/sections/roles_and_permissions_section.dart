import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class RolesAndPermissionsSection extends StatelessWidget {
  const RolesAndPermissionsSection({super.key, required this.roles});

  final List<RolePermission> roles;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionHeader(
          title: 'Roles & permissions',
          subtitle: 'Define and manage roles and their associated permissions.',
        ),
        const SizedBox(height: 28),
        for (final role in roles) ...[
          _RoleCard(role: role),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role});
  final RolePermission role;

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                role.role,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.keyboard_arrow_right,
                size: 20,
                color: Color(0xFF6B7280),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            role.description,
            style: context.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}
