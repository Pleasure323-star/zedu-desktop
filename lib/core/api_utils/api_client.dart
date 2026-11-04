import 'package:zedu/core/core.dart';

class ApiBaseService {
  ApiBaseService({required AppConfig config, Dio? dio})
    : _dio = dio ?? Dio(createOptions(config.apiBaseUrl));

  /// Creates consistent deadlines for connection, upload and response waits.
  /// Supplied Dio clients retain their caller-provided timeout settings.
  static BaseOptions createOptions(String baseUrl) => BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  );

  /// Trims leading slashes from [path] so that Dio's URI resolution does not
  /// treat the path as root-relative and strip the path prefix of [baseUrl].
  /// Absolute URLs (with scheme) and empty paths are preserved unchanged.
  static String normalizePath(String path) {
    if (path.isEmpty || Uri.tryParse(path)?.hasScheme == true) {
      return path;
    }
    return path.replaceFirst(RegExp(r'^/+'), '');
  }

  final Dio _dio;

  Future<ApiResponseModel<T>> get<T>({
    required String path,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) {
    return _request<T>(
      path: path,
      method: 'GET',
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<ApiResponseModel<T>> post<T>({
    required String path,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) {
    return _request<T>(
      path: path,
      method: 'POST',
      data: data,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<ApiResponseModel<T>> put<T>({
    required String path,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) {
    return _request<T>(
      path: path,
      method: 'PUT',
      data: data,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<ApiResponseModel<T>> patch<T>({
    required String path,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) {
    return _request<T>(
      path: path,
      method: 'PATCH',
      data: data,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<ApiResponseModel<T>> delete<T>({
    required String path,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) {
    return _request<T>(
      path: path,
      method: 'DELETE',
      data: data,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Map<String, String> headersForPath(
    String path, {
    Map<String, String>? headers,
  }) {
    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...?headers,
    };
  }

  Future<ApiResponseModel<T>> _request<T>({
    required String path,
    required String method,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final normalizedPath = normalizePath(path);
    final requestHeaders = headersForPath(normalizedPath, headers: headers);
    if (data is FormData) {
      // Dio computes and attaches the multipart boundary itself; a hardcoded
      // application/json Content-Type would strip it and the Go backend
      // cannot parse the multipart body.
      requestHeaders.remove('Content-Type');
    }
    try {
      final response = await _dio.request<T>(
        normalizedPath,
        data: data,
        queryParameters: queryParameters,
        options: Options(method: method, headers: requestHeaders),
      );

      final responseData = response.data;
      if (responseData is Map<String, dynamic> &&
          responseData['status'] == 'error') {
        throw ApiFailure(
          message: responseData['message'] as String? ?? 'Request failed.',
          statusCode: responseData['status_code'] as int?,
          path: path,
          kind: ApiFailureKind.client,
        );
      }

      return ApiResponseModel<T>(
        data: responseData as T,
        statusCode: response.statusCode ?? 0,
        message: response.statusMessage,
      );
    } on DioException catch (error) {
      throw ApiFailure.fromDioException(error);
    }
  }
}
