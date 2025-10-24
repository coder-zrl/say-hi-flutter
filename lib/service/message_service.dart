import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:say_hi_flutter/config/api_paths.dart';
import 'package:say_hi_flutter/model/pull_message_model.dart';
import 'package:say_hi_flutter/model/message_model.dart';
import 'package:say_hi_flutter/service/storage_service.dart';
import 'package:say_hi_flutter/service/http_service.dart';

/// 消息服务类
class MessageService {
  static final MessageService _instance = MessageService._internal();
  factory MessageService() => _instance;
  MessageService._internal();

  final HttpService _httpService = HttpService();

  /// 拉取历史消息
  Future<HistoryMessageResult> pullHistoryMessages({
    required int chatId,
    int? cursor,
    int limit = 20,
  }) async {
    try {
      final request = PullMessageRequest(
        chatId: chatId,
        cursor: cursor,
        limit: limit,
      );

      print('📤 开始拉取历史消息: /message/pullHistoryMessage');
      print('📤 请求参数: ${request.toQuery()}');

      final response = await _httpService.get(
        '/message/pullHistoryMessage',
        queryParameters: request.toQuery(),
      );

      print('📥 收到响应: 状态码 ${response.statusCode}');
      print('📥 响应数据: ${response.data}');

      if (response.statusCode == 200) {
        final pullResponse = PullMessageResponse.fromJson(response.data);

        // 按seqId升序排列
        final sortedMessages = List<Message>.from(pullResponse.messages);
        sortedMessages.sort((a, b) => a.seqId.compareTo(b.seqId));

        final sortedResponse = PullMessageResponse(
          messages: sortedMessages,
          nextCursor: pullResponse.nextCursor,
          hasMore: pullResponse.hasMore,
        );

        print('✅ 历史消息拉取成功: ${sortedMessages.length}条消息');
        return HistoryMessageResult.success(sortedResponse);
      } else {
        final error = '拉取历史消息失败: HTTP ${response.statusCode}';
        print('❌ $error');
        return HistoryMessageResult.error(error);
      }
    } catch (e) {
      String error = '拉取历史消息异常: $e';
      if (e is DioException) {
        error = '拉取历史消息失败: ${e.message}';
      }
      print('❌ $error');
      return HistoryMessageResult.error(error);
    }
  }

  /// 拉取完整历史消息（直到拉完为止）
  Future<List<Message>> pullAllHistoryMessages({
    required int chatId,
    int limit = 20,
    Function(int loadedCount, bool isLoading)? onProgress,
  }) async {
    final List<Message> allMessages = [];
    int? cursor;
    int totalCount = 0;

    print('🔄 开始拉取完整历史消息，chatId: $chatId');

    bool hasMore = true;

    while (hasMore && cursor != null) {
      if (onProgress != null) {
        onProgress(totalCount, true);
      }

      final result = await pullHistoryMessages(
        chatId: chatId,
        cursor: cursor,
        limit: limit,
      );

      if (!result.success || result.data == null) {
        print('❌ 拉取历史消息失败: ${result.error}');
        break;
      }

      final pullResponse = result.data!;
      allMessages.addAll(pullResponse.messages);
      totalCount += pullResponse.messages.length;
      cursor = pullResponse.nextCursor;
      hasMore = pullResponse.hasMore;

      print('📊 已拉取 ${pullResponse.messages.length} 条消息，总计 $totalCount 条');
      print('📊 还有更多: ${pullResponse.hasMore}, 下一游标: $cursor');
    }

    // 按seqId升序排列所有消息
    allMessages.sort((a, b) => a.seqId.compareTo(b.seqId));

    print('✅ 历史消息拉取完成，总计 ${allMessages.length} 条消息');

    if (onProgress != null) {
      onProgress(totalCount, false);
    }

    return allMessages;
  }

  /// 保存消息到本地存储
  Future<void> saveMessagesToLocal(List<Message> messages) async {
    try {
      for (final message in messages) {
        await StorageService.saveMessage(message);
      }
      print('✅ 已保存 ${messages.length} 条消息到本地存储');
    } catch (e) {
      print('❌ 保存消息到本地存储失败: $e');
    }
  }

  /// 从本地存储获取消息
  Future<List<Message>> getMessagesFromLocal({
    required int channelId,
    int limit = 50,
    int? beforeSeqId,
  }) async {
    try {
      final messages = await StorageService.getMessagesByChannelId(
        channelId,
        limit: limit,
      );

      // 按seqId升序排列
      messages.sort((a, b) => a.seqId.compareTo(b.seqId));

      print('📚 从本地存储获取 ${messages.length} 条消息');
      return messages;
    } catch (e) {
      print('❌ 从本地存储获取消息失败: $e');
      return [];
    }
  }

  /// 合并服务器消息和本地消息（去重）
  List<Message> mergeMessages({
    required List<Message> serverMessages,
    required List<Message> localMessages,
  }) {
    final Map<int, Message> messageMap = {};

    // 先添加本地消息
    for (final message in localMessages) {
      messageMap[message.messageId] = message;
    }

    // 服务器消息覆盖本地消息（因为服务器数据更新）
    for (final message in serverMessages) {
      messageMap[message.messageId] = message;
    }

    final mergedMessages = messageMap.values.toList();
    mergedMessages.sort((a, b) => a.seqId.compareTo(b.seqId));

    print('🔗 合并消息完成: 本地${localMessages.length}条 + 服务器${serverMessages.length}条 = 合并后${mergedMessages.length}条');

    return mergedMessages;
  }
}