class DmConversation {
  final String channelId;
  final String username;
  final String participantId;
  final String? participantEmail;
  final String? avatarUrl;
  final String? defaultAvatarUrl;
  final String channelType;
  final bool isFavourite;
  final int threadCount;
  final String? lastThreadId;
  final DateTime? lastReadAt;
  final String previewMessage;
  final List<DmPreviewThread> previewThreads;
  final List<DmParticipant> participants;
  final int unreadCount;

  DmConversation({
    required this.channelId,
    required this.username,
    required this.participantId,
    this.participantEmail,
    this.avatarUrl,
    this.defaultAvatarUrl,
    this.channelType = 'dm',
    this.isFavourite = false,
    this.threadCount = 0,
    this.lastThreadId,
    this.lastReadAt,
    required this.previewMessage,
    this.previewThreads = const [],
    this.participants = const [],
    required this.unreadCount,
  });

  String get displayName => username.isNotEmpty ? username : 'Unknown';

  String? get effectiveAvatarUrl => (avatarUrl != null && avatarUrl!.isNotEmpty)
      ? avatarUrl
      : defaultAvatarUrl;

  /// False when the conversation has no messages and was never read, so
  /// [lastActivityAt] is only the epoch-0 placeholder used for sorting.
  bool get hasActivity => previewThreads.isNotEmpty || lastReadAt != null;

  DateTime get lastActivityAt {
    if (previewThreads.isNotEmpty) {
      return previewThreads.first.createdAt;
    }
    return lastReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory DmConversation.fromJson(Map<String, dynamic> json) {
    final rawThreads = json['preview_thread'];
    final threads = (rawThreads is List ? rawThreads : const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(DmPreviewThread.fromJson)
        .toList();

    final rawParticipants = json['participants'];
    final participantsList =
        (rawParticipants is List ? rawParticipants : const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(DmParticipant.fromJson)
            .toList();

    return DmConversation(
      channelId: json['channel_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      participantId: json['participant_id'] as String? ?? '',
      participantEmail: json['participant_email'] as String?,
      avatarUrl: _nonEmpty(json['avatar_url']),
      defaultAvatarUrl: _nonEmpty(json['default_avatar_url']),
      channelType: json['channel_type'] as String? ?? 'dm',
      isFavourite: json['is_favourite'] as bool? ?? false,
      threadCount: json['thread_count'] as int? ?? 0,
      lastThreadId: json['last_thread_id'] as String?,
      lastReadAt: json['last_read_at'] != null
          ? DateTime.tryParse(json['last_read_at'] as String)?.toLocal()
          : null,
      previewMessage: json['preview_message'] as String? ?? '',
      previewThreads: threads,
      participants: participantsList,
      unreadCount:
          json['unread_count'] as int? ?? json['thread_count'] as int? ?? 0,
    );
  }

  static String? _nonEmpty(dynamic value) {
    if (value == null) return null;
    final str = value.toString();
    return str.isNotEmpty ? str : null;
  }
}

class DmPreviewThread {
  final String threadId;
  final String message;
  final String userId;
  final String username;
  final DateTime createdAt;
  final int messageCount;

  DmPreviewThread({
    required this.threadId,
    required this.message,
    required this.userId,
    required this.username,
    required this.createdAt,
    this.messageCount = 0,
  });

  factory DmPreviewThread.fromJson(Map<String, dynamic> json) {
    return DmPreviewThread(
      threadId: json['thread_id'] as String? ?? '',
      message: json['message'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
      messageCount: json['message_count'] as int? ?? 0,
    );
  }
}

class DmParticipant {
  final String userId;
  final String username;
  final String email;
  final String? avatarUrl;
  final String? defaultAvatarUrl;
  final String userType;

  DmParticipant({
    required this.userId,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.defaultAvatarUrl,
    this.userType = 'user',
  });

  factory DmParticipant.fromJson(Map<String, dynamic> json) {
    return DmParticipant(
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      defaultAvatarUrl: json['default_avatar_url'] as String?,
      userType: json['user_type'] as String? ?? 'user',
    );
  }
}
