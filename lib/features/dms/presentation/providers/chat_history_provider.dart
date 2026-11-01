import 'dart:io' show File;

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class ChatHistoryNotifier extends ChangeNotifier {
  final String channelId;
  final Ref ref;

  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;
  bool hasMore = true;
  int page = 1;
  bool _isHistoryClearedLocally = false;

  String? editingMessageId;
  final Map<String, Future<void>> _saveEditChains = {};

  ChatHistoryNotifier(this.channelId, this.ref) {
    _loadInitial();
  }

  String get _currentUserId {
    final authState = ref.read(authNotifierProvider);
    return authState.user?.id ?? '';
  }

  String get currentUserName {
    final user = ref.read(authNotifierProvider).user;
    if (user == null) return 'You';
    final name = '${user.firstName} ${user.lastName}'.trim();
    return name.isNotEmpty ? name : user.username;
  }

  String? get currentUserAvatarUrl {
    final user = ref.read(authNotifierProvider).user;
    if (user == null) return null;
    return user.avatarUrl.isNotEmpty ? user.avatarUrl : user.defaultAvatarUrl;
  }

  bool isMyMessage(Map<String, dynamic> message) {
    final senderId = message['user_id'] ?? message['userId'];
    return senderId == _currentUserId || senderId == 'me';
  }

  String? get lastSentMessageContent {
    for (final msg in messages) {
      if (isMyMessage(msg) && msg['status'] != 'failed') {
        return msg['content'] as String?;
      }
    }
    return null;
  }

  String? get lastSentMessageId {
    for (final msg in messages) {
      if (isMyMessage(msg) && msg['status'] != 'failed') {
        return msg['id'] as String?;
      }
    }
    return null;
  }

  Future<void> _loadInitial() async {
    try {
      final repository = ref.read(dmRepositoryProvider);
      messages = await repository.getMessages(channelId, page: 1);
      hasMore = messages.length >= DmRepository.pageSize;
      page = 1;
    } catch (_) {
    } finally {
      isLoading = false;
      notifyListeners();
    }
    // Start polling for new messages now that the initial load is done.
    _startPolling();
  }

  // ── Realtime notification polling ────────────────────────────────────────────

  /// Set of message IDs we have already seen. Used to detect truly-new messages
  /// so we don't re-fire a notification on every poll cycle.
  final Set<String> _seenIds = {};

  /// Keep track of the polling timer so we can cancel it on dispose.
  // ignore: cancel_subscriptions
  dynamic _pollingTimer;

  void _startPolling() {
    // Record all initially-loaded IDs as "already seen" so we only notify
    // about messages that arrive AFTER the initial load.
    for (final m in messages) {
      final id = m['id']?.toString();
      if (id != null) _seenIds.add(id);
    }

    // Poll every 10 seconds for new messages.
    _pollingTimer = Stream<int>.periodic(const Duration(seconds: 10), (i) => i)
        .listen((_) {
          _pollForNewMessages();
        });
  }

  Future<void> _pollForNewMessages() async {
    if (_isHistoryClearedLocally) return;
    try {
      final repository = ref.read(dmRepositoryProvider);
      final fresh = await repository.getMessages(channelId, page: 1);

      bool hadNew = false;
      for (final msg in fresh) {
        final id = msg['id']?.toString();
        if (id == null || _seenIds.contains(id)) continue;

        _seenIds.add(id);
        hadNew = true;

        // Only notify for messages from other users.
        if (!isMyMessage(msg)) {
          final senderName =
              (msg['sender_name'] ?? msg['username'] ?? 'Someone').toString();
          ref
              .read(notificationServiceProvider)
              .handleIncomingMessage(msg, channelId, senderName);
        }
      }

      if (hadNew) {
        // Prepend only the genuinely new messages at the top.
        final existingIds = messages.map((m) => m['id']?.toString()).toSet();
        final newOnly = fresh
            .where(
              (m) =>
                  !existingIds.contains(m['id']?.toString()) && !_isDeleted(m),
            )
            .toList();
        if (newOnly.isNotEmpty) {
          messages = [...newOnly, ...messages];
          notifyListeners();
        }
      }
    } catch (_) {
      // Silent — polling failures should not surface to the UI.
    }
  }

  @override
  void dispose() {
    (_pollingTimer as dynamic)?.cancel();
    // Recordings kept for messages that never sent are no longer needed.
    for (final options in _sendOptions.values) {
      _deleteRecordings(options.media);
    }
    _sendOptions.clear();
    super.dispose();
  }

  Future<void> loadMore() async {
    if (isLoading || !hasMore) return;

    isLoading = true;
    notifyListeners();

    try {
      final repository = ref.read(dmRepositoryProvider);
      final nextPage = page + 1;
      final newMessages = await repository.getMessages(
        channelId,
        page: nextPage,
      );

      messages = [...messages, ...newMessages.where((m) => !_isDeleted(m))];
      hasMore = newMessages.length >= DmRepository.pageSize;
      page = nextPage;
    } catch (_) {
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // What each message was sent with, so a retry sends it the same way.
  final Map<String, ({List<XFile>? media, bool isChannel})> _sendOptions = {};

  /// Deletes voice recordings this app made once their message is sent. Files
  /// the user picked are never deleted.
  Future<void> _deleteRecordings(List<XFile>? files) async {
    for (final file in files ?? const <XFile>[]) {
      if (appRecordedPaths.remove(file.path)) {
        try {
          await File(file.path).delete();
        } catch (_) {}
      }
    }
  }

  Future<void> sendMessage(
    String content, {
    List<XFile>? media,
    List<dynamic>? mentions,
    bool isChannel = false,
  }) async {
    _isHistoryClearedLocally = false;
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final optimisticMessage = {
      "id": tempId,
      "content": content,
      "channel_id": channelId,
      "user_id": _currentUserId,
      "userId": _currentUserId,
      "type": "user",
      "created_at": DateTime.now().toIso8601String(),
      "status": "sending",
      if (media != null && media.isNotEmpty)
        "media": [
          for (final file in media) {"file_name": file.name},
        ],
    };

    _sendOptions[tempId] = (media: media, isChannel: isChannel);
    messages = [optimisticMessage, ...messages];
    notifyListeners();

    try {
      final repository = ref.read(dmRepositoryProvider);
      final threadId = await repository.sendMessage(
        channelId,
        content,
        media: media,
        mentions: mentions,
        isChannel: isChannel,
      );
      _sendOptions.remove(tempId);
      _deleteRecordings(media);

      messages = messages.map((m) {
        if (m['id'] == tempId) {
          final newMsg = Map<String, dynamic>.from(m);
          newMsg.remove('status');
          newMsg['thread_id'] = threadId;
          return newMsg;
        }
        return m;
      }).toList();
    } catch (_) {
      messages = messages.map((m) {
        if (m['id'] == tempId) {
          final newMsg = Map<String, dynamic>.from(m);
          newMsg['status'] = 'failed';
          return newMsg;
        }
        return m;
      }).toList();
    } finally {
      notifyListeners();
    }
  }

  Future<void> retryMessage(String messageId) async {
    final idx = messages.indexWhere((m) => m['id'] == messageId);
    if (idx == -1) return;

    final failedMsg = Map<String, dynamic>.from(messages[idx]);
    final content = failedMsg['content'] as String? ?? '';

    failedMsg['status'] = 'sending';
    messages = List<Map<String, dynamic>>.from(messages);
    messages[idx] = failedMsg;
    notifyListeners();

    try {
      final repository = ref.read(dmRepositoryProvider);
      final options = _sendOptions[messageId];
      final threadId = await repository.sendMessage(
        channelId,
        content,
        media: options?.media,
        isChannel: options?.isChannel ?? false,
      );
      _sendOptions.remove(messageId);
      _deleteRecordings(options?.media);

      messages = messages.map((m) {
        if (m['id'] == messageId) {
          final newMsg = Map<String, dynamic>.from(m);
          newMsg.remove('status');
          newMsg['thread_id'] = threadId;
          return newMsg;
        }
        return m;
      }).toList();
    } catch (_) {
      messages = messages.map((m) {
        if (m['id'] == messageId) {
          final newMsg = Map<String, dynamic>.from(m);
          newMsg['status'] = 'failed';
          return newMsg;
        }
        return m;
      }).toList();
    } finally {
      notifyListeners();
    }
  }

  void clearLocalHistory() {
    _isHistoryClearedLocally = true;
    messages = [];
    hasMore = false;
    page = 1;
    notifyListeners();
  }

  void startEditing(String messageId) {
    final msg = messages.firstWhere(
      (m) => m['id'] == messageId,
      orElse: () => <String, dynamic>{},
    );
    if (msg.isEmpty) return;

    editingMessageId = messageId;
    notifyListeners();
  }

  void cancelEditing() {
    editingMessageId = null;
    notifyListeners();
  }

  /// Ids of messages being deleted or already deleted, so polling and paging
  /// do not bring them back.
  final Set<String> _deletedIds = {};

  bool _isDeleted(Map<String, dynamic> message) =>
      _deletedIds.contains(message['id']?.toString());

  /// Removes the message right away and puts it back if the request fails.
  Future<void> deleteMessage(String messageId) async {
    final index = messages.indexWhere((m) => m['id'] == messageId);
    if (index == -1) return;

    final removed = messages[index];
    final threadId = (removed['thread_id'] ?? removed['id']).toString();
    if (editingMessageId == messageId) editingMessageId = null;
    _deletedIds.add(messageId);
    messages = [...messages]..removeAt(index);
    notifyListeners();

    try {
      final repository = ref.read(dmRepositoryProvider);
      await repository.deleteMessage(threadId: threadId, channelId: channelId);
    } catch (_) {
      _deletedIds.remove(messageId);
      messages = [...messages]
        ..insert(index.clamp(0, messages.length), removed);
      notifyListeners();
    }
  }

  Future<void> saveEdit(String messageId, String newContent) {
    final previous = _saveEditChains[messageId] ?? Future<void>.value();
    final task = previous.then((_) => _runSaveEdit(messageId, newContent));
    _saveEditChains[messageId] = task.catchError((_) {});
    return task;
  }

  Future<void> _runSaveEdit(String messageId, String newContent) async {
    if (newContent.trim().isEmpty) {
      cancelEditing();
      return;
    }

    final baselineContent =
        messages.firstWhere(
              (m) => m['id'] == messageId,
              orElse: () => <String, dynamic>{},
            )['content']
            as String?;

    messages = messages.map((m) {
      if (m['id'] == messageId) {
        final updated = Map<String, dynamic>.from(m);
        updated['content'] = newContent;
        return updated;
      }
      return m;
    }).toList();
    if (editingMessageId == messageId) {
      editingMessageId = null;
    }
    notifyListeners();

    try {
      final repository = ref.read(dmRepositoryProvider);
      await repository.editMessage(channelId, content: newContent);
    } catch (_) {
      messages = messages.map((m) {
        if (m['id'] == messageId && m['content'] == newContent) {
          final reverted = Map<String, dynamic>.from(m);
          reverted['content'] = baselineContent;
          return reverted;
        }
        return m;
      }).toList();
      notifyListeners();
    }
  }
}

final chatHistoryProvider =
    ChangeNotifierProvider.family<ChatHistoryNotifier, String>(
      (ref, channelId) => ChatHistoryNotifier(channelId, ref),
    );
