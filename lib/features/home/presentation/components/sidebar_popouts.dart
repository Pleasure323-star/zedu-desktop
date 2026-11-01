import 'dart:async';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

typedef _PopoutRowData = (String, String, String?, String?, VoidCallback);
TextStyle _w600(Color color, double size) =>
    TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w600);
TextStyle _mutedStyle(AppPalette colors) =>
    TextStyle(color: colors.sidebar, fontSize: 12);
TextStyle _stateStyle(AppPalette colors) =>
    TextStyle(color: colors.textHint, fontSize: 14);
const _transparent = Colors.transparent;
const _cardWidth = 358.0;
const _avatarSize = 36.0;

abstract interface class SidebarPopoutController {
  void onRailHover(HomeSidebarType type, bool hovered);
}

class SidebarPopoutHost extends ConsumerStatefulWidget {
  const SidebarPopoutHost({
    super.key,
    required this.child,
    required this.dmsTargetKey,
    required this.peopleTargetKey,
    required this.onTypeSelected,
  });
  final Widget child;
  final GlobalKey dmsTargetKey;
  final GlobalKey peopleTargetKey;
  final ValueChanged<HomeSidebarType> onTypeSelected;
  static SidebarPopoutController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SidebarPopoutScope>()!.host;
  @override
  ConsumerState<SidebarPopoutHost> createState() => _SidebarPopoutHostState();
}

class _SidebarPopoutHostState extends ConsumerState<SidebarPopoutHost>
    implements SidebarPopoutController {
  final _railKey = GlobalKey();
  Timer? _closeTimer;
  OverlayEntry? _entry;
  HomeSidebarType? _openType;
  Offset? _position;
  bool _openingChat = false;
  @override
  void dispose() {
    _closeTimer?.cancel();
    _entry?.remove();
    super.dispose();
  }

  @override
  void onRailHover(HomeSidebarType type, bool hovered) {
    if (hovered) _open(type);
    if (!hovered && _openType == type) _close(delayed: true);
  }

  void _open(HomeSidebarType type) {
    _close(cancelOnly: true);
    if (_openType == type) return;
    final isDms = type == HomeSidebarType.dms;
    if (isDms && ref.read(dmListProvider).hasError) {
      ref.read(dmListProvider.notifier).refresh();
    } else if (type == HomeSidebarType.people) {
      // An unrelated profile error must not reload everything on each hover
      // once the people are loaded.
      final profile = ref.read(userProfileNotifierProvider);
      if (profile.teamMembers.isEmpty && profile.error != null) {
        ref.read(userProfileNotifierProvider.notifier).load();
      }
    }
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject();
    final railBox = _railKey.currentContext?.findRenderObject();
    final targetKey = isDms ? widget.dmsTargetKey : widget.peopleTargetKey;
    final targetBox = targetKey.currentContext?.findRenderObject();
    if (overlayBox is! RenderBox ||
        railBox is! RenderBox ||
        targetBox is! RenderBox) {
      return;
    }
    final size = MediaQuery.sizeOf(context);
    final railRight = railBox.localToGlobal(Offset(railBox.size.width, 0));
    final iconTop = targetBox.localToGlobal(Offset.zero);
    final iconLocal = overlayBox.globalToLocal(iconTop);
    final cardLeft = overlayBox.globalToLocal(railRight).dx;
    final cardTop = iconLocal.dy.clamp(8.0, size.height - 8).toDouble();
    _position = Offset(cardLeft, cardTop);
    _openType = type;
    setState(() {});
    if (_entry == null) {
      _entry = OverlayEntry(builder: _buildOverlay);
      overlay.insert(_entry!);
    } else {
      _entry!.markNeedsBuild();
    }
  }

  void _close({bool delayed = false, bool cancelOnly = false}) {
    _closeTimer?.cancel();
    if (delayed) {
      _closeTimer = Timer(const Duration(milliseconds: 125), () => _close());
      return;
    }
    _closeTimer = null;
    if (cancelOnly) return;
    _openType = _position = null;
    if (mounted) setState(() {});
    _entry?.remove();
    _entry = null;
  }

  Widget _buildOverlay(BuildContext context) {
    final type = _openType, position = _position;
    if (type == null || position == null) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (size.width - position.dx - 8).clamp(0.0, _cardWidth),
          maxHeight: (size.height - position.dy - 8).clamp(0.0, size.height),
        ),
        child: SidebarPopoutCard(
          type,
          () => _close(cancelOnly: true),
          () => _close(delayed: true),
          _selectDm,
          _openPersonChat,
        ),
      ),
    );
  }

  void _selectDm(DmConversation conversation) {
    ref.read(selectedDmProvider.notifier).select(conversation);
    widget.onTypeSelected(HomeSidebarType.dms);
    _close();
  }

  Future<void> _openPersonChat(TeamMember person) async {
    if (_openingChat) return;
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId.isEmpty) return _showChatError();
    _openingChat = true;
    try {
      final opened = await ref
          .read(dmRepositoryProvider)
          .openConversation(orgId: orgId, participantId: person.id);
      if (!mounted) return;
      final conversation = DmConversation(
        channelId: opened.channelId,
        username: person.name ?? person.email,
        participantId: opened.participantId,
        participantEmail: person.email,
        avatarUrl: person.avatarUrl,
        previewMessage: '',
        unreadCount: 0,
      );
      _selectDm(conversation);
    } catch (error) {
      AppLogger.e('Failed to open direct message', error: error);
      if (mounted) _showChatError();
    } finally {
      _openingChat = false;
    }
  }

  void _showChatError() => AppToastService.show(
    context,
    type: AppToastType.error,
    message: "Couldn't open chat. Please try again.",
  );
  @override
  Widget build(BuildContext context) => _SidebarPopoutScope(
    this,
    child: KeyedSubtree(key: _railKey, child: widget.child),
  );
}

