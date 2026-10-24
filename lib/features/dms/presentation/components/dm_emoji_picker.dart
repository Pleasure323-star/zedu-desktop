import 'package:zedu/core/core.dart';

class DmEmojiPicker extends StatelessWidget {
  final ValueChanged<String> onEmojiSelected;
  final VoidCallback onClose;

  const DmEmojiPicker({
    super.key,
    required this.onEmojiSelected,
    required this.onClose,
  });

  static const _emojis = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😅',
    '😂',
    '🤣',
    '😊',
    '😇',
    '🙂',
    '😉',
    '😍',
    '🥰',
    '😘',
    '😗',
    '😋',
    '😛',
    '😜',
    '🤪',
    '😝',
    '🤑',
    '🤗',
    '🤭',
    '🤫',
    '🤔',
    '😐',
    '😑',
    '😶',
    '😏',
    '😒',
    '🙄',
    '😬',
    '😮',
    '😯',
    '😲',
    '😳',
    '🥺',
    '😢',
    '😭',
    '😤',
    '👍',
    '👎',
    '👌',
    '✌️',
    '🤞',
    '🤟',
    '🤙',
    '👏',
    '🙌',
    '🤝',
    '🙏',
    '💪',
    '🫡',
    '🫶',
    '👀',
    '🧠',
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '🤍',
    '🔥',
    '✨',
    '🎉',
    '🎊',
    '💯',
    '💥',
    '💫',
    '🚀',
    '💻',
    '📱',
    '💼',
    '📎',
    '📌',
    '🗂️',
    '✅',
    '❌',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: 340,
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
            child: Row(
              children: [
                Text(
                  'Emoji',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onClose,
                  icon: Icon(Icons.close, size: 16, color: colors.textHint),
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.divider),
          Flexible(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              shrinkWrap: true,
              itemCount: _emojis.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () => onEmojiSelected(_emojis[index]),
                  borderRadius: BorderRadius.circular(6),
                  hoverColor: colors.onPrimary.withValues(alpha: 0.08),
                  child: Center(
                    child: Text(
                      _emojis[index],
                      style: const TextStyle(fontSize: 20),
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
