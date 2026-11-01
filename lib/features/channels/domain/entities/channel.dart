class Channel {
  final String id;
  final String name;
  final String description;
  final String organisationId;
  final bool isPrivate;
  final String ownerId;
  final bool archived;
  final int unreadCount;
  final int membersCount;
  final String? topic;

  Channel({
    required this.id,
    required this.name,
    required this.description,
    required this.organisationId,
    this.isPrivate = false,
    required this.ownerId,
    this.archived = false,
    this.unreadCount = 0,
    this.membersCount = 0,
    this.topic,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      // The server sends a channel's id as `channels_id` in the channel list.
      id: (json['channels_id'] ?? json['id']) as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      organisationId: json['organisation_id'] as String? ?? '',
      isPrivate: json['is_private'] as bool? ?? false,
      ownerId: json['owner_id'] as String? ?? '',
      archived: json['archived'] as bool? ?? false,
      topic: json['topic'] as String?,
      unreadCount: json['unread_count'] as int? ?? 0,
      membersCount: json['members_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'organisation_id': organisationId,
      'is_private': isPrivate,
      'owner_id': ownerId,
      'archived': archived,
      'topic': topic,
      'unread_count': unreadCount,
      'members_count': membersCount,
    };
  }

  Channel copyWith({
    String? id,
    String? name,
    String? description,
    String? organisationId,
    bool? isPrivate,
    String? ownerId,
    bool? archived,
    int? unreadCount,
    int? membersCount,
    String? topic,
  }) {
    return Channel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      organisationId: organisationId ?? this.organisationId,
      isPrivate: isPrivate ?? this.isPrivate,
      ownerId: ownerId ?? this.ownerId,
      archived: archived ?? this.archived,
      unreadCount: unreadCount ?? this.unreadCount,
      membersCount: membersCount ?? this.membersCount,
      topic: topic ?? this.topic,
    );
  }
}
