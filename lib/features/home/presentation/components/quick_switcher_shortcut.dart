import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Opens the [QuickSwitcherDialog] on Cmd+K (macOS) or Ctrl+K (Windows,
/// Linux) from any screen once the user is signed in.
class QuickSwitcherShortcut extends ConsumerStatefulWidget {
  final Widget child;

  /// The router to open the switcher over and to navigate with. Defaults to
  /// the app's router; tests pass their own.
  final GoRouter? router;

  const QuickSwitcherShortcut({super.key, required this.child, this.router});

  @override
  ConsumerState<QuickSwitcherShortcut> createState() =>
      _QuickSwitcherShortcutState();
}

class _QuickSwitcherShortcutState extends ConsumerState<QuickSwitcherShortcut> {
  bool _open = false;

  GoRouter get _router => widget.router ?? AppRouter.router;

  Future<void> _showSwitcher() async {
    final signedIn =
        ref.read(authNotifierProvider).status == AuthStatus.authenticated;
    final navigatorContext = _router.routerDelegate.navigatorKey.currentContext;
    if (_open || !signedIn || navigatorContext == null) return;

    _open = true;
    try {
      // Wait for the lists to load, so Cmd/Ctrl+K right after launch still
      // finds every channel and DM. A list that fails to load is left out,
      // and the user is told, so a short list isn't mistaken for all of them.
      var loadFailed = false;
      final channelList = await ref.read(channelProvider.future).catchError((
        _,
      ) {
        loadFailed = true;
        return const <Channel>[];
      });
      final dmList = await ref.read(dmListProvider.future).catchError((_) {
        loadFailed = true;
        return const <DmConversation>[];
      });
      final channels = channelList
          .where((c) => !c.archived)
          .map((c) => QuickSwitcherEntry.channel(c.name));
      final dms = dmList.map(QuickSwitcherEntry.dm);
      final rootContext = _router.routerDelegate.navigatorKey.currentContext;
      if (!mounted || rootContext == null || !rootContext.mounted) return;

      await showDialog<void>(
        context: rootContext,
        builder: (dialogContext) {
          // The dialog sits inside the navigator's overlay, so the toast is
          // shown from its context once it is on screen.
          if (loadFailed) {
            loadFailed = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!dialogContext.mounted) return;
              AppToastService.show(
                dialogContext,
                type: AppToastType.error,
                message: "Couldn't load all your channels and DMs.",
              );
            });
          }
          return QuickSwitcherDialog(
            entries: [...channels, ...dms],
            onSelected: (entry) {
              Navigator.of(dialogContext).pop();
              _openEntry(entry);
            },
          );
        },
      );
    } finally {
      _open = false;
    }
  }

  void _openEntry(QuickSwitcherEntry entry) {
    final conversation = entry.conversation;
    if (conversation == null) {
      ref.read(homeSidebarProvider.notifier).setType(HomeSidebarType.home);
      ref.read(activeChatProvider.notifier).selectChannel(entry.label);
    } else {
      ref.read(homeSidebarProvider.notifier).setType(HomeSidebarType.dms);
      ref.read(selectedDmProvider.notifier).select(conversation);
    }

    final location = _router.routerDelegate.currentConfiguration.uri;
    if (location.path != AppRouter.home) {
      _router.go(AppRouter.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _showSwitcher,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _showSwitcher,
      },
      child: widget.child,
    );
  }
}
