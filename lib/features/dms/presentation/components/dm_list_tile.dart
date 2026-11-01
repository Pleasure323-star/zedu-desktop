import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class DmListTile extends ConsumerWidget {
  final DmConversation conversation;

  const DmListTile({super.key, required this.conversation});

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(dt.year, dt.month, dt.day);

    if (messageDay == today) {
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (messageDay == yesterday) {
      return 'Yesterday';
    }

    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final selected = ref.watch(selectedDmProvider);
    final isSelected = selected?.channelId == conversation.channelId;
    final hasUnread = conversation.unreadCount > 0;
    final borderRadius = BorderRadius.circular(6);

    // Draft indicator: watch the store so the tile rebuilds when a draft is
    // created/edited/cleared. Kick off a one-shot load for entries not yet
    // cached (load() notifies listeners when done, which rebuilds this tile).
    final draftStore = ref.watch(dmDraftStoreProvider);
    final draftEntry = draftStore.peek(conversation.channelId);
    if (draftEntry == null && !draftStore.hasLoaded(conversation.channelId)) {
      scheduleMicrotask(() {
        if (context.mounted) {
          ref.read(dmDraftStoreProvider).load(conversation.channelId);
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Ink(
        decoration: BoxDecoration(
          color: isSelected
              ? colors.onPrimary.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: borderRadius,
        ),
        child: InkWell(
          borderRadius: borderRadius,
          hoverColor: colors.onPrimary.withValues(alpha: 0.06),
          mouseCursor: SystemMouseCursors.click,
          onTap: () {
            ref.read(selectedDmProvider.notifier).select(conversation);
          },
          child: Stack(
            children: [
              if (isSelected)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(6),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: _buildContent(colors, hasUnread, draftEntry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    AppPalette colors,
    bool hasUnread,
    DraftEntry? draftEntry,
  ) {
    final emphasis = hasUnread ? FontWeight.w700 : FontWeight.w400;

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: colors.primary,
          backgroundImage: conversation.effectiveAvatarUrl != null
              ? NetworkImage(conversation.effectiveAvatarUrl!)
              : null,
          child: conversation.effectiveAvatarUrl == null
              ? Text(
                  conversation.displayName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conversation.displayName,
                style: TextStyle(
                  color: colors.onPrimary,
                  fontSize: 13,
                  fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              if (draftEntry != null)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Draft',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        draftEntry.text.trim(),
                        style: TextStyle(
                          color: colors.onPrimary,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  conversation.previewMessage,
                  style: TextStyle(
                    color: hasUnread
                        ? colors.onPrimary
                        : colors.onPrimary.withValues(alpha: 0.72),
                    fontSize: 11,
                    fontWeight: emphasis,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (conversation.hasActivity)
              Text(
                _formatTime(conversation.lastActivityAt),
                style: TextStyle(
                  color: hasUnread
                      ? colors.onPrimary
                      : colors.onPrimary.withValues(alpha: 0.92),
                  fontSize: 11,
                  fontWeight: emphasis,
                ),
              ),
            if (hasUnread) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${conversation.unreadCount}',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