class _SidebarPopoutScope extends InheritedWidget {
  const _SidebarPopoutScope(this.host, {required super.child});
  final SidebarPopoutController host;
  @override
  bool updateShouldNotify(_SidebarPopoutScope old) => host != old.host;
}

class SidebarPopoutCard extends ConsumerWidget {
  const SidebarPopoutCard(
    this.type,
    this.onPointerEnter,
    this.onPointerExit,
    this.onConversationTap,
    this.onPersonTap, {
    super.key,
  });
  final HomeSidebarType type;
  final VoidCallback onPointerEnter;
  final VoidCallback onPointerExit;
  final ValueChanged<DmConversation> onConversationTap;
  final ValueChanged<TeamMember> onPersonTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDms = type == HomeSidebarType.dms;
    final dmState = isDms ? ref.watch(dmListProvider) : null;
    final profileState = isDms ? null : ref.watch(userProfileNotifierProvider);
    final Iterable<Object> items = isDms
        ? dmState?.asData?.value ?? const <DmConversation>[]
        : profileState?.teamMembers ?? const <TeamMember>[];
    final rows = items.take(4).map((item) {
      if (item is DmConversation) {
        return (
          item.displayName,
          item.previewMessage
              .replaceAll(RegExp(r'<[^>]*>'), '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim(),
          item.effectiveAvatarUrl,
          null,
          () => onConversationTap(item),
        );
      }
      final person = item as TeamMember;
      return (
        person.name?.isNotEmpty == true ? person.name! : 'Organisation member',
        person.role.isNotEmpty ? person.role : 'Organisation member',
        person.avatarUrl,
        // No status label: the API has no presence, and every member would
        // read "Active", which looks like being online.
        null,
        () => onPersonTap(person),
      );
    }).toList();
    final isLoading = isDms ? dmState!.isLoading : profileState!.isLoading;
    final colors = context.colors;
    // Loaded people are listed even if an unrelated profile request failed.
    final stateText = isLoading
        ? 'Loading...'
        : isDms && dmState!.hasError
        ? "Couldn't load conversations."
        : isDms
        ? 'No recent conversations'
        : profileState!.error ?? 'No people to show';
    return MouseRegion(
      onEnter: (_) => onPointerEnter(),
      onExit: (_) => onPointerExit(),
      child: Material(
        color: _transparent,
        child: Container(
          width: _cardWidth,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                offset: const Offset(0, 12),
                blurRadius: 32,
              ),
            ],
          ),
          // Rows are ListTiles; they need a Material below the decorated box.
          child: Material(
            type: MaterialType.transparency,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isDms ? 'Direct messages' : 'People',
                          style: _w600(colors.textPrimary, 15),
                        ),
                      ),
                      if (isDms) Text('Recent', style: _mutedStyle(colors)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isLoading || rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(stateText, style: _stateStyle(colors)),
                    )
                  else
                    Column(
                      spacing: 12,
                      children: [for (final row in rows) _row(context, row)],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, _PopoutRowData data) {
    final colors = context.colors;
    final status = data.$4;
    final fallback = Container(
      width: _avatarSize,
      height: _avatarSize,
      color: context.colors.primary,
      alignment: Alignment.center,
      child: Text(data.$1[0].toUpperCase(), style: _w600(colors.onPrimary, 14)),
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      minTileHeight: 36,
      minVerticalPadding: 0,
      minLeadingWidth: 36,
      horizontalTitleGap: 12,
      hoverColor: _transparent,
      splashColor: _transparent,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: data.$3?.isNotEmpty == true
            ? Image.network(
                data.$3!,
                width: _avatarSize,
                height: _avatarSize,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              )
            : fallback,
      ),
      title: Text(
        data.$1,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _w600(colors.textPrimary, 13),
      ),
      subtitle: Text(
        data.$2.isEmpty ? 'No recent message' : data.$2,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _mutedStyle(colors),
      ),
      trailing: status == null
          ? null
          : Text(
              status,
              maxLines: 1,
              softWrap: false,
              style: _mutedStyle(colors),
            ),
      onTap: data.$5,
    );
  }
}
