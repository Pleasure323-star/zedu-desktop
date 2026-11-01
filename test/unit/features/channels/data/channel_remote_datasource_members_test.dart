import '../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

ApiResponseModel<Map<String, dynamic>> _page(List<String> ids) {
  return ApiResponseModel<Map<String, dynamic>>(
    data: {
      'data': [
        for (final id in ids) {'id': id, 'email': '$id@zedu.chat'},
      ],
    },
    statusCode: 200,
  );
}

void main() {
  group('ChannelRemoteDataSourceImpl members', () {
    late MockApiBaseService mockApi;
    late ChannelRemoteDataSourceImpl datasource;

    setUp(() {
      mockApi = MockApiBaseService();
      datasource = ChannelRemoteDataSourceImpl(apiBaseService: mockApi);
    });

    test('fetchOrganisationMemberIds reads every page of members', () async {
      const pageSize = ChannelRemoteDataSourceImpl.memberPageSize;
      final firstPage = List.generate(pageSize, (i) => 'u$i');
      when(
        () => mockApi.get<Map<String, dynamic>>(
          path: '/organisations/org-1/users',
          queryParameters: {'page': 1, 'limit': pageSize},
        ),
      ).thenAnswer((_) async => _page(firstPage));
      when(
        () => mockApi.get<Map<String, dynamic>>(
          path: '/organisations/org-1/users',
          queryParameters: {'page': 2, 'limit': pageSize},
        ),
      ).thenAnswer((_) async => _page(['last']));

      final ids = await datasource.fetchOrganisationMemberIds('org-1');

      expect(ids, [...firstPage, 'last']);
      verifyNever(
        () => mockApi.get<Map<String, dynamic>>(
          path: '/organisations/org-1/users',
          queryParameters: {'page': 3, 'limit': pageSize},
        ),
      );
    });

    test(
      'throws instead of returning part of a list that fills every page',
      () {
        const pageSize = ChannelRemoteDataSourceImpl.memberPageSize;
        when(
          () => mockApi.get<Map<String, dynamic>>(
            path: '/channels/ch-1/users',
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer((_) async => _page(List.generate(pageSize, (i) => 'u$i')));

        expect(
          datasource.fetchChannelMemberIds('ch-1'),
          throwsA(isA<ApiFailure>()),
        );
      },
    );

    test('fetchChannelMemberIds skips entries without an id', () async {
      when(
        () => mockApi.get<Map<String, dynamic>>(
          path: '/channels/ch-1/users',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => ApiResponseModel<Map<String, dynamic>>(
          data: {
            'data': [
              {'id': 'u1'},
              {'email': 'no-id@zedu.chat'},
              {'id': ''},
            ],
          },
          statusCode: 200,
        ),
      );

      final ids = await datasource.fetchChannelMemberIds('ch-1');

      expect(ids, ['u1']);
    });

    test('addMembersToChannel posts the channel and user ids', () async {
      when(
        () => mockApi.post<Map<String, dynamic>>(
          path: any(named: 'path'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          data: {'message': 'users added to channel successfully'},
          statusCode: 200,
        ),
      );

      await datasource.addMembersToChannel(
        channelId: 'ch-1',
        userIds: ['u1', 'u2'],
      );

      verify(
        () => mockApi.post<Map<String, dynamic>>(
          path: '/channels/add-multiple',
          data: {
            'channel_id': 'ch-1',
            'user_ids': ['u1', 'u2'],
          },
        ),
      ).called(1);
    });
  });
}
