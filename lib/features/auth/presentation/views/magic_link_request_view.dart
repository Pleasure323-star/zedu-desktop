import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MagicLinkRequestView extends ConsumerStatefulWidget {
  const MagicLinkRequestView({super.key});

  @override
  ConsumerState<MagicLinkRequestView> createState() =>
      _MagicLinkRequestViewState();
}

class _MagicLinkRequestViewState extends ConsumerState<MagicLinkRequestView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onGeneratePressed() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final success = await ref
        .read(magicLinkNotifierProvider.notifier)
        .send(email);
    if (!mounted) return;

    if (success) {
      context.go(AppRouter.magicLinkSent, extra: email);
      return;
    }

    final error = ref.read(magicLinkNotifierProvider).error;
    final message = switch (error) {
      // The backend signals "no account for this email" with a 404. Show a
      // fixed, friendly message instead of the generic "The resource was not
      // found." so the user knows the link was never sent, without putting raw
      // server text (an HTML 404 page or Dio's error) on screen (zeduchat#44).
      ApiFailure(kind: ApiFailureKind.notFound) =>
        "We couldn't find an account with that email.",
      ApiFailure() => error.friendlyMessage,
      Object() => error.toString(),
      null => 'Could not send magic link. Please try again.',
    };

    AppToastService.show(context, type: AppToastType.error, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(magicLinkNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: AuthHeaderStrip(
          promptText: 'Already have an account? ',
          actionText: 'Sign in',
          onActionTap: () => context.go(AppRouter.login),
        ),
      ),
      body: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: context.symmetric(horizontal: 0, vertical: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Login with email link',
                    style: context.textTheme.headlineMedium,
                  ),
                  context.gapV(12),
                  Text(
                    'Please provide your email address to receive the magic link for accessing your account.',
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colors.textPrimary,
                    ),
                  ),
                  context.gapV(36),
                  Form(
                    key: _formKey,
                    child: AppTextField(
                      controller: _emailController,
                      label: 'Email address',
                      hint: 'Enter your email',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      validator: (value) =>
                          Validators.validateEmail(context, value),
                    ),
                  ),
                  context.gapV(22),
                  AppButton(
                    label: 'Generate magic link',
                    loading: isLoading,
                    onPressed: _onGeneratePressed,
                  ),
                  context.gapV(18),
                  RichText(
                    text: TextSpan(
                      text: 'Don\'t have an account? ',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colors.textPrimary,
                      ),
                      children: [
                        TextSpan(
                          text: 'Sign up',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colors.primary,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => context.push(AppRouter.signup),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
