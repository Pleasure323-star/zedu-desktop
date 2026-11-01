import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class DmSidebarList extends ConsumerWidget {
  const DmSidebarList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Container(
      width: 320,
      color: colors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceSwitcherHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: colors.onPrimary.withValues(alpha: 0.68),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        Icon(
                          Icons.search,
                          color: colors.onPrimary.withValues(alpha: 0.9),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Find a Conversation',
                          style: TextStyle(
                            color: colors.onPrimary.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ref
                .watch(dmListProvider)
                .when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  error: (err, stack) => Center(
                    child: Text(
                      'Failed to load DMs',
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                  data: (conversations) {
                    final actions = ref.watch(dmConversationActionsProvider);
                    final visibleConversations =
                        conversations
                            .where(
                              (conversation) => !actions.deletedIds.contains(
                                conversation.channelId,
                              ),
                            )
                            .toList()
                          ..sort((a, b) {
                            final aPinned = actions.pinnedIds.contains(
                              a.channelId,
                            );
                            final bPinned = actions.pinnedIds.contains(
                              b.channelId,
                            );
                            if (aPinned != bPinned) return aPinned ? -1 : 1;
                            return b.lastActivityAt.compareTo(a.lastActivityAt);
                          });
                    if (visibleConversations.isEmpty) {
                      return Center(
                        child: Text(
                          'No recent chats',
                          style: TextStyle(
                            color: colors.onPrimary.withValues(alpha: 0.5),
                          ),
                        ),
                      );
                    }
                    return NotificationListener<ScrollNotification>(
                      onNotification: (scrollInfo) {
                        if (scrollInfo is ScrollEndNotification &&
                            scrollInfo.metrics.pixels >=
                                scrollInfo.metrics.maxScrollExtent * 0.85) {
                          final notifier = ref.read(dmListProvider.notifier);
                          if (notifier.hasMore) {
                            notifier.loadMore();
                          }
                        }
                        return false;
                      },
                      // Transparent Material so each row's hover and
                      // selected ink paints above the sidebar colour.
                      child: Material(
                        type: MaterialType.transparency,
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: visibleConversations.length,
                          itemBuilder: (context, index) {
                            return DmListTile(
                              conversation: visibleConversations[index],
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
