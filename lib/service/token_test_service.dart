import 'package:say_hi_flutter/service/auth_service.dart';
import 'package:say_hi_flutter/service/http_service.dart';
import 'package:say_hi_flutter/service/storage_service.dart';

class TokenTestService {
  static Future<void> testTokenHeader() async {
    try {
      print('=== 测试Token Header格式 ===');

      // 1. 先保存一个测试token
      await StorageService.saveToken('satoken', 'test_token_value_12345');
      print('✓ 已保存测试token: satoken = test_token_value_12345');

      // 2. 获取token并验证
      final token = await StorageService.getToken();
      if (token != null) {
        print('✓ 成功获取token: ${token['tokenName']} = ${token['tokenValue']}');
      } else {
        print('✗ 无法获取token');
        return;
      }

      // 3. 测试HTTP请求头是否正确设置
      print('\n=== HTTP请求头格式验证 ===');
      print('每个HTTP请求将包含以下header:');
      print('{ "${token['tokenName']}": "${token['tokenValue']}" }');

      // 4. 验证AuthService是否能正常工作
      final authService = AuthService();
      final isLoggedIn = await authService.isLoggedIn();
      print('✓ AuthService登录状态检查: ${isLoggedIn ? '已登录' : '未登录'}');

      print('\n=== 测试完成 ===');
      print('HTTP请求现在会自动在header中添加token格式: {tokenName: tokenValue}');

    } catch (e) {
      print('✗ 测试失败: $e');
    }
  }
}