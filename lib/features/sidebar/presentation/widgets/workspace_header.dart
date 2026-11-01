import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class WorkspaceSwitcherHeader extends ConsumerStatefulWidget {
  const WorkspaceSwitcherHeader({super.key});

  @override
  ConsumerState<WorkspaceSwitcherHeader> createState() =>
      _WorkspaceSwitcherHeaderState();
}

class _WorkspaceSwitcherHeaderState
    extends ConsumerState<WorkspaceSwitcherHeader> {
  static const _menuWidth = 320.0;
  static const _screenMargin = 8.0;
  static const _gapBelowHeader = 10.0;
  static const _openDuration = Duration(milliseconds: 240);

  final _headerKey = GlobalKey();
  final _nameKey = GlobalKey();
  final _arrowKey = GlobalKey();
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final workspaceState = ref.watch(workspaceProvider);
    final selectedWorkspace = workspaceState.selectedWorkspace;

    if (selectedWorkspace == null) {
      final errorMessage = workspaceState.errorMessage;
      if (errorMessage == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                errorMessage,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onPrimary.withValues(alpha: 0.8),
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(workspaceProvider.notifier).fetchWorkspaces(),
              child: Text('Retry', style: TextStyle(color: colors.onPrimary)),
            ),
          ],
        ),
      );
    }

    return Container(
      key: _headerKey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _showWorkspaceSwitcher,
              child: Row(
                children: [
                  Flexible(
                    child: Tooltip(
                      message: selectedWorkspace.name,
                      child: Text(
                        selectedWorkspace.name,
                        key: _nameKey,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.onPrimary,
                          letterSpacing: 0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    key: _arrowKey,
                    turns: _isOpen ? 0.5 : 0,
                    duration: _openDuration,
                    curve: _WorkspaceMenuCurves.open,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: colors.onPrimary.withValues(alpha: 0.7),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              // Add action
            },
            icon: Icon(
              Icons.add,
              color: colors.onPrimary.withValues(alpha: 0.7),
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _showWorkspaceSwitcher() async {
    final header = _rectOf(_headerKey);
    final name = _rectOf(_nameKey);
    final arrow = _rectOf(_arrowKey);
    if (header == null || name == null || arrow == null) return;

    final colors = context.colors;
    final maxLeft =
        MediaQuery.sizeOf(context).width - _menuWidth - _screenMargin;
    final left = maxLeft < _screenMargin
        ? _screenMargin
        : (name.left - 8).clamp(_screenMargin, maxLeft).toDouble();

    setState(() => _isOpen = true);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'WorkspaceSwitcher',
      barrierColor: colors.textPrimary.withValues(alpha: 0.26),
      transitionDuration: _openDuration,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _AnchoredWorkspaceMenu(
          animation: animation,
          left: left,
          top: header.bottom + _gapBelowHeader,
          arrowX: arrow.center.dx - left,
          menuWidth: _menuWidth,
        );
      },
      // The menu animates itself from the arrow, so the route adds nothing.
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
    if (mounted) setState(() => _isOpen = false);
  }
}

class _WorkspaceMenuCurves {
  const _WorkspaceMenuCurves._();

  static const open = Cubic(0.16, 1, 0.3, 1);

  // The route reverses over the same 240 ms, so closing only uses the last
  // 60% of it (about 140 ms) and starts slowly, like an ease-in.
  static const close = Interval(0.4, 1, curve: Curves.easeOut);
}

class _AnchoredWorkspaceMenu extends StatelessWidget {
  final Animation<double> animation;
  final double left;
  final double top;
  final double arrowX;
  final double menuWidth;

  const _AnchoredWorkspaceMenu({
    required this.animation,
    required this.left,
    required this.top,
    required this.arrowX,
    required this.menuWidth,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxHeight = MediaQuery.sizeOf(context).height - top - 16;

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxHeight < 0 ? 0 : maxHeight,
            ),
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final t = animation.status == AnimationStatus.reverse
                    ? _WorkspaceMenuCurves.close.transform(animation.value)
                    : _WorkspaceMenuCurves.open.transform(animation.value);
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, -10 * (1 - t)),
                    child: Transform.scale(
                      scale: 0.94 + 0.06 * t,
                      alignment: Alignment(arrowX / menuWidth * 2 - 1, -1),
                      child: child,
                    ),
                  ),
                );
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // In a short window the cap can be smaller than the menu,
                  // so the whole menu scrolls instead of overflowing.
                  const SingleChildScrollView(child: WorkspaceSwitcherList()),
                  Positioned(
                    top: -6,
                    left: arrowX - 6,
                    child: Transform.rotate(
                      angle: 0.7853981633974483,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
