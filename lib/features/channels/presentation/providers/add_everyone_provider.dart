import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Outcome of adding everyone in the organisation to a channel.
sealed class AddEveryoneResult {
  const AddEveryoneResult();
}

class AddEveryoneAdded extends AddEveryoneResult {
  const AddEveryoneAdded(this.count, this.channelName);
  final int count;
  final String channelName;
}

class AddEveryoneNobodyToAdd extends AddEveryoneResult {
  const AddEveryoneNobodyToAdd(this.channelName);
  final String channelName;
}

class AddEveryoneFailed extends AddEveryoneResult {
  const AddEveryoneFailed(this.message);
  final String message;
}

const generalChannelName = 'general';

/// The channel "Add everyone" adds to: the one open in the sidebar, or
/// #general when no channel is open (for example a direct message).
String openChannelName(ActiveChatState chat) {
  final name = chat.id?.trim() ?? '';
  return chat.type == ActiveChatType.channel && name.isNotEmpty
      ? name
      : generalChannelName;
}

/// Organisation members who are not in the channel yet, without the current
/// user, duplicates or empty ids. Keeps the organisation list's order.
List<String> usersToAddToChannel({
  required List<String> organisationMemberIds,
  required List<String> channelMemberIds,
  String? currentUserId,
}) {
  final skip = {...channelMemberIds, ?currentUserId};
  final result = <String>[];
  for (final id in organisationMemberIds) {
    if (id.isEmpty || skip.contains(id)) continue;
    skip.add(id);
    result.add(id);
  }
  return result;
}

/// Adds every member of the selected organisation to the open channel.
class AddEveryoneToChannel {
  AddEveryoneToChannel(this._ref);

  final Ref _ref;

  Future<AddEveryoneResult> call() async {
    final channelName = openChannelName(_ref.read(activeChatProvider));
    final orgId = _ref.read(workspaceProvider).selectedWorkspace?.id;
    if (orgId == null) {
      return const AddEveryoneFailed('No organisation is selected.');
    }
    final currentUserId = _ref.read(authNotifierProvider).user?.id;
    final repository = _ref.read(channelRepositoryProvider);

    final channelsResult = await repository.fetchChannels(orgId);
    if (channelsResult is Failure<List<Channel>>) {
      return _failed(channelsResult.error, channelName);
    }
    final channels = (channelsResult as Success<List<Channel>>).value;
    final channel = channels
        .where(
          (c) =>
              !c.archived && c.name.toLowerCase() == channelName.toLowerCase(),
        )
        .firstOrNull;
    if (channel == null) {
      return AddEveryoneFailed(
        'Could not find #$channelName in this organisation.',
      );
    }

    final orgMembersResult = await repository.fetchOrganisationMemberIds(orgId);
    if (orgMembersResult is Failure<List<String>>) {
      return _failed(orgMembersResult.error, channelName);
    }
    final channelMembersResult = await repository.fetchChannelMemberIds(
      channel.id,
    );
    if (channelMembersResult is Failure<List<String>>) {
      return _failed(channelMembersResult.error, channelName);
    }

    final userIds = usersToAddToChannel(
      organisationMemberIds: (orgMembersResult as Success<List<String>>).value,
      channelMemberIds: (channelMembersResult as Success<List<String>>).value,
      currentUserId: currentUserId,
    );
    // The backend rejects an empty list, so say so instead of calling it.
    if (userIds.isEmpty) return AddEveryoneNobodyToAdd(channelName);

    final addResult = await repository.addMembersToChannel(
      channelId: channel.id,
      userIds: userIds,
    );
    if (addResult is Failure<void>) {
      return _failed(addResult.error, channelName);
    }
    return AddEveryoneAdded(userIds.length, channelName);
  }

  AddEveryoneFailed _failed(ApiFailure error, String channelName) {
    final message = error.message.trim();
    return AddEveryoneFailed(
      message.isEmpty
          ? 'Could not add everyone to #$channelName. Please try again.'
          : message,
    );
  }
}

final addEveryoneToChannelProvider = Provider<AddEveryoneToChannel>(
  AddEveryoneToChannel.new,
);
