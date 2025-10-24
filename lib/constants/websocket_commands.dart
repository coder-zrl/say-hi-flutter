/// WebSocket Command 常量定义
class WebSocketCommands {
  // 心跳相关
  static const String heartbeat = 'heartbeat';
  static const String heartbeatResponse = 'heartbeat_response';

  // 消息相关
  static const String sendMessage = 'send_message';
  static const String receiveMessage = 'receive_message';
  static const String messageRead = 'message_read';
  static const String messageReadResponse = 'message_read_response';

  // 会话相关
  static const String createChat = 'create_chat';
  static const String deleteChat = 'delete_chat';
  static const String updateChat = 'update_chat';
  static const String chatListUpdate = 'chat_list_update';

  // 用户状态相关
  static const String userOnline = 'user_online';
  static const String userOffline = 'user_offline';
  static const String userStatusUpdate = 'user_status_update';

  // 会话操作相关
  static const String pinChat = 'pin_chat';
  static const String unpinChat = 'unpin_chat';
  static const String muteChat = 'mute_chat';
  static const String unmuteChat = 'unmute_chat';

  // 连接相关
  static const String connect = 'connect';
  static const String connectResponse = 'connect_response';
  static const String disconnect = 'disconnect';
  static const String reconnect = 'reconnect';

  // 错误相关
  static const String error = 'error';
  static const String errorMessage = 'error_message';

  // 同步相关
  static const String syncRequest = 'sync_request';
  static const String syncResponse = 'sync_response';

  // 通知相关
  static const String notification = 'notification';
  static const String notificationRead = 'notification_read';

  // typing状态相关
  static const String typingStart = 'typing_start';
  static const String typingStop = 'typing_stop';
}