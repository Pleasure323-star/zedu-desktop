import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class AppSidebarRail extends ConsumerStatefulWidget {
  const AppSidebarRail({
    super.key,
    required this.activeType,
    this.onTypeSelected,
    this.settingsSelected = false,
  });

  static const double width = 50;

  final HomeSidebarType? activeType;
  final ValueChanged<HomeSidebarType>? onTypeSelected;
  final bool settingsSelected;

  @override
  ConsumerState<AppSidebarRail> createState() => _AppSidebarRailState();
}

class _AppSidebarRailState extends ConsumerState<AppSidebarRail> {
  // Held in state so a rebuild keeps the icons the pop-outs anchor to mounted.
  final _dmsTargetKey = GlobalKey();
  final _peopleTargetKey = GlobalKey();

  HomeSidebarType? get activeType => widget.activeType;
  ValueChanged<HomeSidebarType>? get onTypeSelected => widget.onTypeSelected;
  bool get settingsSelected => widget.settingsSelected;

  @override
  Widget build(BuildContext context) {
    final dmsTargetKey = _dmsTargetKey;
    final peopleTargetKey = _peopleTargetKey;

    void select(HomeSidebarType type) {
      if (onTypeSelected != null) {
        onTypeSelected!(type);
        return;
      }
      ref.read(homeSidebarProvider.notifier).setType(type);
    }

    return SidebarPopoutHost(
      dmsTargetKey: dmsTargetKey,
      peopleTargetKey: peopleTargetKey,
      onTypeSelected: select,
      child: _buildRail(context, ref, dmsTargetKey, peopleTargetKey, select),
    );
  }

  Widget _buildRail(
    BuildContext context,
    WidgetRef ref,
    GlobalKey dmsTargetKey,
    GlobalKey peopleTargetKey,
    ValueChanged<HomeSidebarType> select,
  ) {
    final colors = context.colors;
    return Container(
      width: AppSidebarRail.width,
      decoration: BoxDecoration(
        color: colors.sidebar,
        border: Border(
          right: BorderSide(color: colors.onPrimary.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _RailNavItem(
            icon: Icons.home_filled,
            label: 'Home',
            isActive: activeType == HomeSidebarType.home,
            onTap: () => select(HomeSidebarType.home),
          ),
          _RailNavItem(
            icon: Icons.chat_bubble_outline,
            label: 'DMs',
            popoutType: HomeSidebarType.dms,
            positionKey: dmsTargetKey,
            isActive: activeType == HomeSidebarType.dms,
            onTap: () => select(HomeSidebarType.dms),
          ),
          _RailNavItem(
            icon: Icons.people_outline,
            label: 'People',
            popoutType: HomeSidebarType.people,
            positionKey: peopleTargetKey,
            isActive: activeType == HomeSidebarType.people,
            onTap: () => select(HomeSidebarType.people),
          ),
          _RailNavItem(
            icon: Icons.folder_open_outlined,
            label: 'Files',
            isActive: activeType == HomeSidebarType.files,
            onTap: () => select(HomeSidebarType.files),
          ),
          _BuzzRailItem(
            isActive: activeType == HomeSidebarType.buzz,
            onTap: () => select(HomeSidebarType.buzz),
          ),
          const Spacer(),
          _RailBottomIcon(
            icon: Icons.notifications_none_outlined,
            // No unread-count source yet; show the dot once there is one.
            hasNotification: false,
            tooltip: 'Notifications',
            onTap: () {
              showDialog<void>(
                context: context,
                barrierColor: Colors.black.withValues(alpha: 0.3),
                builder: (context) => const NotificationsDialog(),
              );
            },
          ),
          _RailBottomIcon(
            icon: Icons.settings_outlined,
            selected: settingsSelected,
            onTap: () {
              context.go(AppRouter.profile);
            },
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 16, top: 8),
            child: UserMenuButton(),
          ),
        ],
      ),
    );
  }
}

class _BuzzRailItem extends ConsumerWidget {
  const _BuzzRailItem({required this.isActive, required this.onTap});

  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(activeCallProvider).state;
    final tooltip = call.lastCallAt == null
        ? 'Buzz'
        : 'Last Buzz: ${_formatDateTime(call.lastCallAt!)}';

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: _RailNavItem(
        icon: Icons.phone_outlined,
        label: 'Buzz',
        isActive: isActive,
        onTap: onTap,
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour > 12
        ? local.hour - 12
        : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day}/${local.month}/${local.year} $hour:$minute $period';
  }
}

class _RailNavItem extends StatefulWidget {
  const _RailNavItem({
    required this.icon,
    required this.label,
    this.popoutType,
    this.isActive = false,
    this.positionKey,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final HomeSidebarType? popoutType;
  final bool isActive;
  final GlobalKey? positionKey;
  final VoidCallback? onTap;

  @override
  State<_RailNavItem> createState() => _RailNavItemState();
}

class _RailNavItemState extends State<_RailNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final popouts = widget.popoutType == null
        ? null
        : SidebarPopoutHost.of(context);

    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: widget.onTap,
        onHover: popouts == null
            ? null
            : (hovered) => popouts.onRailHover(widget.popoutType!, hovered),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            children: [
              MouseRegion(
                onEnter: (_) => setState(() => _hovered = true),
                onExit: (_) => setState(() => _hovered = false),
                child: Container(
                  key: widget.positionKey,
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (widget.isActive || _hovered)
                        ? colors.primary.withValues(alpha: 0.95)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(widget.icon, color: colors.onPrimary, size: 20),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: context.textTheme.labelSmall?.copyWith(
                  color: colors.onPrimary.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailBottomIcon extends StatelessWidget {
  const _RailBottomIcon({
    required this.icon,
    this.hasNotification = false,
    this.selected = false,
    this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final bool hasNotification;
  final bool selected;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: selected
                    ? colors.primary.withValues(alpha: 0.95)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: colors.onPrimary, size: 20),
            ),
            if (hasNotification)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(
      message: tooltip!,
      waitDuration: const Duration(milliseconds: 350),
      child: button,
    );
  }
}
