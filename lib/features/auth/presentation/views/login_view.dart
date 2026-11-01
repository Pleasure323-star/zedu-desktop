import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    if (ref.read(authNotifierProvider).isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    ref
        .read(authNotifierProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          rememberMe: _rememberMe,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (previous?.status != AuthStatus.authenticated &&
          next.status == AuthStatus.authenticated) {
        AppToastService.show(
          context,
          type: AppToastType.success,
          message: 'Logged in successfully!',
        );
        context.go(AppRouter.home);
      }
      if (next.error != null && previous?.error != next.error) {
        AppToastService.show(
          context,
          type: AppToastType.error,
          message: next.error!,
        );
      }
    });

    final authState = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    if (authState.status == AuthStatus.unknown) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

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
                  text: "Don't have an account? ",
                  style: context.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: context.colors.textPrimary,
                    fontFamily: FontFamily.roboto,
                  ),
                  children: [
                    TextSpan(
                      text: 'Sign up',
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: context.colors.primary,
                        fontFamily: FontFamily.roboto,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: SizedBox(
            width: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                context.gapV(136),
                Text('Login to Zedu', style: context.textTheme.headlineMedium),
                context.gapV(8),
                Text(
                  'Welcome back! We’ve missed you!',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                context.gapV(32),
                SocialAuthButton(
                  icon: 'assets/svgs/google_logo.svg',
                  label: 'Sign in with Google',
                  loading: authState.isLoading,
                  onPressed: () =>
                      ref.read(authNotifierProvider.notifier).loginWithGoogle(),
                ),
                context.gapV(12),
                SocialAuthButton(
                  icon: 'assets/svgs/apple_logo.svg',
                  label: 'Sign in with Apple',
                  onPressed: () => AppToastService.show(
                    context,
                    type: AppToastType.info,
                    message: 'Apple sign in is not available yet.',
                  ),
                ),
                context.gapV(26),
                Padding(
                  padding: context.symmetric(horizontal: 100, vertical: 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: context.colors.divider,
                          height: 0.67,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR',
                          style: textTheme.bodySmall?.copyWith(
                            color: Color(
                              (((theme.colorScheme.onSurface as dynamic).value
                                          as int) &
                                      0x00FFFFFF) |
                                  (((0.72 * 255).round() & 0xFF) << 24),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: context.colors.divider,
                          height: 0.67,
                        ),
                      ),
                    ],
                  ),
                ),
                context.gapV(26),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: _emailController,
                        label: 'Email address',
                        hint: 'Enter your email address',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            Validators.validateEmail(context, value),
                      ),
                      context.gapV(16),
                      AppTextField(
                        isPassword: true,
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Password',
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _onLoginPressed(),
                        validator: (value) => Validators.validateRequired(
                          context,
                          value?.trim(),
                          fieldName: 'Password',
                        ),
                      ),
                      context.gapV(8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                              ),
                              const Text('Remember me'),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => context.push(AppRouter.forgotPassword),
                            child: Text(
                              'Forgot Password?',
                              style: context.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w400,
                                color: context.colors.primary,
                                fontFamily: FontFamily.roboto,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                context.gapV(18),
                AppButton(
                  label: 'Login',
                  loading: authState.isLoading,
                  onPressed: _onLoginPressed,
                ),
                context.gapV(12),
                Align(
                  alignment: Alignment.topLeft,
                  child: InkWell(
                    onTap: () => context.go(AppRouter.magicLinkRequest),
                    child: Text(
                      'Login with magic link',
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: context.colors.primary,
                        fontFamily: FontFamily.roboto,
                      ),
                    ),
                  ),
                ),
                context.gapV(32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    GestureDetector(
                      onTap: () => context.push(AppRouter.signup),
                      child: Text(
                        'Sign up',
                        style: TextStyle(
                          color: context.colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                context.gapV(32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
