import 'package:say_hi_flutter/model/chat_info_model.dart';

class ChatResponse {
  final int code;
  final String message;
  final List<ChatInfo> chatInfos;
  final bool hasMore;
  final bool success;

  ChatResponse({
    required this.code,
    required this.message,
    required this.chatInfos,
    required this.hasMore,
    required this.success,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    try {
      print('📥 ChatResponse.fromJson - 输入数据: $json');

      final code = json['code'] as int?;
      final message = json['message'] as String? ?? '';
      final success = json['success'] as bool? ?? false;

      List<ChatInfo> chatList = [];
      bool hasMore = false;

      if (json['data'] != null) {
        final data = json['data'] as Map<String, dynamic>?;
        if (data != null) {
          // 解析 chatInfos 数组
          if (data['chatInfos'] != null && data['chatInfos'] is List) {
            chatList = (data['chatInfos'] as List<dynamic>)
                .map((item) => ChatInfo.fromJson(item as Map<String, dynamic>))
                .toList();
          } else {
            print('⚠️ ChatResponse - chatInfos字段不是List类型: ${data['chatInfos']?.runtimeType}');
          }

          // 解析 hasMore 字段
          hasMore = data['hasMore'] as bool? ?? false;
        }
      } else {
        // 兼容旧格式：data 直接是数组
        if (json['data'] is List) {
          chatList = (json['data'] as List<dynamic>)
              .map((item) => ChatInfo.fromJson(item as Map<String, dynamic>))
              .toList();
          print('⚠️ ChatResponse - 使用旧版data格式');
        } else {
          print('⚠️ ChatResponse - data字段格式不支持: ${json['data'].runtimeType}');
        }
      }

      print('📥 ChatResponse - 解析结果: code=$code, message=$message, success=$success, dataCount=${chatList.length}, hasMore=$hasMore');

      return ChatResponse(
        code: code ?? 0,
        message: message,
        chatInfos: chatList,
        hasMore: hasMore,
        success: success,
      );
    } catch (e) {
      print('❌ ChatResponse.fromJson 错误: $e');
      print('❌ 输入数据: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      'data': {
        'chatInfos': chatInfos.map((chatInfo) => chatInfo.toJson()).toList(),
        'hasMore': hasMore,
      },
      'success': success,
    };
  }

  @override
  String toString() {
    return 'ChatResponse(code: $code, message: $message, chatInfos: $chatInfos, hasMore: $hasMore, success: $success)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatResponse &&
        other.code == code &&
        other.message == message &&
        other.chatInfos == chatInfos &&
        other.hasMore == hasMore &&
        other.success == success;
  }

  @override
  int get hashCode {
    return Object.hash(code, message, chatInfos, hasMore, success);
  }

  // 向后兼容性的 getter
  List<ChatInfo> get data => chatInfos;
}