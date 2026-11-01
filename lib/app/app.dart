import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Zedu',
      theme: AppTheme.light,
      routerConfig: AppRouter.router,
      builder: (context, child) => CreditsPaymentDeepLinkListener(
        child: AuthDeepLinkListener(
          child: QuickSwitcherShortcut(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
