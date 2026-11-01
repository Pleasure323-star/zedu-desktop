class Workspace {
  final String id;
  final String name;
  final String avatar;
  final int unreadCount;
  final int channelsCount;

  const Workspace({
    required this.id,
    required this.name,
    required this.avatar,
    this.unreadCount = 0,
    this.channelsCount = 0,
  });

  /// What the organisation switcher shows under the name, e.g. "1 channel".
  String get channelsLabel =>
      channelsCount == 1 ? '1 channel' : '$channelsCount channels';

  Workspace copyWith({
    String? id,
    String? name,
    String? avatar,
    int? unreadCount,
    int? channelsCount,
  }) {
    return Workspace(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      unreadCount: unreadCount ?? this.unreadCount,
      channelsCount: channelsCount ?? this.channelsCount,
    );
  }
}
