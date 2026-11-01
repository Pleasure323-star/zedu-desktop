import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class AppRouter {
  const AppRouter._();

  static const home = '/home';
  static const login = '/login';
  static const magicLinkRequest = '/magic-link';
  static const magicLinkSent = '/magic-link/sent';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const changePassword = '/change-password';
  static const profile = '/profile';
  static const createOrganization = '/create-organization';
  static const buyCredits = '/credits/buy';

  /// The root Navigator. Widgets mounted from [App]'s `builder` sit above the
  /// Navigator, so they reach the Overlay and the router through this key
  /// instead of through their own context.
  static final navigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    initialLocation: login,
    navigatorKey: navigatorKey,
    routes: [
      GoRoute(path: login, builder: (context, state) => const LoginView()),
      GoRoute(
        path: magicLinkRequest,
        builder: (context, state) => const MagicLinkRequestView(),
      ),
      GoRoute(
        path: magicLinkSent,
        redirect: (context, state) =>
            state.extra is String && (state.extra! as String).trim().isNotEmpty
            ? null
            : magicLinkRequest,
        builder: (context, state) {
          final email = state.extra is String ? state.extra! as String : '';
          return MagicLinkSentView(email: email);
        },
      ),

      GoRoute(path: home, builder: (context, state) => const HomeView()),
      GoRoute(path: signup, builder: (context, state) => const SignUpView()),
      GoRoute(
        path: forgotPassword,
        builder: (context, state) => const ForgotPasswordView(),
      ),
      GoRoute(
        path: resetPassword,
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return ResetPasswordView(email: email);
        },
      ),
      GoRoute(
        path: changePassword,
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return ChangePasswordView(email: email);
        },
      ),
      GoRoute(
        path: profile,
        builder: (context, state) => const UserProfileView(),
      ),
      GoRoute(
        path: createOrganization,
        builder: (context, state) => const CreateOrganizationView(),
      ),
      GoRoute(
        path: buyCredits,
        builder: (context, state) => const BuyCreditsView(),
      ),
    ],
  );
}
