import '../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  group('AuthRemoteDataSourceImpl', () {
    late MockApiBaseService mockApi;

    setUp(() {
      mockApi = MockApiBaseService();
    });

    group('login', () {
      test('returns mock response when usesMockData is true', () async {
        final datasource = AuthRemoteDataSourceImpl(
          config: const AppConfig(
            apiBaseUrl: 'https://api.example.com',
            usesMockData: true,
          ),
          apiBaseService: mockApi,
        );

        final result = await datasource.login(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result, isA<LoginResponseModel>());
        expect(result.accessToken, isNotEmpty);
        expect(result.user.email, isNotEmpty);
        verifyNever(
          () => mockApi.post<Map<String, dynamic>>(
            path: any(named: 'path'),
            data: any(named: 'data'),
          ),
        );
      });

      test('calls POST /auth/login with correct credentials', () async {
        when(
          () => mockApi.post<Map<String, dynamic>>(
            path: '/auth/login',
            data: {'email': 'user@example.com', 'password': 'Secret123'},
          ),
        ).thenAnswer(
          (_) async => ApiResponseModel<Map<String, dynamic>>(
            data: {'data': LoginResponseModel.mockLoginResponse},
            statusCode: 200,
          ),
        );

        final datasource = AuthRemoteDataSourceImpl(
          config: const AppConfig(
            apiBaseUrl: 'https://api.example.com',
            usesMockData: false,
          ),
          apiBaseService: mockApi,
        );

        await datasource.login(
          email: 'user@example.com',
          password: 'Secret123',
        );

        verify(
          () => mockApi.post<Map<String, dynamic>>(
            path: '/auth/login',
            data: {'email': 'user@example.com', 'password': 'Secret123'},
          ),
        ).called(1);
      });

      test('rethrows ApiFailure from the API', () async {
        final failure = ApiFailure.unknown(Exception('network error'));

        when(
          () => mockApi.post<Map<String, dynamic>>(
            path: '/auth/login',
            data: any(named: 'data'),
          ),
        ).thenThrow(failure);

        final datasource = AuthRemoteDataSourceImpl(
          config: const AppConfig(
            apiBaseUrl: 'https://api.example.com',
            usesMockData: false,
          ),
          apiBaseService: mockApi,
        );

        expect(
          () => datasource.login(email: 'test@example.com', password: 'pass'),
          throwsA(isA<ApiFailure>()),
        );
      });
    });

    group('me', () {
      test('returns user from mock data when usesMockData is true', () async {
        final datasource = AuthRemoteDataSourceImpl(
          config: const AppConfig(
            apiBaseUrl: 'https://api.example.com',
            usesMockData: true,
          ),
          apiBaseService: mockApi,
        );

        final user = await datasource.me();

        expect(user.email, isNotEmpty);
        verifyNever(
          () => mockApi.get<Map<String, dynamic>>(path: any(named: 'path')),
        );
      });

      test('calls GET /profile and maps the profile to a user', () async {
        const rawProfile = <String, dynamic>{
          'id': '019142c8-5408-7a48-8173-f31e6c8e00cd',
          'user_id': '019142c8-5408-7a47-b94c-91d674dd8358',
          'email': 'profile@example.com',
          'phone': '09099999999',
          'first_name': 'Test',
          'last_name': 'Og',
          'full_name': 'Test Og',
          'username': 'tester',
          'avatar_url': 'avatar.png',
          'default_avatar_url': 'default.png',
          'created_at': '2024-08-11T19:51:50+01:00',
          'updated_at': '2024-08-12T00:59:39+01:00',
          'deactivated': false,
          'organisation_id': 'org-1',
        };

        when(
          () => mockApi.get<Map<String, dynamic>>(path: '/profile'),
        ).thenAnswer(
          (_) async => ApiResponseModel<Map<String, dynamic>>(
            data: {'data': rawProfile},
            statusCode: 200,
          ),
        );

        final datasource = AuthRemoteDataSourceImpl(
          config: const AppConfig(
            apiBaseUrl: 'https://api.example.com',
            usesMockData: false,
          ),
          apiBaseService: mockApi,
        );

        final user = (await datasource.me()).toEntity();

        expect(user.id, rawProfile['user_id']);
        expect(user.email, rawProfile['email']);
        expect(user.currentOrg, 'org-1');
        expect(user.fullname, 'Test Og');
        expect(user.createdAt, DateTime.parse('2024-08-11T19:51:50+01:00'));
        verify(
          () => mockApi.get<Map<String, dynamic>>(path: '/profile'),
        ).called(1);
        verifyNever(() => mockApi.get<Map<String, dynamic>>(path: '/auth/me'));
      });

      test('rethrows ApiFailure from GET /profile', () async {
        when(
          () => mockApi.get<Map<String, dynamic>>(path: '/profile'),
        ).thenThrow(
          const ApiFailure(
            message: 'Unauthorized',
            kind: ApiFailureKind.unauthorized,
          ),
        );

        final datasource = AuthRemoteDataSourceImpl(
          config: const AppConfig(
            apiBaseUrl: 'https://api.example.com',
            usesMockData: false,
          ),
          apiBaseService: mockApi,
        );

        await expectLater(datasource.me(), throwsA(isA<ApiFailure>()));
      });
    });

    group('sendMagicLink', () {
      test('calls POST /auth/magick-link with email payload', () async {
        when(
          () => mockApi.post<Map<String, dynamic>>(
            path: '/auth/magick-link',
            data: {'email': 'magic@example.com'},
          ),
        ).thenAnswer(
          (_) async => ApiResponseModel<Map<String, dynamic>>(
            data: {'status': 'success'},
            statusCode: 200,
          ),
        );

        final datasource = AuthRemoteDataSourceImpl(
          config: const AppConfig(
            apiBaseUrl: 'https://api.example.com',
            usesMockData: false,
          ),
          apiBaseService: mockApi,
        );

        await datasource.sendMagicLink(email: 'magic@example.com');

        verify(
          () => mockApi.post<Map<String, dynamic>>(
            path: '/auth/magick-link',
            data: {'email': 'magic@example.com'},
          ),
        ).called(1);
      });
    });

    group('verifyMagicLink', () {
      test('calls POST /auth/magick-link/verify with token', () async {
        when(
          () => mockApi.post<Map<String, dynamic>>(
            path: '/auth/magick-link/verify',
            data: {'token': 'token-123'},
          ),
        ).thenAnswer(
          (_) async => ApiResponseModel<Map<String, dynamic>>(
            data: {'data': LoginResponseModel.mockLoginResponse},
            statusCode: 200,
          ),
        );

        final datasource = AuthRemoteDataSourceImpl(
          config: const AppConfig(
            apiBaseUrl: 'https://api.example.com',
            usesMockData: false,
          ),
          apiBaseService: mockApi,
        );

        final result = await datasource.verifyMagicLink(token: 'token-123');

        expect(result, isA<LoginResponseModel>());
        verify(
          () => mockApi.post<Map<String, dynamic>>(
            path: '/auth/magick-link/verify',
            data: {'token': 'token-123'},
          ),
        ).called(1);
      });
    });
  });
}
