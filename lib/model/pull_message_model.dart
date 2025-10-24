import 'message_model.dart';

// 拉取历史消息请求模型
class PullMessageRequest {
  final int chatId;
  final int? cursor;
  final int? limit;

  PullMessageRequest({
    required this.chatId,
    this.cursor,
    this.limit = 20, // 默认拉取20条
  });

  Map<String, dynamic> toQuery() {
    final Map<String, dynamic> query = {
      'chatId': chatId.toString(),
    };

    if (cursor != null) {
      query['cursor'] = cursor.toString();
    }

    if (limit != null) {
      query['limit'] = limit.toString();
    }

    return query;
  }
}

// 拉取历史消息响应模型
class PullMessageResponse {
  final List<Message> messages;
  final int? nextCursor;
  final bool hasMore;

  PullMessageResponse({
    required this.messages,
    this.nextCursor,
    required this.hasMore,
  });

  factory PullMessageResponse.fromJson(Map<String, dynamic> json) {
    try {
      final data = json['data'] as Map<String, dynamic>? ?? {};
      final messagesList = data['messages'] as List<dynamic>? ?? [];

      final messages = messagesList.map((messageJson) {
        // 转换 messageType 字符串为枚举
        final messageTypeStr = messageJson['messageType'] as String? ?? 'TEXT';
        MessageType messageType;
        switch (messageTypeStr.toUpperCase()) {
          case 'IMAGE':
            messageType = MessageType.image;
            break;
          case 'VIDEO':
            messageType = MessageType.video;
            break;
          case 'RED_PACKET':
            messageType = MessageType.redPacket;
            break;
          case 'TEXT':
          default:
            messageType = MessageType.text;
            break;
        }

        return Message(
          messageId: messageJson['messageId'] as int? ?? 0,
          channelId: messageJson['channelId'] as int? ?? 0,
          seqId: messageJson['seqId'] as int? ?? 0,
          fromUserId: messageJson['fromUserId'] as int? ?? 0,
          messageType: messageType,
          content: messageJson['content'] as String? ?? '',
          showText: messageJson['showText'] as String? ?? '',
          expireTime: messageJson['expireTime'] as int? ?? 0,
          createTime: messageJson['createTime'] as int? ?? 0,
          updateTime: messageJson['updateTime'] as int? ?? 0,
          deleteTime: messageJson['deleteTime'] as int? ?? 0,
        );
      }).toList();

      return PullMessageResponse(
        messages: messages,
        nextCursor: data['nextCursor'] as int?,
        hasMore: data['hasMore'] as bool? ?? false,
      );
    } catch (e) {
      print('PullMessageResponse.fromJson 错误: $e');
      print('输入数据: $json');
      rethrow;
    }
  }
}

// 历史消息拉取结果
class HistoryMessageResult {
  final bool success;
  final String? error;
  final PullMessageResponse? data;

  HistoryMessageResult({
    required this.success,
    this.error,
    this.data,
  });

  factory HistoryMessageResult.success(PullMessageResponse data) {
    return HistoryMessageResult(
      success: true,
      data: data,
    );
  }

  factory HistoryMessageResult.error(String error) {
    return HistoryMessageResult(
      success: false,
      error: error,
    );
  }
}