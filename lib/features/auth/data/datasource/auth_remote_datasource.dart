import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

abstract interface class AuthRemoteDataSource {
  Future<LoginResponseModel> login({
    required String email,
    required String password,
  });
  Future<ProfileModel> me();
  Future<void> signUp({
    required String username,
    required String email,
    required String password,
  });
  Future<void> forgotPassword({required String email});
  Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  });
  Future<void> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  });
  Future<void> sendMagicLink({required String email});
  Future<LoginResponseModel> verifyMagicLink({required String token});
  Future<LoginResponseModel> signInWithGoogle({
    required String grantCode,
    String? redirectUri,
  });
  Future<void> changeStatus({
    required String icon,
    required String text,
    required bool pauseNotifications,
    required String statusTimeout,
    required bool clearStatus,
    required bool online,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl({
    required AppConfig config,
    required ApiBaseService apiBaseService,
  }) : _config = config,
       _apiBaseService = apiBaseService;

  final AppConfig _config;
  final ApiBaseService _apiBaseService;

  static const _tag = 'AuthRemoteDataSource';

  @override
  Future<LoginResponseModel> login({
    required String email,
    required String password,
  }) async {
    try {
      if (_config.usesMockData) {
        AppLogger.d('Using mock data for POST /auth/login', tag: _tag);
        if (password != mockPassword) {
          throw const ApiFailure(
            message: 'Invalid credentials',
            kind: ApiFailureKind.client,
          );
        }
        return LoginResponseModel.fromJson(
          LoginResponseModel.mockLoginResponse,
        );
      }

      AppLogger.d('POST /auth/login — $email', tag: _tag);
      final response = await _apiBaseService.post<Map<String, dynamic>>(
        path: '/auth/login',
        data: {'email': email, 'password': password},
      );

      final payload = response.data['data'] as Map<String, dynamic>;
      return LoginResponseModel.fromJson(payload);
    } on ApiFailure {
      rethrow;
    } catch (error) {
      AppLogger.e(
        'Failed to parse /auth/login response',
        tag: _tag,
        error: error,
      );
      throw ApiFailure.fromParsingError(error, path: 'auth/login');
    }
  }

  @override
  Future<ProfileModel> me() async {
    try {
      if (_config.usesMockData) {
        AppLogger.d('Using mock data for GET /profile', tag: _tag);
        return ProfileModel.fromJson(
          LoginResponseModel.mockLoginResponse['user'] as Map<String, dynamic>,
        );
      }

      AppLogger.d('GET /profile', tag: _tag);
      final response = await _apiBaseService.get<Map<String, dynamic>>(
        path: '/profile',
      );

      final data = response.data['data'] as Map<String, dynamic>;
      return ProfileModel.fromJson(data);
    } on ApiFailure {
      rethrow;
    } catch (error) {
      AppLogger.e('Failed to parse /profile response', tag: _tag, error: error);
      throw ApiFailure.fromParsingError(error, path: 'profile');
    }
  }

  @override
  Future<void> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      if (_config.usesMockData) {
        AppLogger.d('Using mock data for POST /auth/register', tag: _tag);
        await Future<void>.delayed(const Duration(milliseconds: 800));
        return;
      }

      AppLogger.d('POST auth/register — $email', tag: _tag);
      await _apiBaseService.post<dynamic>(
        path: '/auth/register',
        data: {'username': username, 'email': email, 'password': password},
      );
    } on ApiFailure {
      rethrow;
    } catch (error) {
      AppLogger.e('Failed auth/register', tag: _tag, error: error);
      throw ApiFailure.unknown(error);
    }
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    try {
      if (_config.usesMockData) {
        AppLogger.d(
          'Using mock data for POST /auth/forgot-password',
          tag: _tag,
        );
        await Future<void>.delayed(const Duration(milliseconds: 800));
        return;
      }

      AppLogger.d('POST auth/password-reset — $email', tag: _tag);
      await _apiBaseService.post<dynamic>(
        path: '/auth/password-reset',
        data: {'email': email},
      );
    } on ApiFailure {
      rethrow;
    } catch (error) {
      AppLogger.e('Failed auth/password-reset', tag: _tag, error: error);
      throw ApiFailure.unknown(error);
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      if (_config.usesMockData) {
        AppLogger.d(
          'Using mock data for POST /auth/password-reset/verify',
          tag: _tag,
        );
        await Future<void>.delayed(const Duration(milliseconds: 800));
        return;
      }

      AppLogger.d('POST /auth/password-reset/verify', tag: _tag);
      await _apiBaseService.post<dynamic>(
        path: '/auth/password-reset/verify',
        data: {'token': token, 'new_password': newPassword},
      );
    } on ApiFailure {
      rethrow;
    } catch (error) {
      AppLogger.e(
        'Failed /auth/password-reset/verify',
        tag: _tag,
        error: error,
      );
      throw ApiFailure.unknown(error);
    }
  }

  @override
  Future<void> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      if (_config.usesMockData) {
        AppLogger.d('Using mock data for PUT /auth/change-password', tag: _tag);
        await Future<void>.delayed(const Duration(milliseconds: 800));
        return;
      }

      AppLogger.d('PUT /auth/change-password', tag: _tag);
      await _apiBaseService.put<dynamic>(
        path: '/auth/change-password',
        data: {'old_password': oldPassword, 'new_password': newPassword},
      );
    } on ApiFailure {
      rethrow;
    } catch (error) {
      AppLogger.e('Failed /auth/change-password', tag: _tag, error: error);
      throw ApiFailure.unknown(error);
    }
  }

  @override
  Future<void> sendMagicLink({required String email}) async {
    try {
      if (_config.usesMockData) {
        AppLogger.d('Using mock data for POST /auth/magick-link', tag: _tag);
        return;
      }

      AppLogger.d('POST /auth/magick-link — $email', tag: _tag);
      await _apiBaseService.post<Map<String, dynamic>>(
        path: '/auth/magick-link',
        data: {'email': email},
      );
    } on ApiFailure {
      rethrow;
    } catch (error) {
      AppLogger.e('Failed to request magic link', tag: _tag, error: error);
      throw ApiFailure.fromParsingError(error, path: '/auth/magick-link');
    }
  }

  @override
  Future<LoginResponseModel> verifyMagicLink({required String token}) async {
    try {
      if (_config.usesMockData) {
        AppLogger.d(
          'Using mock data for POST /auth/magick-link/verify',
          tag: _tag,
        );
        return LoginResponseModel.fromJson(
          LoginResponseModel.mockLoginResponse,
        );
      }

      AppLogger.d('POST /auth/magick-link/verify', tag: _tag);
      final response = await _apiBaseService.post<Map<String, dynamic>>(
        path: '/auth/magick-link/verify',
        data: {'token': token},
      );

      final payload = response.data['data'] as Map<String, dynamic>;
      return LoginResponseModel.fromJson(payload);
    } on ApiFailure {
      rethrow;
    } catch (error) {
      AppLogger.e('Failed to verify magic link', tag: _tag, error: error);
      throw ApiFailure.fromParsingError(
        error,
        path: '/auth/magick-link/verify',
      );
    }
  }

  @override
  Future<LoginResponseModel> signInWithGoogle({
    required String grantCode,
    String? redirectUri,
  }) async {
    try {
      if (_config.usesMockData) {
        AppLogger.d('Using mock data for POST /auth/google', tag: _tag);
        return LoginResponseModel.fromJson(
          LoginResponseModel.mockLoginResponse,
        );
      }

      AppLogger.d('POST /auth/google', tag: _tag);
      final data = <String, dynamic>{'grant_code': grantCode};
      if (redirectUri != null) {
        data['redirect_uri'] = redirectUri;
      }

      final response = await _apiBaseService.post<Map<String, dynamic>>(
        path: '/auth/google',
        data: data,
      );

      final payload = response.data['data'] as Map<String, dynamic>;
      return LoginResponseModel.fromJson(payload);
    } on ApiFailure {
      rethrow;
    } catch (error) {
      AppLogger.e(
        'Failed to parse /auth/google response',
        tag: _tag,
        error: error,
      );
      throw ApiFailure.fromParsingError(error, path: '/auth/google');
    }
  }

  @override
  Future<void> changeStatus({
    required String icon,
    required String text,
    required bool pauseNotifications,
    required String statusTimeout,
    required bool clearStatus,
    required bool online,
  }) async {
    try {
      if (_config.usesMockData) {
        AppLogger.d(
          'Using mock data for POST /profile/change-status',
          tag: _tag,
        );
        await Future<void>.delayed(const Duration(milliseconds: 400));
        return;
      }

      AppLogger.d('POST /profile/change-status', tag: _tag);
      await _apiBaseService.post<dynamic>(
        path: 'profile/change-status',
        data: {
          'icon': icon,
          'text': text,
          'pause_notification': pauseNotifications,
          'status_timeout': statusTimeout,
          'clear_status': clearStatus,
          'online': online,
        },
      );
    } on ApiFailure {
      rethrow;
    } catch (error) {
      AppLogger.e('Failed /profile/change-status', tag: _tag, error: error);
      throw ApiFailure.unknown(error);
    }
  }
}
