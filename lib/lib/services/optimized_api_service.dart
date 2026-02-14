import 'package:dio/dio.dart';

class OptimizedApiService {
  static final _dio = Dio(
    BaseOptions(
      baseUrl: 'http://127.0.0.1:8000',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
    ),
  );

  static Dio get dio => _dio;

  static Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    final response = await dio.get(path, queryParameters: queryParameters);
    return response.data;
  }

  static Future<dynamic> post(String path, dynamic data) async {
    final response = await dio.post(path, data: data);
    return response.data;
  }

  static Future<dynamic> put(String path, dynamic data) async {
    final response = await dio.put(path, data: data);
    return response.data;
  }

  static Future<dynamic> delete(String path) async {
    final response = await dio.delete(path);
    return response.data;
  }
}
