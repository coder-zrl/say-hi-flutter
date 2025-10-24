enum MessageType {
  text(0, '文本'),
  image(1, '图片'),
  video(2, '视频'),
  redPacket(201, '红包');

  const MessageType(this.value, this.description);

  final int value;
  final String description;

  static MessageType fromValue(int value) {
    return MessageType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => MessageType.text,
    );
  }
}

class Message {
  final int messageId;
  final int channelId;
  final int seqId;
  final int fromUserId;
  final MessageType messageType;
  final String content;
  final String showText;
  final int expireTime;
  final int createTime;
  final int updateTime;
  final int deleteTime;

  Message({
    required this.messageId,
    required this.channelId,
    required this.seqId,
    required this.fromUserId,
    required this.messageType,
    required this.content,
    required this.showText,
    required this.expireTime,
    required this.createTime,
    this.updateTime = 0,
    this.deleteTime = 0,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      messageId: json['message_id'] ?? 0,
      channelId: json['channel_id'] ?? 0,
      seqId: json['seq_id'] ?? 0,
      fromUserId: json['from_user_id'] ?? 0,
      messageType: MessageType.fromValue(json['message_type'] ?? 0),
      content: json['content'] ?? '',
      showText: json['show_text'] ?? '',
      expireTime: json['expire_time'] ?? 0,
      createTime: json['create_time'] ?? 0,
      updateTime: json['update_time'] ?? 0,
      deleteTime: json['delete_time'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'channel_id': channelId,
      'seq_id': seqId,
      'from_user_id': fromUserId,
      'message_type': messageType.value,
      'content': content,
      'show_text': showText,
      'expire_time': expireTime,
      'create_time': createTime,
      'update_time': updateTime,
      'delete_time': deleteTime,
    };
  }

  bool get isDeleted => deleteTime > 0;

  bool get isExpired {
    if (expireTime == 0) return false;
    return DateTime.now().millisecondsSinceEpoch > expireTime;
  }

  @override
  String toString() {
    return 'Message{messageId: $messageId, channelId: $channelId, seqId: $seqId, content: $content}';
  }
}