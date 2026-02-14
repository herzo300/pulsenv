import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

class CachedApiService {
  static final _dio = Dio(BaseOptions(
    baseUrl: 'http://127.0.0.1:8000',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static final _cacheOptions = CacheOptions(
    store: MemCacheStore(),
    policy: CachePolicy.forceCache,
    maxStale: const Duration(hours: 1),
    hitCacheOnErrorExcept: [401, 403],
  );

  static Dio get dio {
    if (!_dio.interceptors.any((i) => i is DioCacheInterceptor)) {
      _dio.interceptors.add(DioCacheInterceptor(options: _cacheOptions));
    }
    return _dio;
  }

  static Future<dynamic> get(String path) async {
    final response = await dio.get(path);
    return response.data;
  }

  static Future<dynamic> post(String path, dynamic data) async {
    final response = await dio.post(path, data: data);
    return response.data;
  }
}
