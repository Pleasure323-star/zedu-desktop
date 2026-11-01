import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

abstract class ChannelRemoteDataSource {
  Future<List<Channel>> fetchChannels(String orgId);
  Future<Channel> createChannel({
    required String name,
    required String description,
    required String orgId,
    required String username,
    required bool isPrivate,
    String? topic,
  });
  Future<void> updateChannelTopicOrDescription({
    required String channelId,
    String? topic,
    String? description,
  });
  Future<void> archiveChannel(String channelId, bool archived);
  Future<List<String>> fetchOrganisationMemberIds(String orgId);
  Future<List<String>> fetchChannelMemberIds(String channelId);
  Future<void> addMembersToChannel({
    required String channelId,
    required List<String> userIds,
  });
}

class ChannelRemoteDataSourceImpl implements ChannelRemoteDataSource {
  final ApiBaseService apiBaseService;

  /// Page size for the paginated member lists (the backend default is 20).
  static const memberPageSize = 100;

  /// Stops paging a broken or endless member list after this many pages.
  static const maxMemberPages = 50;

  ChannelRemoteDataSourceImpl({required this.apiBaseService});

  @override
  Future<List<Channel>> fetchChannels(String orgId) async {
    final response = await apiBaseService.get<Map<String, dynamic>>(
      path: '/organisations/$orgId/channels',
    );
    final data = response.data['data'] as List?;
    if (data == null) return [];
    return data
        .map((e) => Channel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Channel> createChannel({
    required String name,
    required String description,
    required String orgId,
    required String username,
    required bool isPrivate,
    String? topic,
  }) async {
    final body = {
      'name': name,
      'description': description,
      'organisation_id': orgId,
      'username': username,
      'is_private': isPrivate,
      'topic': ?topic,
    };
    final response = await apiBaseService.post<Map<String, dynamic>>(
      path: '/channels',
      data: body,
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from create channel');
    return Channel.fromJson(data);
  }

  @override
  Future<void> updateChannelTopicOrDescription({
    required String channelId,
    String? topic,
    String? description,
  }) async {
    final data = <String, dynamic>{};
    if (topic != null) data['topic'] = topic;
    if (description != null) data['description'] = description;

    await apiBaseService.put<Map<String, dynamic>>(
      path: '/channels/$channelId/',
      data: data,
    );
  }

  @override
  Future<void> archiveChannel(String channelId, bool archived) async {
    await apiBaseService.put<Map<String, dynamic>>(
      path: '/channels/$channelId/archive',
      data: {'archived': archived},
    );
  }

  @override
  Future<List<String>> fetchOrganisationMemberIds(String orgId) {
    // People only: this endpoint leaves bots out unless include_bots=true.
    return _fetchAllMemberIds('/organisations/$orgId/users');
  }

  @override
  Future<List<String>> fetchChannelMemberIds(String channelId) {
    return _fetchAllMemberIds('/channels/$channelId/users');
  }

  @override
  Future<void> addMembersToChannel({
    required String channelId,
    required List<String> userIds,
  }) async {
    await apiBaseService.post<Map<String, dynamic>>(
      path: '/channels/add-multiple',
      data: {'channel_id': channelId, 'user_ids': userIds},
    );
  }

  Future<List<String>> _fetchAllMemberIds(String path) async {
    final ids = <String>[];
    for (var page = 1; page <= maxMemberPages; page++) {
      final response = await apiBaseService.get<Map<String, dynamic>>(
        path: path,
        queryParameters: {'page': page, 'limit': memberPageSize},
      );
      final data = response.data['data'] as List?;
      if (data == null || data.isEmpty) return ids;
      for (final item in data) {
        final id = (item as Map<String, dynamic>)['id'] as String?;
        if (id != null && id.isNotEmpty) ids.add(id);
      }
      if (data.length < memberPageSize) return ids;
    }
    // Every page was full, so the list may go on. Fail rather than act on
    // part of it.
    throw ApiFailure(
      message: 'Too many members to load. Please try again later.',
      path: path,
    );
  }
}
