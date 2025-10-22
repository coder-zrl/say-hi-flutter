import 'package:dio/dio.dart';
import '../config/api_paths.dart';
import '../model/login_model.dart';
import '../service/http_service.dart';
import '../service/storage_service.dart';
import '../service/response_handler.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final HttpService _httpService = HttpService();

  Future<bool> login(String username, String password) async {
    try {
      final loginRequest = LoginRequest(
        username: username,
        password: password,
      );

      final response = await _httpService.post<Map<String, dynamic>>(
        ApiPaths.userLogin,
        data: loginRequest.toJson(),
      );

      if (response.statusCode == 200 && response.data != null) {
        final apiResponse = ApiResponse<LoginData>.fromJson(
          response.data!,
          (data) => LoginData.fromJson(data),
        );

        // 使用统一响应处理器处理结果
        final isSuccess = await ResponseHandler.handleResponse(
          apiResponse,
          successMessage: '登录成功',
        );

        // 如果登录成功，保存token
        if (isSuccess && apiResponse.data != null) {
          await StorageService.saveToken(
            apiResponse.data!.tokenName,
            apiResponse.data!.tokenValue,
          );
        }

        return isSuccess;
      } else {
        await ResponseHandler.handleErrorResponse(0, '服务器响应异常');
        return false;
      }
    } on DioException catch (e) {
      await ResponseHandler.handleErrorResponse(0, '网络请求失败: ${e.message}');
      return false;
    } catch (e) {
      await ResponseHandler.handleErrorResponse(0, '登录失败: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      // 清除本地存储的token
      await StorageService.clearToken();

      // 这里可以调用服务器端的登出接口
      // await _httpService.post(ApiPaths.userLogout);
    } catch (e) {
      throw Exception('登出失败: $e');
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      final token = await StorageService.getToken();
      return token != null && token['tokenValue']!.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, String>?> getCurrentToken() async {
    return await StorageService.getToken();
  }
}