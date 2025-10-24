import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:say_hi_flutter/config/api_paths.dart';
import 'package:say_hi_flutter/model/chat_response_model.dart';
import 'package:say_hi_flutter/model/chat_info_model.dart';
import 'package:say_hi_flutter/service/http_service.dart';

class ChatService {
  final HttpService _httpService = HttpService();

  /// 获取会话列表
  /// [timestamp] 时间戳，表示会话活跃时间水位线
  /// [limit] 返回数量限制
  Future<ChatResponse> getChatList({
    int? timestamp,
    int? limit,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {};

      if (timestamp != null) {
        // 确保timestamp是整数，并转换为字符串格式（有些API期望字符串）
        queryParams['timestamp'] = timestamp.toInt();
      }

      if (limit != null) {
        queryParams['limit'] = limit.toInt();
      }

      print('📤 开始请求会话列表: ${ApiPaths.chatList}');
      print('📤 查询参数: $queryParams');

      final response = await _httpService.get<dynamic>(
        ApiPaths.chatList,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      print('📥 收到响应: 状态码 ${response.statusCode}');
      print('📥 响应数据类型: ${response.data.runtimeType}');
      print('📥 响应数据: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        Map<String, dynamic> responseData;

        if (response.data is String) {
          responseData = jsonDecode(response.data) as Map<String, dynamic>;
        } else if (response.data is Map<String, dynamic>) {
          responseData = response.data as Map<String, dynamic>;
        } else {
          throw Exception('响应数据格式错误: 期望Map或String，实际${response.data.runtimeType}');
        }

        print('📥 解析后的数据: $responseData');

        final chatResponse = ChatResponse.fromJson(responseData);
        print('📥 成功解析ChatResponse: 数据条数 ${chatResponse.chatInfos.length}, hasMore: ${chatResponse.hasMore}');

        return chatResponse;
      } else {
        throw Exception('获取会话列表失败: 状态码 ${response.statusCode}');
      }
    } catch (e) {
      print('❌ ChatService错误: $e');
      print('❌ 错误类型: ${e.runtimeType}');

      // 如果是DioException，打印更详细的信息
      if (e is DioException) {
        print('❌ DioException详情:');
        print('  请求URL: ${e.requestOptions.uri}');
        print('  请求方法: ${e.requestOptions.method}');
        print('  请求头: ${e.requestOptions.headers}');
        print('  查询参数: ${e.requestOptions.queryParameters}');
        print('  响应状态码: ${e.response?.statusCode}');
        print('  响应数据: ${e.response?.data}');
      }

      throw Exception('获取会话列表时发生错误: $e');
    }
  }

  /// 删除会话
  /// [chatId] 会话ID
  Future<bool> deleteChat(int chatId) async {
    try {
      print('🗑️ 开始删除会话: $chatId');

      final response = await _httpService.delete<dynamic>(
        '${ApiPaths.chatList}/${chatId.toString()}',
      );

      print('📥 删除会话响应: 状态码 ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ 会话删除成功: $chatId');
        return true;
      } else {
        print('❌ 删除会话失败: 状态码 ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ 删除会话异常: $e');
      return false;
    }
  }

  /// 切换置顶状态
  /// [chatId] 会话ID
  /// [stickyTop] 是否置顶
  Future<bool> togglePin(int chatId, bool stickyTop) async {
    try {
      print('📌 开始切换置顶状态: $chatId, stickyTop: $stickyTop');

      final response = await _httpService.put<dynamic>(
        '${ApiPaths.chatList}/${chatId.toString()}/pin',
        data: {
          'stickyTop': stickyTop,
        },
      );

      print('📥 切换置顶响应: 状态码 ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ 置顶状态切换成功: $chatId, newStickyTop: $stickyTop');
        return true;
      } else {
        print('❌ 置顶状态切换失败: 状态码 ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ 切换置顶状态异常: $e');
      return false;
    }
  }

  /// 切换免打扰状态
  /// [chatId] 会话ID
  /// [doNotDisturb] 是否免打扰
  Future<bool> toggleMute(int chatId, bool doNotDisturb) async {
    try {
      print('🔕 开始切换免打扰状态: $chatId, doNotDisturb: $doNotDisturb');

      final response = await _httpService.put<dynamic>(
        '${ApiPaths.chatList}/${chatId.toString()}/mute',
        data: {
          'doNotDisturb': doNotDisturb,
        },
      );

      print('📥 切换免打扰响应: 状态码 ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ 免打扰状态切换成功: $chatId, newDoNotDisturb: $doNotDisturb');
        return true;
      } else {
        print('❌ 免打扰状态切换失败: 状态码 ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ 切换免打扰状态异常: $e');
      return false;
    }
  }
}