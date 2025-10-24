class ChatInfo {
  /**
   * 会话ID
   */
  final int chatId;

  /**
   * 会话头像
   */
  final String? avatar;

  /**
   * 会话标题
   */
  final String chatTitle;

  /**
   * 最后一条消息的时间
   */
  final int lastMessageTime;

  /**
   * 最后一条消息内容
   */
  final String lastMessageContent;

  /**
   * 最后活跃时间戳
   */
  final int lastActiveTime;

  /**
   * 未读数数量
   */
  final int unreadCount;

  /**
   * 会话是否置顶
   */
  final bool stickyTop;

  /**
   * 会话优先级，按优先级降序排列
   */
  final int priority;

  /**
   * 已读消息ID
   */
  final int? readSeqId;

  /**
   * 最大消息ID
   */
  final int? maxSeqId;

  /**
   * 是否免打扰
   */
  final bool doNotDisturb;

  ChatInfo({
    required this.chatId,
    this.avatar,
    required this.chatTitle,
    required this.lastMessageTime,
    required this.lastMessageContent,
    required this.lastActiveTime,
    required this.unreadCount,
    required this.stickyTop,
    required this.priority,
    this.readSeqId,
    this.maxSeqId,
    this.doNotDisturb = false,
  });

  factory ChatInfo.fromJson(Map<String, dynamic> json) {
    try {
      print('📥 ChatInfo.fromJson - 输入数据: $json');

      return ChatInfo(
        chatId: (json['chatId'] as num?)?.toInt() ?? 0,
        avatar: json['avatar'] as String?,
        chatTitle: json['chatTitle'] as String? ?? '',
        lastMessageTime: (json['lastMessageTime'] as int?) ?? 0,
        lastMessageContent: json['lastMessageContent'] as String? ?? '',
        lastActiveTime: (json['lastActiveTime'] as int?) ?? 0,
        unreadCount: (json['unreadCount'] as int?) ?? 0,
        stickyTop: (json['stickyTop'] as bool?) ?? false,
        priority: (json['priority'] as int?) ?? 0,
        readSeqId: json['readSeqId'] as int?,
        maxSeqId: json['maxSeqId'] as int?,
        doNotDisturb: (json['doNotDisturb'] as bool?) ?? false,
      );
    } catch (e) {
      print('❌ ChatInfo.fromJson 错误: $e');
      print('❌ 输入数据: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'chatId': chatId,
      'avatar': avatar,
      'chatTitle': chatTitle,
      'lastMessageTime': lastMessageTime,
      'lastMessageContent': lastMessageContent,
      'lastActiveTime': lastActiveTime,
      'unreadCount': unreadCount,
      'stickyTop': stickyTop,
      'priority': priority,
      'readSeqId': readSeqId,
      'maxSeqId': maxSeqId,
      'doNotDisturb': doNotDisturb,
    };
  }

  ChatInfo copyWith({
    int? chatId,
    String? avatar,
    String? chatTitle,
    int? lastMessageTime,
    String? lastMessageContent,
    int? lastActiveTime,
    int? unreadCount,
    bool? stickyTop,
    int? priority,
    int? readSeqId,
    int? maxSeqId,
    bool? doNotDisturb,
  }) {
    return ChatInfo(
      chatId: chatId ?? this.chatId,
      avatar: avatar ?? this.avatar,
      chatTitle: chatTitle ?? this.chatTitle,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastActiveTime: lastActiveTime ?? this.lastActiveTime,
      unreadCount: unreadCount ?? this.unreadCount,
      stickyTop: stickyTop ?? this.stickyTop,
      priority: priority ?? this.priority,
      readSeqId: readSeqId ?? this.readSeqId,
      maxSeqId: maxSeqId ?? this.maxSeqId,
      doNotDisturb: doNotDisturb ?? this.doNotDisturb,
    );
  }

  @override
  String toString() {
    return 'ChatInfo(chatId: $chatId, avatar: $avatar, chatTitle: $chatTitle, lastMessageTime: $lastMessageTime, lastMessageContent: $lastMessageContent, lastActiveTime: $lastActiveTime, unreadCount: $unreadCount, stickyTop: $stickyTop, priority: $priority, readSeqId: $readSeqId, maxSeqId: $maxSeqId, doNotDisturb: $doNotDisturb)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatInfo &&
        other.chatId == chatId &&
        other.avatar == avatar &&
        other.chatTitle == chatTitle &&
        other.lastMessageTime == lastMessageTime &&
        other.lastMessageContent == lastMessageContent &&
        other.lastActiveTime == lastActiveTime &&
        other.unreadCount == unreadCount &&
        other.stickyTop == stickyTop &&
        other.priority == priority &&
        other.readSeqId == readSeqId &&
        other.maxSeqId == maxSeqId &&
        other.doNotDisturb == doNotDisturb;
  }

  @override
  int get hashCode {
    return Object.hash(
      chatId,
      avatar,
      chatTitle,
      lastMessageTime,
      lastMessageContent,
      lastActiveTime,
      unreadCount,
      stickyTop,
      priority,
      readSeqId,
      maxSeqId,
      doNotDisturb,
    );
  }
}