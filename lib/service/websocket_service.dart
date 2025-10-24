import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:say_hi_flutter/constants/websocket_commands.dart';
import 'package:say_hi_flutter/model/websocket_model.dart';
import 'package:say_hi_flutter/config/api_paths.dart';
import 'package:say_hi_flutter/service/storage_service.dart';

/// WebSocket 回调接口
abstract class WebSocketListener {
  void onConnected();
  void onDisconnected();
  void onError(String error);
  void onMessage(LongLinkBody message);
  void onReconnecting();
  void onReconnected();
}

/// WebSocket 服务类
class WebSocketService {
  static WebSocketService? _instance;
  static WebSocketService get instance {
    _instance ??= WebSocketService._();
    return _instance!;
  }

  WebSocketService._();

  WebSocketChannel? _channel;
  WebSocketStatus _status = WebSocketStatus.disconnected;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  final List<WebSocketListener> _listeners = [];

  String? _userId;
  String _appVersion = '1.0.0';
  final String _wsUrl = ApiPaths.websocketUrl; // 使用配置的WebSocket完整地址

  // 重连相关
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _reconnectDelay = Duration(seconds: 3);

  /// 连接状态
  WebSocketStatus get status => _status;

  /// 是否已连接
  bool get isConnected => _status == WebSocketStatus.connected;

  /// 添加监听器
  void addListener(WebSocketListener listener) {
    _listeners.add(listener);
  }

  /// 移除监听器
  void removeListener(WebSocketListener listener) {
    _listeners.remove(listener);
  }

  /// 清除所有监听器
  void clearListeners() {
    _listeners.clear();
  }

  /// 初始化WebSocket连接
  Future<void> connect({String? userId}) async {
    if (isConnected) {
      developer.log('WebSocket已连接，无需重复连接', name: 'WebSocket');
      return;
    }

    // 首先检查是否有token
    final token = await StorageService.getToken();
    if (token == null || token['tokenValue']?.isEmpty == true) {
      developer.log('WebSocket连接失败：没有有效的token', name: 'WebSocket');
      _notifyError('连接失败：没有有效的登录凭证');
      return;
    }

    // 如果传入了userId，则更新
    if (userId != null) {
      _userId = userId;
    }

    // 如果没有userId，尝试从本地获取
    if (_userId == null || _userId!.isEmpty) {
      _userId = await _getUserIdFromStorage();
      if (_userId == null || _userId!.isEmpty) {
        developer.log('WebSocket连接失败：userId为空', name: 'WebSocket');
        _notifyError('连接失败：用户ID为空');
        return;
      }
    }

    // 获取应用版本
    await _getAppVersion();

    await _connect();
  }

  /// 实际连接方法
  Future<void> _connect() async {
    try {
      _setStatus(WebSocketStatus.connecting);

      final url = '$_wsUrl/$_userId';
      developer.log('正在连接WebSocket: $url', name: 'WebSocket');

      _channel = WebSocketChannel.connect(Uri.parse(url));

      // 监听消息流
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      // 等待连接建立
      await Future.delayed(const Duration(milliseconds: 500));

      // 发送连接消息
      _sendConnectMessage();

      // 启动心跳
      _startHeartbeat();

      _setStatus(WebSocketStatus.connected);
      _reconnectAttempts = 0;

      developer.log('WebSocket连接成功', name: 'WebSocket');
      _notifyConnected();

    } catch (e) {
      developer.log('WebSocket连接失败: $e', name: 'WebSocket');
      _setStatus(WebSocketStatus.error);
      _notifyError('连接失败: $e');

      // 尝试重连
      _scheduleReconnect();
    }
  }

  /// 断开连接
  void disconnect() {
    developer.log('手动断开WebSocket连接', name: 'WebSocket');
    _cleanup();
    _setStatus(WebSocketStatus.disconnected);
    _notifyDisconnected();
  }

  /// 发送消息
  Future<bool> sendMessage({
    required String command,
    required String data,
  }) async {
    if (!isConnected) {
      developer.log('WebSocket未连接，无法发送消息', name: 'WebSocket');
      return false;
    }

    try {
      final message = LongLinkBody.message(
        command: command,
        data: data,
      );

      final jsonStr = jsonEncode(message.toJson());
      _channel!.sink.add(jsonStr);

      developer.log('发送WebSocket消息: $jsonStr', name: 'WebSocket');
      return true;
    } catch (e) {
      developer.log('发送WebSocket消息失败: $e', name: 'WebSocket');
      return false;
    }
  }

  /// 发送连接消息
  void _sendConnectMessage() {
    if (_userId == null) return;

    final connectMessage = LongLinkBody.connect(
      userId: _userId!,
      appVersion: _appVersion,
    );

    final jsonStr = jsonEncode(connectMessage.toJson());
    _channel!.sink.add(jsonStr);

    developer.log('发送连接消息: $jsonStr', name: 'WebSocket');
  }

  /// 发送心跳
  void _sendHeartbeat() {
    if (!isConnected) return;

    final heartbeatMessage = LongLinkBody.heartbeat();
    final jsonStr = jsonEncode(heartbeatMessage.toJson());
    _channel!.sink.add(jsonStr);

    developer.log('发送心跳', name: 'WebSocket');
  }

