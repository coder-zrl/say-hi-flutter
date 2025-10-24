import 'package:json_annotation/json_annotation.dart';

part 'websocket_model.g.dart';

/// 客户端信息
@JsonSerializable()
class RequestClientInfo {
  @JsonKey(name: 'userId')
  final String userId;

  @JsonKey(name: 'appVersion')
  final String appVersion;

  const RequestClientInfo({
    required this.userId,
    required this.appVersion,
  });

  factory RequestClientInfo.fromJson(Map<String, dynamic> json) =>
      _$RequestClientInfoFromJson(json);

  Map<String, dynamic> toJson() => _$RequestClientInfoToJson(this);
}

/// WebSocket 长连接消息体
@JsonSerializable()
class LongLinkBody {
  /// 请求的客户端信息
  @JsonKey(name: 'requestClientInfo')
  final RequestClientInfo? requestClientInfo;

  /// 长连信令
  @JsonKey(name: 'command')
  final String command;

  /// 长连的业务数据
  @JsonKey(name: 'data')
  final String data;

  const LongLinkBody({
    this.requestClientInfo,
    required this.command,
    required this.data,
  });

  factory LongLinkBody.fromJson(Map<String, dynamic> json) =>
      _$LongLinkBodyFromJson(json);

  Map<String, dynamic> toJson() => _$LongLinkBodyToJson(this);

  /// 创建连接消息
  factory LongLinkBody.connect({
    required String userId,
    required String appVersion,
  }) {
    return LongLinkBody(
      requestClientInfo: RequestClientInfo(
        userId: userId,
        appVersion: appVersion,
      ),
      command: 'connect',
      data: '',
    );
  }

  /// 创建心跳消息
  factory LongLinkBody.heartbeat() {
    return const LongLinkBody(
      command: 'heartbeat',
      data: '',
    );
  }

  /// 创建普通消息
  factory LongLinkBody.message({
    required String command,
    required String data,
  }) {
    return LongLinkBody(
      command: command,
      data: data,
    );
  }

  @override
  String toString() {
    return 'LongLinkBody{requestClientInfo: $requestClientInfo, command: $command, data: $data}';
  }
}

/// WebSocket 连接状态
enum WebSocketStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// WebSocket 消息类型
enum WebSocketMessageType {
  text,
  binary,
  ping,
  pong,
  close,
}

/// WebSocket 响应包装器
class WebSocketResponse<T> {
  final bool success;
  final T? data;
  final String error;
  final String command;

  const WebSocketResponse({
    required this.success,
    this.data,
    required this.error,
    required this.command,
  });

  factory WebSocketResponse.success({
    required T data,
    required String command,
  }) {
    return WebSocketResponse<T>(
      success: true,
      data: data,
      error: '',
      command: command,
    );
  }

  factory WebSocketResponse.error({
    required String error,
    required String command,
  }) {
    return WebSocketResponse<T>(
      success: false,
      data: null,
      error: error,
      command: command,
    );
  }
}