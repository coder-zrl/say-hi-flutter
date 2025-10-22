import 'package:dio/dio.dart';
import '../config/http_config.dart';
import '../service/storage_service.dart';

class HttpService {
  static final HttpService _instance = HttpService._internal();
  factory HttpService() => _instance;
  HttpService._internal();

  late Dio _dio;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: HttpConfig.baseUrl,
      connectTimeout: HttpConfig.connectTimeout,
      receiveTimeout: HttpConfig.receiveTimeout,
      sendTimeout: HttpConfig.sendTimeout,
      headers: HttpConfig.headers,
    ));

    // 添加拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 添加认证头
        final token = await StorageService.getToken();
        if (token != null &&
            token['tokenName'] != null &&
            token['tokenValue'] != null &&
            token['tokenName']!.isNotEmpty &&
            token['tokenValue']!.isNotEmpty) {
          // 按照要求的格式添加token到header
          options.headers[token['tokenName']!] = token['tokenValue']!;
          print('🔐 添加Token到请求头: ${token['tokenName']} = ${token['tokenValue']}');
        }

        print('📤 请求详情:');
        print('  URL: ${options.uri}');
        print('  方法: ${options.method}');
        print('  Headers: ${options.headers}');
        if (options.data != null) {
          print('  数据: ${options.data}');
        }

        handler.next(options);
      },
      onResponse: (response, handler) {
        print('📥 响应详情:');
        print('  状态码: ${response.statusCode}');
        print('  数据: ${response.data}');
        handler.next(response);
      },
      onError: (error, handler) async {
        // 处理错误
        print('❌ 请求错误:');
        print('  类型: ${error.type}');
        print('  消息: ${error.message}');
        if (error.response != null) {
          print('  状态码: ${error.response?.statusCode}');
          print('  响应数据: ${error.response?.data}');
        }
        _handleError(error);
        handler.next(error);
      },
    ));
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  void _handleError(DioException error) {
    String message = '';
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = '网络超时，请检查网络连接';
        break;
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode != null) {
          switch (statusCode) {
            case 400:
              message = '请求参数错误';
              break;
            case 401:
              message = '未授权，请重新登录';
              break;
            case 403:
              message = '拒绝访问';
              break;
            case 404:
              message = '请求的资源不存在';
              break;
            case 500:
              message = '服务器内部错误';
              break;
            default:
              message = '网络请求失败: $statusCode';
          }
        } else {
          message = '网络请求失败';
        }
        break;
      case DioExceptionType.cancel:
        message = '请求已取消';
        break;
      case DioExceptionType.unknown:
        message = '网络连接异常，请检查网络设置';
        break;
      default:
        message = '未知错误';
    }

    // 可以在这里添加错误日志记录
    print('HTTP Error: $message');
  }

  Dio get dio => _dio;
}