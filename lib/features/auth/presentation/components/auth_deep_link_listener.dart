import 'dart:async';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class AuthDeepLinkListener extends ConsumerStatefulWidget {
  const AuthDeepLinkListener({super.key, required this.child, this.appLinks});

  final Widget child;
  final AppLinks? appLinks;

  @override
  ConsumerState<AuthDeepLinkListener> createState() =>
      _AuthDeepLinkListenerState();
}

class _AuthDeepLinkListenerState extends ConsumerState<AuthDeepLinkListener> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  String? _lastProcessedToken;

  static const _tag = 'AuthDeepLinkListener';

  @override
  void initState() {
    super.initState();
    _appLinks = widget.appLinks ?? AppLinks();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleUri(initialUri);
      }
    } catch (error) {
      AppLogger.w('Failed to read initial deep link', tag: _tag);
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        unawaited(_handleUri(uri));
      },
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.w('Deep link stream error: $error', tag: _tag);
      },
    );
  }

  Future<void> _handleUri(Uri uri) async {
    final token = MagicLinkDeepLinkParser.extractToken(uri);
    if (token == null || token == _lastProcessedToken) return;
    _lastProcessedToken = token;

    AppLogger.i('Processing magic link deep link', tag: _tag);
    await ref.read(authNotifierProvider.notifier).verifyMagicLink(token: token);

    if (!mounted) return;

    // This listener is mounted from `App`'s builder, above the Navigator, so
    // its own context has neither an Overlay nor the router in it.
    final navigator = AppRouter.navigatorKey.currentState;
    if (navigator == null) return;

    final authState = ref.read(authNotifierProvider);
    if (authState.status == AuthStatus.authenticated) {
      AppToastService.showAtRoot(
        navigator,
        type: AppToastType.success,
        message: 'Logged in successfully!',
      );
      navigator.context.go(AppRouter.home);
      return;
    }

    if (authState.error != null) {
      AppToastService.showAtRoot(
        navigator,
        type: AppToastType.error,
        message: authState.error!,
      );
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
