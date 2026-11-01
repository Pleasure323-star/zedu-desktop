import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

enum ActiveChatType {
  channel,
  groupDm,
  newGroupChat,
  directMessage,
  channelDirectory,
}

class ActiveChatState {
  final ActiveChatType type;
  final String? id;

  const ActiveChatState({required this.type, this.id});

  static const generalChannel = ActiveChatState(
    type: ActiveChatType.channel,
    id: 'general',
  );
  static const newGroupChat = ActiveChatState(
    type: ActiveChatType.newGroupChat,
  );
  static const channelDirectory = ActiveChatState(
    type: ActiveChatType.channelDirectory,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveChatState &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          id == other.id;

  @override
  int get hashCode => type.hashCode ^ id.hashCode;
}

class ActiveChatNotifier extends Notifier<ActiveChatState> {
  @override
  ActiveChatState build() {
    // A channel picked in one workspace means nothing in another, so the
    // selection starts over when the workspace changes.
    ref.watch(workspaceProvider.select((s) => s.selectedWorkspace?.id));
    return ActiveChatState.generalChannel;
  }

  void selectChannel(String channelId) {
    state = ActiveChatState(type: ActiveChatType.channel, id: channelId);
  }

  void selectGroupDm(String groupDmId) {
    state = ActiveChatState(type: ActiveChatType.groupDm, id: groupDmId);
  }

  void selectDirectMessage(String userId) {
    state = ActiveChatState(type: ActiveChatType.directMessage, id: userId);
  }

  void selectChannelDirectory() {
    state = ActiveChatState.channelDirectory;
  }

  void selectNewGroupChat() {
    state = ActiveChatState.newGroupChat;
  }
}

final activeChatProvider =
    NotifierProvider<ActiveChatNotifier, ActiveChatState>(
      ActiveChatNotifier.new,
    );
