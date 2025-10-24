import 'package:flutter/material.dart';
import 'package:say_hi_flutter/model/chat_info_model.dart';
import 'package:say_hi_flutter/model/message_model.dart';
import 'package:say_hi_flutter/service/storage_service.dart';
import 'package:say_hi_flutter/service/websocket_service.dart';
import 'package:say_hi_flutter/service/message_service.dart';
import 'package:say_hi_flutter/constants/websocket_commands.dart';
import 'package:say_hi_flutter/model/websocket_model.dart';
import 'package:say_hi_flutter/model/pull_message_model.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ChatDetailPage extends StatefulWidget {
  final ChatInfo chatInfo;

  const ChatDetailPage({
    Key? key,
    required this.chatInfo,
  }) : super(key: key);

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> implements WebSocketListener {
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isLoadingHistory = false;
  bool _hasMoreHistory = true;
  int? _historyCursor;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  bool _isComposing = false;
  bool _isRecording = false;
  bool _showEmoji = false;
  final MessageService _messageService = MessageService();

  // 语音录制相关
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 图片选择相关
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initWebSocket();
    _loadHistoryMessages(); // 拉取历史消息
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollController.removeListener(_onScroll);
    _textController.dispose();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    WebSocketService.instance.removeListener(this);
    super.dispose();
  }

  // 拉取历史消息
  Future<void> _loadHistoryMessages() async {
    if (!mounted) return;

    final chatId = widget.chatInfo.chatId;
    if (chatId == 0) {
      print('❌ 无效的chatId: ${widget.chatInfo.chatId}');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    print('🔄 开始拉取历史消息，chatId: $chatId');

    // 先从本地获取消息
    final localMessages = await StorageService.getMessagesByChannelId(chatId, limit: 50);
    if (localMessages.isNotEmpty) {
      // 按seqId升序排列
      localMessages.sort((a, b) => a.seqId.compareTo(b.seqId));

      if (mounted) {
        setState(() {
          _messages = localMessages;
          _isLoading = false;
        });
      }
      print('📚 从本地加载了 ${localMessages.length} 条消息');
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    // 从服务器拉取历史消息
    await _pullHistoryMessagesFromServer(chatId);

    // 添加滚动监听器，用于上拉加载更多
    _scrollController.addListener(_onScroll);
  }

  // 从服务器拉取历史消息
  Future<void> _pullHistoryMessagesFromServer(int chatId) async {
    if (!mounted || _isLoadingHistory) return;

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      print('🌐 从服务器拉取历史消息，chatId: $chatId, cursor: $_historyCursor');

      final result = await _messageService.pullHistoryMessages(
        chatId: chatId,
        cursor: _historyCursor,
        limit: 20,
      );

      if (result.success && result.data != null) {
        final pullResponse = result.data!;
        final newMessages = pullResponse.messages;

        print('📥 服务器返回 ${newMessages.length} 条消息，hasMore: ${pullResponse.hasMore}, nextCursor: ${pullResponse.nextCursor}');

        if (mounted) {
          setState(() {
            // 合并新消息到现有消息列表（保持按seqId升序）
            final allMessages = <Message>[..._messages, ...newMessages];
            // 按seqId升序排列并去重
            final messageMap = <int, Message>{};
            for (final message in allMessages) {
              messageMap[message.messageId] = message;
            }
            _messages = messageMap.values.toList()
              ..sort((a, b) => a.seqId.compareTo(b.seqId));

            _hasMoreHistory = pullResponse.hasMore;
            _historyCursor = pullResponse.nextCursor;
            _isLoadingHistory = false;
          });

          // 保存新消息到本地
          if (newMessages.isNotEmpty) {
            await _messageService.saveMessagesToLocal(newMessages);
          }

          // 如果是首次加载且滚动到顶部，滚动到最新消息
          if (_historyCursor == null && _messages.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });
          }
        }
      } else {
        print('❌ 拉取历史消息失败: ${result.error}');
        if (mounted) {
          setState(() {
            _isLoadingHistory = false;
          });
        }
      }
    } catch (e) {
      print('❌ 拉取历史消息异常: $e');
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  // 滚动监听器
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // 当滚动到顶部且还有更多历史消息时，加载更多
    if (_scrollController.offset <= 50 && _hasMoreHistory && !_isLoadingHistory) {
      final chatId = widget.chatInfo.chatId;
      if (chatId != 0) {
        _pullHistoryMessagesFromServer(chatId);
      }
    }
  }

  // 滚动到底部
  void _scrollToBottom() {
    if (_scrollController.hasClients && _messages.isNotEmpty) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Mock数据用于测试
  Future<void> _mockMessages() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final channelId = widget.chatInfo.chatId;

    final mockMessages = [
      Message(
        messageId: 1,
        channelId: channelId,
        seqId: 1,
        fromUserId: 1001,
        messageType: MessageType.text,
        content: '你好！最近怎么样？',
        showText: '你好！最近怎么样？',
        expireTime: 0,
        createTime: now - 3600000, // 1小时前
      ),
      Message(
        messageId: 2,
        channelId: channelId,
        seqId: 2,
        fromUserId: 1002,
        messageType: MessageType.text,
        content: '挺好的，正在学习Flutter开发。',
        showText: '挺好的，正在学习Flutter开发。',
        expireTime: 0,
        createTime: now - 3000000, // 50分钟前
      ),
      Message(
        messageId: 3,
        channelId: channelId,
        seqId: 3,
        fromUserId: 1001,
        messageType: MessageType.image,
        content: 'https://example.com/image.jpg',
        showText: '[图片]',
        expireTime: 0,
        createTime: now - 2400000, // 40分钟前
      ),
      Message(
        messageId: 4,
        channelId: channelId,
        seqId: 4,
        fromUserId: 1002,
        messageType: MessageType.text,
        content: '这个界面做得不错！',
        showText: '这个界面做得不错！',
        expireTime: 0,
        createTime: now - 1800000, // 30分钟前
      ),
      Message(
        messageId: 5,
        channelId: channelId,
        seqId: 5,
        fromUserId: 1001,
        messageType: MessageType.redPacket,
        content: '{"amount": 8.88, "greeting": "恭喜发财！"}',
        showText: '[红包]',
        expireTime: 0,
        createTime: now - 1200000, // 20分钟前
      ),
      Message(
        messageId: 6,
        channelId: channelId,
        seqId: 6,
        fromUserId: 1002,
        messageType: MessageType.text,
        content: '谢谢你的红包！',
        showText: '谢谢你的红包！',
        expireTime: 0,
        createTime: now - 600000, // 10分钟前
      ),
    ];

    await StorageService.saveMessages(mockMessages);
    _loadHistoryMessages(); // 重新加载数据
  }

  String _formatTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();

    if (now.day == dateTime.day && now.month == dateTime.month && now.year == dateTime.year) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (now.year == dateTime.year) {
      return DateFormat('MM/dd HH:mm').format(dateTime);
    } else {
      return DateFormat('yyyy/MM/dd HH:mm').format(dateTime);
    }
  }

  Widget _buildMessageBubble(Message message) {
    final isMe = message.fromUserId == 1002; // 假设当前用户ID是1002
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) _buildAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: alignment,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.65,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: message.messageType == MessageType.redPacket ? 8 : 10
                  ),
                  decoration: BoxDecoration(
                    color: _getBubbleColor(message, isMe),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: _buildMessageContent(message, isMe),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(message.createTime),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isMe) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.blue[200],
        shape: BoxShape.circle,
      ),
      child: widget.chatInfo.avatar != null
          ? ClipOval(
              child: Image.network(
                widget.chatInfo.avatar!,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.person,
                    size: 20,
                    color: Colors.white,
                  );
                },
              ),
            )
          : Icon(
              Icons.person,
              size: 20,
              color: Colors.white,
            ),
    );
  }

  Color _getBubbleColor(Message message, bool isMe) {
    if (message.messageType == MessageType.redPacket) {
      return const Color(0xFFFFD700); // 金色红包背景
    }
    return isMe ? const Color(0xFF95EC69) : const Color(0xFFFFFFFF);
  }

  Widget _buildMessageContent(Message message, bool isMe) {
    switch (message.messageType) {
      case MessageType.text:
        return Text(
          message.content,
          style: TextStyle(
            color: isMe ? const Color(0xFF000000) : const Color(0xFF000000),
            fontSize: 16,
            height: 1.4,
          ),
        );
      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.image,
                color: Colors.grey[600],
                size: 40,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '[图片]',
              style: TextStyle(
                color: isMe ? const Color(0xFF999999) : const Color(0xFF999999),
                fontSize: 12,
              ),
            ),
          ],
        );
      case MessageType.video:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.videocam,
                color: Colors.grey[600],
                size: 40,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '[视频]',
              style: TextStyle(
                color: isMe ? const Color(0xFF999999) : const Color(0xFF999999),
                fontSize: 12,
              ),
            ),
          ],
        );
      case MessageType.redPacket:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF6B35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '恭喜发财',
                    style: TextStyle(
                      color: Color(0xFF8B4513),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '微信红包',
                    style: TextStyle(
                      color: Color(0xFF8B4513),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F8F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF333333)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.blue[200],
                shape: BoxShape.circle,
              ),
              child: widget.chatInfo.avatar != null
                  ? ClipOval(
                      child: Image.network(
                        widget.chatInfo.avatar!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person,
                            size: 20,
                            color: Colors.white,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.person,
                      size: 20,
                      color: Colors.white,
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.chatInfo.chatTitle,
                    style: const TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    '在线',
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Color(0xFF333333)),
            onPressed: () {
              // TODO: 更多选项
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFEDEDED),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFFEDEDED),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty && !_isLoadingHistory
                      ? const Center(
                          child: Text(
                            '暂无消息',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: false, // 从顶部开始显示，按seqId升序排列
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _messages.length + (_hasMoreHistory ? 1 : 0),
                          itemBuilder: (context, index) {
                            // 如果是最后一个项目且有更多历史消息，显示加载指示器
                            if (index == _messages.length && _hasMoreHistory) {
                              return _buildLoadingIndicator();
                            }

                            return _buildMessageBubble(_messages[index]);
                          },
                        ),
            ),
          ),
          // 表情选择器
          if (_showEmoji)
            Container(
              height: 250,
              color: Colors.white,
              child: EmojiPicker(
                onEmojiSelected: (Category? category, Emoji emoji) {
                  _onEmojiSelected(emoji);
                },
                config: const Config(
                  checkPlatformCompatibility: true,
                ),
              ),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLoadingHistory)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Text(
              '没有更多历史消息了',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      color: const Color(0xFFF8F8F8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: _isRecording ? Colors.red : const Color(0xFF666666),
                size: 24,
              ),
              onPressed: _toggleVoiceRecording,
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.sentiment_satisfied_alt, color: Color(0xFF666666), size: 20),
                      onPressed: _toggleEmojiPicker,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          hintText: '输入消息...',
                          hintStyle: TextStyle(color: Color(0xFF999999), fontSize: 16),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                        ),
                        style: const TextStyle(fontSize: 16, color: Color(0xFF333333)),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (text) {
                          setState(() {
                            _isComposing = text.isNotEmpty;
                          });
                        },
                        onSubmitted: _isComposing ? _handleSubmitted : null,
                      ),
                    ),
                    if (_isComposing)
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Color(0xFF666666), size: 20),
                        onPressed: _showMoreOptionsBottomSheet,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    if (_isComposing) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF07C160),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.send, color: Colors.white, size: 16),
          onPressed: _isComposing ? () => _handleSubmitted(_textController.text) : null,
          padding: EdgeInsets.zero,
        ),
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.add_circle, color: Color(0xFF07C160), size: 28),
        onPressed: _showMoreOptionsBottomSheet,
      );
    }
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    final newMessage = Message(
      messageId: DateTime.now().millisecondsSinceEpoch,
      channelId: widget.chatInfo.chatId,
      seqId: _messages.isNotEmpty ? _messages.last.seqId + 1 : 1,
      fromUserId: 1002, // 假设当前用户ID是1002
      messageType: MessageType.text,
      content: text.trim(),
      showText: text.trim(),
      expireTime: 0,
      createTime: DateTime.now().millisecondsSinceEpoch,
    );

    setState(() {
      _messages.add(newMessage);
      _isComposing = false;
    });

    _textController.clear();

    // 滚动到底部
    _scrollToBottom();

    // 保存到本地存储
    StorageService.saveMessage(newMessage);

    // 发送消息到服务器
    _sendMessageToServer(newMessage);
  }

  void _sendMessageToServer(Message message) async {
    try {
      final messageData = {
        'channel_id': message.channelId,
        'message_type': message.messageType.value,
        'content': message.content,
        'show_text': message.showText,
      };

      final success = await WebSocketService.instance.sendMessage(
        command: WebSocketCommands.sendMessage,
        data: jsonEncode(messageData),
      );

      if (success) {
        print('消息发送成功: ${message.content}');
      } else {
        print('消息发送失败: ${message.content}');
        // TODO: 显示发送失败提示
      }
    } catch (e) {
      print('发送消息异常: $e');
      // TODO: 显示发送失败提示
    }
  }

  void _initWebSocket() async {
    WebSocketService.instance.addListener(this);

    if (!WebSocketService.instance.isConnected) {
      // 获取用户信息并连接WebSocket
      final userInfo = await StorageService.getUserInfo();
      if (userInfo != null) {
        await WebSocketService.instance.connect(userId: userInfo.userId.toString());
      }
    }
  }

  @override
  void onConnected() {
    print('WebSocket连接成功');
  }

  @override
  void onDisconnected() {
    print('WebSocket连接断开');
  }

  @override
  void onError(String error) {
    print('WebSocket错误: $error');
    // TODO: 显示连接错误提示
  }

  @override
  void onMessage(LongLinkBody message) {
    print('收到WebSocket消息: ${message.command}');

    // 处理收到的消息
    if (message.command == WebSocketCommands.receiveMessage) {
      _handleReceiveMessage(message);
    }
  }

  @override
  void onReconnecting() {
    print('WebSocket重连中...');
  }

  @override
  void onReconnected() {
    print('WebSocket重连成功');
  }

  void _handleReceiveMessage(LongLinkBody longLinkBody) {
    try {
      final messageData = jsonDecode(longLinkBody.data);

      // 检查是否是当前频道的消息
      final channelId = messageData['channel_id'] as int?;
      if (channelId == null || channelId != widget.chatInfo.chatId) {
        return;
      }

      final receivedMessage = Message.fromJson(messageData);

      if (mounted) {
        setState(() {
          _messages.add(receivedMessage);
        });

        // 滚动到底部
        _scrollToBottom();
      }

      // 保存到本地存储
      StorageService.saveMessage(receivedMessage);
    } catch (e) {
      print('处理接收到的消息失败: $e');
    }
  }

  // 语音录制功能
  Future<void> _toggleVoiceRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      // 请求录音权限
      final hasPermission = await _requestMicrophonePermission();
      if (!hasPermission) {
        _showPermissionDeniedDialog('麦克风');
        return;
      }

      // 开始录音
      final tempDir = await getTemporaryDirectory();
      final audioPath = path.join(tempDir.path, 'voice_${DateTime.now().millisecondsSinceEpoch}.wav');

      await _audioRecorder.start(const RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 128000,
        sampleRate: 44100,
      ), path: audioPath);

      setState(() {
        _isRecording = true;
      });

      // 显示录音提示
      _showRecordingDialog();
    } catch (e) {
      print('开始录音失败: $e');
      _showErrorDialog('录音失败', '无法开始录音，请检查权限设置');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (path != null && mounted) {
        Navigator.of(context).pop(); // 关闭录音提示框
        _sendVoiceMessage(path);
      }
    } catch (e) {
      print('停止录音失败: $e');
      setState(() {
        _isRecording = false;
      });
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _sendVoiceMessage(String audioPath) async {
    try {
      final voiceMessage = Message(
        messageId: DateTime.now().millisecondsSinceEpoch,
        channelId: widget.chatInfo.chatId,
        seqId: _messages.isNotEmpty ? _messages.last.seqId + 1 : 1,
        fromUserId: 1002, // 假设当前用户ID是1002
        messageType: MessageType.text, // 暂时用文本类型，实际应该是语音类型
        content: '[语音]',
        showText: '[语音]',
        expireTime: 0,
        createTime: DateTime.now().millisecondsSinceEpoch,
      );

      setState(() {
        _messages.add(voiceMessage);
      });

      // 滚动到底部
      _scrollToBottom();

      // 保存到本地存储
      StorageService.saveMessage(voiceMessage);

      // TODO: 实际发送语音文件到服务器
      _sendMessageToServer(voiceMessage);
    } catch (e) {
      print('发送语音消息失败: $e');
    }
  }

  Future<bool> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  void _showRecordingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text('正在录音...'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('松开发送，上滑取消'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _stopRecording();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('停止录音'),
            ),
          ],
        ),
      ),
    );
  }

  // 表情选择功能
  void _toggleEmojiPicker() {
    setState(() {
      _showEmoji = !_showEmoji;
    });

    if (_showEmoji) {
      // 隐藏键盘
      FocusScope.of(context).unfocus();
    }
  }

  void _onEmojiSelected(Emoji emoji) {
    _textController.text += emoji.emoji;
    setState(() {
      _isComposing = _textController.text.isNotEmpty;
    });
  }

  
  void _showMoreOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '更多功能',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 1,
                children: [
                  _buildFunctionItem(Icons.photo_album, '相册', _pickImage),
                  _buildFunctionItem(Icons.camera_alt, '拍照', _takePhoto),
                  _buildFunctionItem(Icons.videocam, '视频', _takeVideo),
                  _buildFunctionItem(Icons.location_on, '位置', _sendLocation),
                  _buildFunctionItem(Icons.person, '名片', _sendCard),
                  _buildFunctionItem(Icons.card_giftcard, '红包', _sendRedPacket),
                  _buildFunctionItem(Icons.file_present, '文件', _pickFile),
                  _buildFunctionItem(Icons.mic, '语音输入', _voiceInput),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFunctionItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 28, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  // 图片选择功能
  Future<void> _pickImage() async {
    try {
      final hasPermission = await _requestPhotoPermission();
      if (!hasPermission) {
        _showPermissionDeniedDialog('相册');
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (image != null) {
        _sendImageMessage(image);
      }
    } catch (e) {
      print('选择图片失败: $e');
      _showErrorDialog('选择图片失败', '无法选择图片，请重试');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final hasPermission = await _requestCameraPermission();
      if (!hasPermission) {
        _showPermissionDeniedDialog('相机');
        return;
      }

      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (photo != null) {
        _sendImageMessage(photo);
      }
    } catch (e) {
      print('拍照失败: $e');
      _showErrorDialog('拍照失败', '无法拍照，请重试');
    }
  }

  Future<void> _takeVideo() async {
    try {
      final hasPermission = await _requestCameraPermission();
      if (!hasPermission) {
        _showPermissionDeniedDialog('相机');
        return;
      }

      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 60),
      );

      if (video != null) {
        _sendVideoMessage(video);
      }
    } catch (e) {
      print('录制视频失败: $e');
      _showErrorDialog('录制视频失败', '无法录制视频，请重试');
    }
  }

  Future<void> _sendImageMessage(XFile imageFile) async {
    final imageMessage = Message(
      messageId: DateTime.now().millisecondsSinceEpoch,
      channelId: widget.chatInfo.chatId,
      seqId: _messages.isNotEmpty ? _messages.last.seqId + 1 : 1,
      fromUserId: 1002,
      messageType: MessageType.image,
      content: imageFile.path,
      showText: '[图片]',
      expireTime: 0,
      createTime: DateTime.now().millisecondsSinceEpoch,
    );

    setState(() {
      _messages.add(imageMessage);
    });

    _scrollToBottom();

    // 保存到本地存储
    StorageService.saveMessage(imageMessage);

    // TODO: 上传图片到服务器
    _sendMessageToServer(imageMessage);
  }

  Future<void> _sendVideoMessage(XFile videoFile) async {
    final videoMessage = Message(
      messageId: DateTime.now().millisecondsSinceEpoch,
      channelId: widget.chatInfo.chatId,
      seqId: _messages.isNotEmpty ? _messages.last.seqId + 1 : 1,
      fromUserId: 1002,
      messageType: MessageType.video,
      content: videoFile.path,
      showText: '[视频]',
      expireTime: 0,
      createTime: DateTime.now().millisecondsSinceEpoch,
    );

    setState(() {
      _messages.add(videoMessage);
    });

    _scrollToBottom();

    // 保存到本地存储
    StorageService.saveMessage(videoMessage);

    // TODO: 上传视频到服务器
    _sendMessageToServer(videoMessage);
  }

  // 其他功能占位方法
  Future<void> _sendLocation() async {
    _showMessage('位置功能', '位置发送功能待实现');
  }

  Future<void> _sendCard() async {
    _showMessage('名片功能', '名片发送功能待实现');
  }

  Future<void> _sendRedPacket() async {
    final redPacketMessage = Message(
      messageId: DateTime.now().millisecondsSinceEpoch,
      channelId: widget.chatInfo.chatId,
      seqId: _messages.isNotEmpty ? _messages.last.seqId + 1 : 1,
      fromUserId: 1002,
      messageType: MessageType.redPacket,
      content: '{"amount": 8.88, "greeting": "恭喜发财！"}',
      showText: '[红包]',
      expireTime: 0,
      createTime: DateTime.now().millisecondsSinceEpoch,
    );

    setState(() {
      _messages.add(redPacketMessage);
    });

    _scrollToBottom();

    // 保存到本地存储
    StorageService.saveMessage(redPacketMessage);

    _sendMessageToServer(redPacketMessage);
  }

  Future<void> _pickFile() async {
    _showMessage('文件功能', '文件选择功能待实现');
  }

  Future<void> _voiceInput() async {
    _showMessage('语音输入', '语音输入功能待实现');
  }

  // 权限请求方法
  Future<bool> _requestPhotoPermission() async {
    final status = await Permission.photos.request();
    return status.isGranted;
  }

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  // 对话框方法
  void _showPermissionDeniedDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('权限被拒绝'),
        content: Text('需要$feature权限才能使用此功能。请在设置中开启权限。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}