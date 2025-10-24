class ApiPaths {
  // 基础配置
  static const String baseUrl = 'http://localhost:10086'; // 替换为实际的服务器地址
  static const String wsBaseUrl = 'ws://localhost:10086';   // WebSocket基础地址

  // WebSocket URL
  static const String websocketUrl = '$wsBaseUrl/websocket';

  // 用户相关接口
  static const String userLogin = '/user/login';

  // 聊天相关接口
  static const String chatList = '/chat/list';

  // 可以在这里添加更多API路径
  // static const String userRegister = '/user/register';
  // static const String userLogout = '/user/logout';
  // static const String getUserInfo = '/user/info';
}