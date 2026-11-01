import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class ChangePasswordView extends ConsumerStatefulWidget {
  const ChangePasswordView({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends ConsumerState<ChangePasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onChangePasswordPressed() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authNotifierProvider.notifier)
        .changePassword(
          email: widget.email,
          oldPassword: _oldPasswordController.text,
          newPassword: _newPasswordController.text,
        );

    if (success && mounted) {
      AppToastService.show(
        context,
        type: AppToastType.success,
        message: 'Password updated successfully!',
      );
      context.go(AppRouter.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        AppToastService.show(
          context,
          type: AppToastType.error,
          message: next.error!,
        );
      }
    });

    final authState = ref.watch(authNotifierProvider);

    // Format the email to mask it like pl***@gmail.com
    final maskedEmail = maskEmail(widget.email);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: context.colors.background,
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset('assets/pngs/zedu_logo.png', width: 83, height: 31),
              Text.rich(
                TextSpan(
                  text: 'Go back to login? ',
                  style: context.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: context.colors.textPrimary,
                    fontFamily: FontFamily.roboto,
                  ),
                  children: [
                    TextSpan(
                      text: 'Sign in',
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: context.colors.primary,
                        fontFamily: FontFamily.roboto,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => context.go(AppRouter.login),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: SizedBox(
            width: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                context.gapV(80),
                Text(
                  'Change password',
                  style: context.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                context.gapV(12),
                Text(
                  'Verify your identity using your current password',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                context.gapV(8),
                Text(
                  'Account: $maskedEmail',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                context.gapV(48),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        isPassword: true,
                        controller: _oldPasswordController,
                        label: 'Enter current password',
                        hint: 'Current Password',
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your current password';
                          }
                          return null;
                        },
                      ),
                      context.gapV(16),
                      AppTextField(
                        isPassword: true,
                        controller: _newPasswordController,
                        label: 'Enter new password',
                        hint: 'New Password',
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            Validators.validatePassword(context, value),
                      ),
                      context.gapV(16),
                      AppTextField(
                        isPassword: true,
                        controller: _confirmPasswordController,
                        label: 'Confirm new password',
                        hint: 'Confirm new Password',
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (value != _newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      context.gapV(32),
                      AppButton(
                        label: 'Change password',
                        loading: authState.isLoading,
                        onPressed: _onChangePasswordPressed,
                      ),
                      context.gapV(16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: context.colors.divider),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => context.go(AppRouter.login),
                          child: Text(
                            'Back to Login',
                            style: context.textTheme.titleMedium?.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      context.gapV(32),
                      Center(
                        child: Text.rich(
                          TextSpan(
                            text: 'Try another way? ',
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colors.textPrimary,
                              fontWeight: FontWeight.w400,
                            ),
                            children: [
                              TextSpan(
                                text: 'Reset using OTP code',
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: context.colors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    context.go(
                                      AppRouter.resetPassword,
                                      extra: widget.email,
                                    );
                                  },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                context.gapV(48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
