import '../../../../helpers/helpers.dart';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

ApiResponseModel<Map<String, dynamic>> _ok() {
  return const ApiResponseModel(data: <String, dynamic>{}, statusCode: 200);
}

ApiResponseModel<Map<String, dynamic>> _saved() {
  return const ApiResponseModel(
    data: <String, dynamic>{
      'data': {
        'id': 'org-1',
        'name': 'Acme',
        'type': 'Design agency',
        'country': 'Nigeria',
      },
    },
    statusCode: 200,
  );
}

void main() {
  group('UserProfileRemoteDataSourceImpl.updateOrganization', () {
    late MockApiBaseService api;
    late UserProfileRemoteDataSourceImpl dataSource;
    const organization = OrganizationProfile(
      id: 'org-1',
      name: 'Acme',
      natureOfBusiness: 'Design agency',
      country: 'Nigeria',
    );

    setUp(() {
      api = MockApiBaseService();
      dataSource = UserProfileRemoteDataSourceImpl(
        config: const AppConfig(
          apiBaseUrl: 'https://api.example.com',
          usesMockData: false,
        ),
        apiBaseService: api,
      );
      when(
        () => api.put<Map<String, dynamic>>(
          path: any(named: 'path'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => _saved());
      when(
        () => api.patch<Map<String, dynamic>>(
          path: any(named: 'path'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => _saved());
    });

    test('saves to the workspace that was given', () async {
      await dataSource.updateOrganization(organization, orgId: 'org-1');

      verify(
        () => api.put<Map<String, dynamic>>(
          path: '/organisations/org-1',
          data: {
            'id': 'org-1',
            'name': 'Acme',
            'type': 'Design agency',
            'country': 'Nigeria',
          },
        ),
      ).called(1);
      verifyNever(
        () => api.patch<Map<String, dynamic>>(
          path: any(named: 'path'),
          data: any(named: 'data'),
        ),
      );
    });

    test('uses the profile endpoint when no workspace is given', () async {
      await dataSource.updateOrganization(organization);

      verify(
        () => api.patch<Map<String, dynamic>>(
          path: '/profile/organization',
          data: any(named: 'data'),
        ),
      ).called(1);
    });
  });

  group('UserProfileRemoteDataSourceImpl.deleteOrganization', () {
    late MockApiBaseService api;
    late UserProfileRemoteDataSourceImpl dataSource;

    setUp(() {
      api = MockApiBaseService();
      dataSource = UserProfileRemoteDataSourceImpl(
        config: const AppConfig(
          apiBaseUrl: 'https://api.example.com',
          usesMockData: false,
        ),
        apiBaseService: api,
      );
      when(
        () => api.delete<Map<String, dynamic>>(path: any(named: 'path')),
      ).thenAnswer((_) async => _ok());
    });

    test('deletes the workspace that was given', () async {
      await dataSource.deleteOrganization(orgId: 'org-1');

      verify(
        () => api.delete<Map<String, dynamic>>(path: '/organisations/org-1'),
      ).called(1);
    });

    test('uses the profile endpoint when no workspace is given', () async {
      await dataSource.deleteOrganization();

      verify(
        () => api.delete<Map<String, dynamic>>(path: '/profile/organization'),
      ).called(1);
    });
  });
}