  /// 启动心跳
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _sendHeartbeat();
    });
  }

  /// 停止心跳
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 计划重连
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      developer.log('达到最大重连次数，停止重连', name: 'WebSocket');
      return;
    }

    _reconnectAttempts++;
    developer.log('计划第$_reconnectAttempts次重连，${_reconnectDelay.inSeconds}秒后执行', name: 'WebSocket');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      _setStatus(WebSocketStatus.reconnecting);
      _notifyReconnecting();
      _connect();
    });
  }

  /// 处理接收到的消息
  void _onMessage(dynamic message) {
    try {
      if (message is String) {
        final Map<String, dynamic> jsonMap = jsonDecode(message);
        final longLinkBody = LongLinkBody.fromJson(jsonMap);

        developer.log('收到WebSocket消息: ${longLinkBody.toString()}', name: 'WebSocket');

        // 处理特殊消息
        if (longLinkBody.command == WebSocketCommands.heartbeatResponse) {
          developer.log('收到心跳响应', name: 'WebSocket');
          return;
        }

        _notifyMessage(longLinkBody);
      }
    } catch (e) {
      developer.log('解析WebSocket消息失败: $e', name: 'WebSocket');
    }
  }

  /// 处理错误
  void _onError(dynamic error) {
    developer.log('WebSocket错误: $error', name: 'WebSocket');
    _setStatus(WebSocketStatus.error);
    _notifyError(error.toString());

    // 计划重连
    _scheduleReconnect();
  }

  /// 处理连接关闭
  void _onDone() {
    developer.log('WebSocket连接关闭', name: 'WebSocket');

    if (_status != WebSocketStatus.disconnected) {
      _setStatus(WebSocketStatus.error);
      _notifyDisconnected();

      // 如果不是手动断开，则尝试重连
      _scheduleReconnect();
    }
  }

  /// 清理资源
  void _cleanup() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _stopHeartbeat();

    _channel?.sink.close();
    _channel = null;
  }

  /// 设置状态
  void _setStatus(WebSocketStatus status) {
    if (_status != status) {
      _status = status;
      developer.log('WebSocket状态变更: $status', name: 'WebSocket');
    }
  }

  /// 检查token状态并断开连接
  Future<void> checkTokenAndDisconnectIfNeeded() async {
    final token = await StorageService.getToken();
    if (token == null || token['tokenValue']?.isEmpty == true) {
      developer.log('token无效，主动断开WebSocket连接', name: 'WebSocket');
      disconnect();
    }
  }

  /// 从本地存储获取userId
  Future<String?> _getUserIdFromStorage() async {
    try {
      // 优先从UserInfo中获取userId
      final userInfo = await StorageService.getUserInfo();
      if (userInfo != null && userInfo.userId > 0) {
        return userInfo.userId.toString();
      }

      // 兼容旧版本，从SharedPreferences获取
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('userId') ?? prefs.getString('username');
    } catch (e) {
      developer.log('从本地存储获取userId失败: $e', name: 'WebSocket');
      return null;
    }
  }

  /// 获取应用版本
  Future<void> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
      developer.log('应用版本: $_appVersion', name: 'WebSocket');
    } catch (e) {
      developer.log('获取应用版本失败: $e', name: 'WebSocket');
      _appVersion = '1.0.0'; // 默认版本
    }
  }

  /// 通知连接成功
  void _notifyConnected() {
    for (final listener in _listeners) {
      try {
        listener.onConnected();
      } catch (e) {
        developer.log('通知连接成功失败: $e', name: 'WebSocket');
      }
    }
  }

  /// 通知连接断开
  void _notifyDisconnected() {
    for (final listener in _listeners) {
      try {
        listener.onDisconnected();
      } catch (e) {
        developer.log('通知连接断开失败: $e', name: 'WebSocket');
      }
    }
  }

  /// 通知错误
  void _notifyError(String error) {
    for (final listener in _listeners) {
      try {
        listener.onError(error);
      } catch (e) {
        developer.log('通知错误失败: $e', name: 'WebSocket');
      }
    }
  }

  /// 通知消息
  void _notifyMessage(LongLinkBody message) {
    for (final listener in _listeners) {
      try {
        listener.onMessage(message);
      } catch (e) {
        developer.log('通知消息失败: $e', name: 'WebSocket');
      }
    }
  }

  /// 通知重连中
  void _notifyReconnecting() {
    for (final listener in _listeners) {
      try {
        listener.onReconnecting();
      } catch (e) {
        developer.log('通知重连中失败: $e', name: 'WebSocket');
      }
    }
  }

  /// 通知重连成功
  void _notifyReconnected() {
    for (final listener in _listeners) {
      try {
        listener.onReconnected();
      } catch (e) {
        developer.log('通知重连成功失败: $e', name: 'WebSocket');
      }
    }
  }

  /// 销毁服务
  void dispose() {
    disconnect();
    clearListeners();
    _instance = null;
  }
}