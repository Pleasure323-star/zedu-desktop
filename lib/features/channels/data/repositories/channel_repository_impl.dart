import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class ChannelRepositoryImpl implements ChannelRepository {
  final ChannelRemoteDataSource remoteDataSource;

  ChannelRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<List<Channel>>> fetchChannels(String orgId) async {
    try {
      final channels = await remoteDataSource.fetchChannels(orgId);
      return Success(channels);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<Channel>> createChannel({
    required String name,
    required String description,
    required String orgId,
    required String username,
    required bool isPrivate,
    String? topic,
  }) async {
    try {
      final channel = await remoteDataSource.createChannel(
        name: name,
        description: description,
        orgId: orgId,
        username: username,
        isPrivate: isPrivate,
        topic: topic,
      );
      return Success(channel);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> updateChannelTopicOrDescription({
    required String channelId,
    String? topic,
    String? description,
  }) async {
    try {
      await remoteDataSource.updateChannelTopicOrDescription(
        channelId: channelId,
        topic: topic,
        description: description,
      );
      return const Success(null);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> archiveChannel(String channelId, bool archived) async {
    try {
      await remoteDataSource.archiveChannel(channelId, archived);
      return const Success(null);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<List<String>>> fetchOrganisationMemberIds(String orgId) async {
    try {
      final ids = await remoteDataSource.fetchOrganisationMemberIds(orgId);
      return Success(ids);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<List<String>>> fetchChannelMemberIds(String channelId) async {
    try {
      final ids = await remoteDataSource.fetchChannelMemberIds(channelId);
      return Success(ids);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> addMembersToChannel({
    required String channelId,
    required List<String> userIds,
  }) async {
    try {
      await remoteDataSource.addMembersToChannel(
        channelId: channelId,
        userIds: userIds,
      );
      return const Success(null);
    } on ApiFailure catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiFailure(message: e.toString()));
    }
  }
}
