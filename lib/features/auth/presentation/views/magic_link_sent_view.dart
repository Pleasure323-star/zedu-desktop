import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MagicLinkSentView extends StatelessWidget {
  const MagicLinkSentView({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
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
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: context.symmetric(horizontal: 0, vertical: 170),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Check your email',
                    style: context.textTheme.headlineMedium,
                  ),
                  context.gapV(40),
                  Container(
                    width: 238,
                    height: 238,
                    decoration: const BoxDecoration(
                      color: Color(0xFF23B444),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 92,
                    ),
                  ),
                  context.gapV(48),
                  Text.rich(
                    TextSpan(
                      text: 'We\'ve sent a sign-in link to ',
                      style: context.textTheme.headlineSmall?.copyWith(
                        color: context.colors.textHint,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(
                          text: email,
                          style: context.textTheme.headlineSmall?.copyWith(
                            color: context.colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text:
                              '. Open the email and click the link to continue.',
                          style: context.textTheme.headlineSmall?.copyWith(
                            color: context.colors.textHint,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
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
