import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

abstract class ChannelRepository {
  Future<Result<List<Channel>>> fetchChannels(String orgId);
  Future<Result<Channel>> createChannel({
    required String name,
    required String description,
    required String orgId,
    required String username,
    required bool isPrivate,
    String? topic,
  });
  Future<Result<void>> updateChannelTopicOrDescription({
    required String channelId,
    String? topic,
    String? description,
  });
  Future<Result<void>> archiveChannel(String channelId, bool archived);
  Future<Result<List<String>>> fetchOrganisationMemberIds(String orgId);
  Future<Result<List<String>>> fetchChannelMemberIds(String channelId);
  Future<Result<void>> addMembersToChannel({
    required String channelId,
    required List<String> userIds,
  });
}
