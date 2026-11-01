import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class DmChatArea extends ConsumerStatefulWidget {
  final DmConversation conversation;

  const DmChatArea({super.key, required this.conversation});

  @override
  ConsumerState<DmChatArea> createState() => _DmChatAreaState();
}

class _DmChatAreaState extends ConsumerState<DmChatArea> {
  bool _isDragging = false;
  final _composerKey = GlobalKey<DmMessageComposerState>();

  String get _recipientHandle {
    final parts = widget.conversation.displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '@user';
    if (parts.length == 1) return '@${parts.first}';
    return '@${parts.first}_${parts.last}';
  }

  Future<void> _handleMenuAction(String action) async {
    final conversation = widget.conversation;
    switch (action) {
      case 'view_profile':
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(conversation.displayName),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (conversation.participantEmail?.isNotEmpty == true)
                  Text(conversation.participantEmail!),
                Text('User ID: ${conversation.participantId}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      case 'mute_notifications':
        final settings = ref.read(notificationSettingsProvider);
        final notifier = ref.read(notificationSettingsProvider.notifier);
        if (settings.isMuted(conversation.participantId)) {
          notifier.unmuteParticipant(conversation.participantId);
        } else {
          notifier.muteParticipant(conversation.participantId);
        }
      case 'pin_conversation':
        ref
            .read(dmConversationActionsProvider.notifier)
            .togglePinned(conversation.channelId);
      case 'search_in_conversation':
        await _showConversationSearch();
      case 'view_files':
        await _showConversationFiles();
      case 'clear_history':
        final confirmed = await _confirmConversationAction(
          title: 'Clear history?',
          message:
              'Clear the loaded message history for ${conversation.displayName}?',
          confirmLabel: 'Clear history',
        );
        if (confirmed && mounted) {
          ref
              .read(chatHistoryProvider(conversation.channelId))
              .clearLocalHistory();
          _showActionNotice('Loaded history cleared locally.');
        }
      case 'delete_conversation':
        final confirmed = await _confirmConversationAction(
          title: 'Delete conversation?',
          message:
              'This removes the conversation from your DM list. ${conversation.displayName} can still see it.',
          confirmLabel: 'Delete conversation',
          destructive: true,
        );
        if (!confirmed || !mounted) return;
        final deleted = await ref
            .read(dmConversationActionsProvider.notifier)
            .delete(conversation.channelId);
        if (!deleted && mounted) {
          _showActionNotice("Couldn't delete the conversation. Try again.");
        }
    }
  }

  Future<bool> _confirmConversationAction({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: destructive
                    ? TextButton.styleFrom(
                        foregroundColor: context.colors.error,
                      )
                    : null,
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showConversationSearch() async {
    final history = ref.read(
      chatHistoryProvider(widget.conversation.channelId),
    );
    await showDialog<void>(
      context: context,
      builder: (context) => _ConversationSearchDialog(
        displayName: widget.conversation.displayName,
        messages: history.messages,
      ),
    );
  }

  Future<void> _showConversationFiles() async {
    final history = ref.read(
      chatHistoryProvider(widget.conversation.channelId),
    );
    final files = history.messages
        .expand((message) => (message['media'] as List<dynamic>?) ?? const [])
        .toList();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${widget.conversation.displayName} files'),
        content: SizedBox(
          width: 420,
          child: files.isEmpty
              ? const Text('No files in the loaded conversation history.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index] as Map;
                    return ListTile(
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(
                        file['file_name']?.toString() ?? 'Attachment',
                      ),
                      subtitle: Text(file['file_type']?.toString() ?? ''),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showActionNotice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isMuted = ref.watch(
      notificationSettingsProvider.select(
        (settings) => settings.isMuted(widget.conversation.participantId),
      ),
    );
    final isPinned = ref.watch(
      dmConversationActionsProvider.select(
        (actions) => actions.pinnedIds.contains(widget.conversation.channelId),
      ),
    );

    return DropTarget(
      onDragDone: (detail) {
        _composerKey.currentState?.addFiles(detail.files);
        setState(() => _isDragging = false);
      },
      onDragEntered: (detail) {
        setState(() => _isDragging = true);
      },
      onDragExited: (detail) {
        setState(() => _isDragging = false);
      },
      child: Container(
        color: colors.onPrimary,
        child: Stack(
          children: [
            Column(
              children: [
                _DmChatHeader(
                  conversation: widget.conversation,
                  isMuted: isMuted,
                  isPinned: isPinned,
                  onMenuAction: _handleMenuAction,
                ),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final historyState = ref.watch(
                        chatHistoryProvider(widget.conversation.channelId),
                      );
                      final messages = historyState.messages;

                      return NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification scrollInfo) {
                          if (!historyState.isLoading &&
                              historyState.hasMore &&
                              scrollInfo.metrics.pixels >=
                                  scrollInfo.metrics.maxScrollExtent * 0.8) {
                            ref
                                .read(
                                  chatHistoryProvider(
                                    widget.conversation.channelId,
                                  ),
                                )
                                .loadMore();
                          }
                          return false;
                        },
                        child: CustomScrollView(
                          reverse: true,
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final msg = messages[index];
                                  return _MessageBubble(
                                    message: msg,
                                    conversation: widget.conversation,
                                    channelId: widget.conversation.channelId,
                                    onEdit: (id, text) => _composerKey
                                        .currentState
                                        ?.enterEditMode(id, text),
                                  );
                                }, childCount: messages.length),
                              ),
                            ),
                            if (historyState.isLoading)
                              const SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              ),
                            if (!historyState.hasMore)
                              SliverToBoxAdapter(
                                child: DmProfileCard(
                                  conversation: widget.conversation,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                DmMessageComposer(
                  key: _composerKey,
                  recipientName: _recipientHandle,
                  channelId: widget.conversation.channelId,
                  participants: widget.conversation.participants,
                ),
              ],
            ),

            // FULL PAGE MODE INJECTION
            Consumer(
              builder: (context, ref, child) {
                final activeCall = ref.watch(activeCallProvider);
                if (activeCall.state.status == CallStatus.active &&
                    activeCall.state.isFullPage) {
                  return const Positioned.fill(child: BuzzMeetingView());
                }
                return const SizedBox.shrink();
              },
            ),

            // FLOATING / PIP INJECTION
            Consumer(
              builder: (context, ref, child) {
                final activeCall = ref.watch(activeCallProvider);
                if (activeCall.state.status == CallStatus.active &&
                    !activeCall.state.isFullPage) {
                  return const BuzzMeetingView();
                }
                return const SizedBox.shrink();
              },
            ),

            // INCOMING CALL MODAL
            const IncomingCallModal(),

            // RINGING STATE OVERLAY (Caller)
            Consumer(
              builder: (context, ref, child) {
                final activeCall = ref.watch(activeCallProvider);
                if (activeCall.state.status == CallStatus.calling) {
                  return Positioned(
                    top: 24,
                    right: 24,
                    child: Material(
                      color: Colors.transparent,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 320,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.divider),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Calling...',
                                    style: TextStyle(
                                      color: colors.textHint,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    activeCall.state.remoteUserName ??
                                        'Unknown',
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.call_end),
                              tooltip: 'Cancel call',
                              color: Colors.red,
                              onPressed: () {
                                ref
                                    .read(activeCallProvider.notifier)
                                    .cancelCall();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            if (_isDragging)
              Positioned.fill(
                child: Container(
                  color: colors.primary.withValues(alpha: 0.2),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Drop files to attach',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConversationSearchDialog extends StatefulWidget {
  final String displayName;
  final List<Map<String, dynamic>> messages;

  const _ConversationSearchDialog({
    required this.displayName,
    required this.messages,
  });

  @override
  State<_ConversationSearchDialog> createState() =>
      _ConversationSearchDialogState();
}

class _ConversationSearchDialogState extends State<_ConversationSearchDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.toLowerCase();
    final results = widget.messages.where(
      (message) =>
          (message['content']?.toString() ?? '').toLowerCase().contains(query),
    );
    return AlertDialog(
      title: Text('Search ${widget.displayName}'),
      content: SizedBox(
        width: 420,
        height: 360,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Search messages'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: query.isEmpty
                    ? const [Text('Enter a search term')]
                    : results
                          .map(
                            (message) => ListTile(
                              dense: true,
                              title: Text(message['content']?.toString() ?? ''),
                            ),
                          )
                          .toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DmChatHeader extends StatelessWidget {
  final DmConversation conversation;
  final bool isMuted;
  final bool isPinned;
  final ValueChanged<String> onMenuAction;

  const _DmChatHeader({
    required this.conversation,
    required this.isMuted,
    required this.isPinned,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final participantInitial = conversation.displayName.trim().isEmpty
        ? '?'
        : conversation.displayName.trim()[0].toUpperCase();

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.primary,
            backgroundImage: conversation.effectiveAvatarUrl != null
                ? NetworkImage(conversation.effectiveAvatarUrl!)
                : null,
            child: conversation.effectiveAvatarUrl == null
                ? Text(
                    participantInitial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Text(
            conversation.displayName,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
          const Spacer(),
          Consumer(
            builder: (context, ref, child) {
              return InkWell(
                onTap: () {
                  ref
                      .read(activeCallProvider.notifier)
                      .initiateCall(
                        remoteUserId: conversation.participantId,
                        remoteUserName: conversation.displayName,
                        channelId: conversation.channelId,
                        remoteAvatarUrl: conversation.effectiveAvatarUrl,
                      );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.divider),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.headphones_outlined,
                    size: 18,
                    color: colors.textPrimary,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            tooltip: 'More options',
            position: PopupMenuPosition.under,
            icon: Icon(Icons.more_vert, color: colors.textHint),
            onSelected: onMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'view_profile',
                child: Text(
                  'View profile',
                  style: TextStyle(color: colors.textPrimary),
                ),
              ),
              PopupMenuItem(
                value: 'mute_notifications',
                child: Text(
                  isMuted ? 'Unmute notifications' : 'Mute notifications',
                  style: TextStyle(color: colors.textPrimary),
                ),
              ),
              PopupMenuItem(
                value: 'pin_conversation',
                child: Text(
                  isPinned ? 'Unpin conversation' : 'Pin conversation',
                  style: TextStyle(color: colors.textPrimary),
                ),
              ),
              PopupMenuItem(
                value: 'search_in_conversation',
                child: Text(
                  'Search in conversation',
                  style: TextStyle(color: colors.textPrimary),
                ),
              ),
              PopupMenuItem(
                value: 'view_files',
                child: Text(
                  'View files',
                  style: TextStyle(color: colors.textPrimary),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'clear_history',
                child: Text(
                  'Clear history',
                  style: TextStyle(color: colors.textPrimary),
                ),
              ),
              PopupMenuItem(
                value: 'delete_conversation',
                child: Text(
                  'Delete conversation',
                  style: TextStyle(color: colors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  final Map<String, dynamic> message;
  final DmConversation conversation;
  final String channelId;
  final void Function(String messageId, String content) onEdit;

  const _MessageBubble({
    required this.message,
    required this.conversation,
    required this.channelId,
    required this.onEdit,
  });

  TextSpan _parseRichText(String text, TextStyle defaultStyle) {
    if (text.isEmpty) return TextSpan(style: defaultStyle, text: '');

    final boldRegex = RegExp(r'\*\*(.*?)\*\*', dotAll: true);
    final italicRegex = RegExp(r'(?<!\*)\*(.*?)\*(?!\*)', dotAll: true);
    final strikeRegex = RegExp(r'~~(.*?)~~', dotAll: true);
    final codeRegex = RegExp(r'`(.*?)`', dotAll: true);

    final allPatterns = [boldRegex, italicRegex, strikeRegex, codeRegex];
    final combined = RegExp(
      allPatterns.map((r) => r.pattern).join('|'),
      dotAll: true,
    );

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in combined.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: defaultStyle,
          ),
        );
      }

      final raw = match.group(0)!;
      if (boldRegex.hasMatch(raw)) {
        final inner =
            match.group(1) ?? boldRegex.firstMatch(raw)?.group(1) ?? raw;
        spans.add(
          TextSpan(
            text: inner,
            style: defaultStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else if (strikeRegex.hasMatch(raw)) {
        final inner = strikeRegex.firstMatch(raw)?.group(1) ?? raw;
        spans.add(
          TextSpan(
            text: inner,
            style: defaultStyle.copyWith(
              decoration: TextDecoration.lineThrough,
            ),
          ),
        );
      } else if (codeRegex.hasMatch(raw)) {
        final inner = codeRegex.firstMatch(raw)?.group(1) ?? raw;
        spans.add(
          TextSpan(
            text: inner,
            style: defaultStyle.copyWith(
              fontFamily: 'monospace',
              backgroundColor: const Color(0x1A6458F5),
              color: const Color(0xFF6458F5),
            ),
          ),
        );
      } else if (italicRegex.hasMatch(raw)) {
        final inner = italicRegex.firstMatch(raw)?.group(1) ?? raw;
        spans.add(
          TextSpan(
            text: inner,
            style: defaultStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else {
        spans.add(TextSpan(text: raw, style: defaultStyle));
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: defaultStyle));
    }

    return TextSpan(style: defaultStyle, children: spans);
  }

  /// Splits [text] around Markdown thematic breaks: a line that is exactly
  /// `---` at the start of the message or after a blank line. A `---` right
  /// under a line of text is a setext heading in Markdown, so it stays text.
  static List<String> _splitOnDividers(String text) {
    final parts = <String>[];
    final current = <String>[];
    String joined() => current.join('\n').replaceAll(RegExp(r'^\n+|\n+$'), '');

    for (final line in text.split('\n')) {
      final afterBlank = current.isEmpty || current.last.trim().isEmpty;
      if (line.trim() == '---' && afterBlank) {
        parts.add(joined());
        current.clear();
      } else {
        current.add(line);
      }
    }
    parts.add(joined());
    return parts;
  }

  Widget _buildMessageText(String content, TextStyle style) {
    final parts = _splitOnDividers(content);
    if (parts.length == 1) {
      return RichText(text: _parseRichText(content, style));
    }

    final divider = Divider(
      height: 16,
      thickness: 1,
      color: style.color?.withValues(alpha: 0.4),
    );
    // The rule spans the bubble's text width, with a floor so a message that
    // is only a divider still shows a visible line.
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < parts.length; i++) ...[
              if (i > 0) divider,
              if (parts[i].isNotEmpty)
                RichText(text: _parseRichText(parts[i], style)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String messageId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text(
          'This deletes the message for everyone and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(chatHistoryProvider(channelId)).deleteMessage(messageId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final history = ref.watch(chatHistoryProvider(channelId));
    final isMe = history.isMyMessage(message);
    final rawContent = message['content'] as String? ?? '';
    // A voice note or file sent without text carries an empty paragraph
    // (`<p></p>`). Show no text bubble for it instead of the literal tags.
    final content = rawContent.replaceAll(RegExp(r'<[^>]*>'), '').trim().isEmpty
        ? ''
        : rawContent;
    final createdAt =
        DateTime.tryParse(message['created_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now();
    final status = message['status'] as String?;
    final messageId = message['id'] as String? ?? '';

    final hour = createdAt.hour > 12
        ? createdAt.hour - 12
        : (createdAt.hour == 0 ? 12 : createdAt.hour);
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final period = createdAt.hour >= 12 ? 'PM' : 'AM';
    final timeString = '$hour:$minute $period';

    final senderName = isMe
        ? history.currentUserName
        : conversation.displayName;

    final senderAvatarUrl = isMe
        ? history.currentUserAvatarUrl
        : conversation.effectiveAvatarUrl;

    final senderInitial = senderName.isNotEmpty
        ? senderName[0].toUpperCase()
        : '?';

    final List<dynamic> media = (message['media'] as List<dynamic>?) ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 15,
              backgroundColor: colors.primary,
              backgroundImage:
                  senderAvatarUrl != null && senderAvatarUrl.isNotEmpty
                  ? NetworkImage(senderAvatarUrl)
                  : null,
              child: senderAvatarUrl == null || senderAvatarUrl.isEmpty
                  ? Text(
                      senderInitial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        senderName,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeString,
                        style: TextStyle(color: colors.textHint, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (content.isNotEmpty)
                  _OwnMessageMenu(
                    enabled: isMe && status == null,
                    onEdit: () => onEdit(messageId, rawContent),
                    onDelete: () => _confirmDelete(context, ref, messageId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? colors.primary
                            : colors.onPrimary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _buildMessageText(
                        content,
                        TextStyle(
                          color: isMe ? Colors.white : colors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                if (media.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: content.isNotEmpty ? 8 : 0),
                    child: content.isNotEmpty
                        ? _AttachmentBubbleList(media: media, isMe: isMe)
                        // No text to hang the menu on, so it goes on the
                        // attachments (Delete only: there is nothing to edit).
                        : _OwnMessageMenu(
                            enabled: isMe && status == null,
                            onEdit: null,
                            onDelete: () =>
                                _confirmDelete(context, ref, messageId),
                            child: _AttachmentBubbleList(
                              media: media,
                              isMe: isMe,
                            ),
                          ),
                  ),
                if (isMe && status != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: status == 'failed'
                        ? GestureDetector(
                            onTap: () {
                              ref
                                  .read(chatHistoryProvider(channelId))
                                  .retryMessage(messageId);
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 13,
                                  color: colors.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Failed – Tap to retry',
                                  style: TextStyle(
                                    color: colors.error,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Text(
                            status == 'sending' ? 'Sending...' : '',
                            style: TextStyle(
                              color: colors.textHint,
                              fontSize: 11,
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentBubbleList extends StatelessWidget {
  final List<dynamic> media;
  final bool isMe;

  const _AttachmentBubbleList({required this.media, required this.isMe});

  void _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _buildGenericFile(
    String fileName,
    String fileLink,
    bool isImage,
    BuildContext context,
  ) {
    final colors = context.colors;
    return GestureDetector(
      onTap: fileLink.isNotEmpty ? () => _launchUrl(fileLink) : null,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMe
              ? colors.primary.withValues(alpha: 0.15)
              : colors.onPrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isMe
                ? colors.primary.withValues(alpha: 0.3)
                : colors.divider,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isImage ? Icons.image_rounded : Icons.insert_drive_file_rounded,
              color: isMe ? colors.primary : colors.textPrimary,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              fileName,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
      children: media.map((item) {
        final String fileName = (item['file_name'] ?? 'Attachment').toString();
        final String fileLink = (item['file_link'] ?? '').toString();
        final isImage = [
          'png',
          'jpg',
          'jpeg',
          'gif',
          'webp',
        ].contains((item['file_type'] ?? '').toString().toLowerCase());

        if (isImage && fileLink.isNotEmpty) {
          final isNetwork = fileLink.startsWith('http');

          return GestureDetector(
            onTap: () => _launchUrl(fileLink),
            child: Container(
              width: 250,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.divider),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isNetwork
                    ? Image.network(
                        fileLink,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildGenericFile(
                              fileName,
                              fileLink,
                              isImage,
                              context,
                            ),
                      )
                    : Image.asset(
                        fileLink,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildGenericFile(
                              fileName,
                              fileLink,
                              isImage,
                              context,
                            ),
                      ),
              ),
            ),
          );
        }

        return _buildGenericFile(fileName, fileLink, isImage, context);
      }).toList(),
    );
  }
}

/// Shows a "more" button on hover, and a right-click or long-press menu, for
/// your own messages, with Edit and Delete. The long press is for touch input,
/// where there is no hover or right click.
class _OwnMessageMenu extends StatefulWidget {
  const _OwnMessageMenu({
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
    required this.child,
  });

  final bool enabled;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  final Widget child;

  @override
  State<_OwnMessageMenu> createState() => _OwnMessageMenuState();
}

class _OwnMessageMenuState extends State<_OwnMessageMenu> {
  final _menuKey = GlobalKey<PopupMenuButtonState<String>>();
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onSecondaryTap: () => _menuKey.currentState?.showButtonMenu(),
        onLongPress: () => _menuKey.currentState?.showButtonMenu(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: _hovered ? 1 : 0,
              child: PopupMenuButton<String>(
                key: _menuKey,
                tooltip: 'Message actions',
                icon: const Icon(Icons.more_horiz, size: 18),
                onSelected: (value) =>
                    value == 'edit' ? widget.onEdit?.call() : widget.onDelete(),
                itemBuilder: (_) => [
                  if (widget.onEdit != null)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit message'),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete message'),
                  ),
                ],
              ),
            ),
            Flexible(child: widget.child),
          ],
        ),
      ),
    );
  }
}
