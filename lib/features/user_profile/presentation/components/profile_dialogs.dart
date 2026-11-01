import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Shows a confirmation dialog and calls [onConfirm] if user agrees.
Future<void> showProfileConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required Future<void> Function() onConfirm,
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        title,
        style: context.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(message, style: context.textTheme.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: confirmLabel,
          expand: false,
          height: 40,
          style: ElevatedButton.styleFrom(
            backgroundColor: destructive ? const Color(0xFFEF4444) : null,
          ),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
  if (confirmed == true) await onConfirm();
}

/// Dialog for editing account information.
Future<void> showEditAccountDialog(
  BuildContext context,
  ProfileAccount account,
  ValueChanged<ProfileAccount> onSave,
) async {
  final nameCtrl = TextEditingController(text: account.name);
  final emailCtrl = TextEditingController(text: account.email);
  final timezoneCtrl = TextEditingController(text: account.timezone);
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        'Edit Account',
        style: ctx.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: 'Name',
                controller: nameCtrl,
                hint: 'Enter your full name',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Email Address',
                controller: emailCtrl,
                hint: 'Enter your email',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  return Validators.validateEmail(context, v.trim());
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Timezone',
                controller: timezoneCtrl,
                hint: 'e.g. Africa/Lagos',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: 'Save changes',
          expand: false,
          height: 40,
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              onSave(
                account.copyWith(
                  name: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  timezone: timezoneCtrl.text.trim(),
                ),
              );
              Navigator.pop(ctx);
            }
          },
        ),
      ],
    ),
  );

  nameCtrl.dispose();
  emailCtrl.dispose();
  timezoneCtrl.dispose();
}

/// Dialog for changing password.
Future<void> showChangePasswordDialog(
  BuildContext context,
  Future<void> Function({
    required String currentPassword,
    required String newPassword,
  })
  onSave,
) async {
  final currentCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool hasAttemptedSubmit = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Change password',
          style: ctx.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    label: 'Current Password',
                    controller: currentCtrl,
                    hint: 'Enter current password',
                    isPassword: true,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'New Password',
                    controller: newCtrl,
                    hint: 'Enter new password',
                    isPassword: true,
                    onChanged: (_) {
                      setDialogState(() {});
                      if (hasAttemptedSubmit) {
                        formKey.currentState?.validate();
                      }
                    },
                    validator: (v) => Validators.validatePassword(ctx, v),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Password requirements',
                    style: ctx.textTheme.bodySmall?.copyWith(
                      color: ctx.colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...Validators.passwordRequirements(newCtrl.text).map(
                    (requirement) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            requirement.isMet
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 16,
                            color: requirement.isMet
                                ? ctx.colors.primary
                                : ctx.colors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              requirement.label,
                              style: ctx.textTheme.bodySmall?.copyWith(
                                color: ctx.colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppTextField(
                    label: 'Confirm New Password',
                    controller: confirmCtrl,
                    hint: 'Re-enter new password',
                    isPassword: true,
                    onChanged: (_) {
                      setDialogState(() {});
                      if (hasAttemptedSubmit) {
                        formKey.currentState?.validate();
                      }
                    },
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please confirm your new password';
                      }
                      if (v != newCtrl.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  if (!hasAttemptedSubmit &&
                      confirmCtrl.text.isNotEmpty &&
                      confirmCtrl.text != newCtrl.text)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Passwords do not match',
                        style: ctx.textTheme.bodySmall?.copyWith(
                          color: ctx.colors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Update Password',
            expand: false,
            height: 40,
            onPressed: () async {
              setDialogState(() {
                hasAttemptedSubmit = true;
              });

              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx);
                await onSave(
                  currentPassword: currentCtrl.text,
                  newPassword: newCtrl.text,
                );
              }
            },
          ),
        ],
      ),
    ),
  );

  currentCtrl.dispose();
  newCtrl.dispose();
  confirmCtrl.dispose();
}

/// Dialog for editing organization information.
Future<void> showEditOrganizationDialog(
  BuildContext context,
  OrganizationProfile organization,
  ValueChanged<OrganizationProfile> onSave,
) async {
  final nameCtrl = TextEditingController(text: organization.name);
  final businessCtrl = TextEditingController(
    text: organization.natureOfBusiness,
  );
  final countryCtrl = TextEditingController(text: organization.country);
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        'Edit Organization',
        style: ctx.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: 'Organization Name',
                controller: nameCtrl,
                hint: 'Enter organization name',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Nature of Business',
                controller: businessCtrl,
                hint: 'e.g. Design agency',
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Country',
                controller: countryCtrl,
                hint: 'e.g. Nigeria',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: 'Save changes',
          expand: false,
          height: 40,
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              onSave(
                organization.copyWith(
                  name: nameCtrl.text.trim(),
                  natureOfBusiness: businessCtrl.text.trim(),
                  country: countryCtrl.text.trim(),
                ),
              );
              Navigator.pop(ctx);
            }
          },
        ),
      ],
    ),
  );

  nameCtrl.dispose();
  businessCtrl.dispose();
  countryCtrl.dispose();
}

/// Dialog for inviting a team member.
Future<void> showInviteMemberDialog(
  BuildContext context,
  Future<void> Function({required String email, required String role}) onInvite,
) async {
  final emailCtrl = TextEditingController();
  String role = 'User';
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Invite Team Member',
          style: ctx.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  label: 'Email Address',
                  controller: emailCtrl,
                  hint: 'Enter email address',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Email is required';
                    }
                    return Validators.validateEmail(context, v.trim());
                  },
                ),
                const SizedBox(height: 16),
                ProfileFieldLabel('Role'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Administrator',
                      child: Text('Administrator'),
                    ),
                    DropdownMenuItem(value: 'Manager', child: Text('Manager')),
                    DropdownMenuItem(value: 'User', child: Text('User')),
                  ],
                  onChanged: (v) => setDialogState(() => role = v ?? 'User'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Send Invite',
            expand: false,
            height: 40,
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx);
                await onInvite(email: emailCtrl.text.trim(), role: role);
              }
            },
          ),
        ],
      ),
    ),
  );

  emailCtrl.dispose();
}

/// Dialog for editing a team member's role.
Future<void> showEditMemberDialog(
  BuildContext context,
  TeamMember member,
  ValueChanged<TeamMember> onUpdate,
) async {
  String role = member.role;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Edit Team Member',
          style: ctx.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.email,
                style: ctx.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ProfileFieldLabel('Role'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Administrator',
                    child: Text('Administrator'),
                  ),
                  DropdownMenuItem(value: 'Manager', child: Text('Manager')),
                  DropdownMenuItem(value: 'User', child: Text('User')),
                ],
                onChanged: (v) => setDialogState(() => role = v ?? member.role),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Save changes',
            expand: false,
            height: 40,
            onPressed: () {
              onUpdate(member.copyWith(role: role));
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ),
  );
}
