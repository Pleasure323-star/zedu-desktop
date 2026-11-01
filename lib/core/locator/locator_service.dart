import 'package:zedu/core/core.dart';

final locator = GetIt.instance;

void setupLocator() {
  locator
    ..registerLazySingleton<AppConfig>(AppConfig.fromEnvironment)
    ..registerLazySingleton<SecureStorageService>(() => SecureStorageService());

  final config = locator<AppConfig>();
  final storage = locator<SecureStorageService>();

  final authInterceptor = AuthInterceptor(storage: storage);
  locator.registerLazySingleton<AuthInterceptor>(() => authInterceptor);

  final baseUrl = config.apiBaseUrl.endsWith('/')
      ? config.apiBaseUrl
      : '${config.apiBaseUrl}/';
  final dio = Dio(ApiBaseService.createOptions(baseUrl));
  dio.interceptors.add(authInterceptor);

  locator.registerLazySingleton<ApiBaseService>(
    () => ApiBaseService(config: config, dio: dio),
  );
}
