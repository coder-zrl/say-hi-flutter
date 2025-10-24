import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:say_hi_flutter/model/chat_info_model.dart';
import 'package:say_hi_flutter/model/login_model.dart';
import 'package:say_hi_flutter/model/message_model.dart';

class StorageService {
  static Database? _database;
  static const String _dbName = 'say_hi.db';
  static const int _dbVersion = 4;

  // SharedPreferences keys for all platforms
  static const String _tokenNameKey = 'user_token_name';
  static const String _tokenValueKey = 'user_token_value';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';
  static const String _userInfoKey = 'user_info';
  static const String _websocketUrlKey = 'websocket_url';

  static Future<void> initDatabase() async {
    if (!kIsWeb) {
      try {
        // 只在移动平台上初始化SQLite
        _database = await _initMobileDatabase();
      } catch (e) {
        print('数据库初始化失败: $e');
        // 如果数据库升级失败，尝试删除旧数据库重新创建
        try {
          final databasePath = await getDatabasesPath();
          final path = join(databasePath, _dbName);
          await deleteDatabase(path);
          _database = await _initMobileDatabase();
          print('数据库重新创建成功');
        } catch (retryError) {
          print('数据库重新创建失败: $retryError');
        }
      }
    }
  }

  static Future<Database> _initMobileDatabase() async {
    String path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_token (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        token_name TEXT NOT NULL,
        token_value TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_info (
        chat_id TEXT PRIMARY KEY,
        avatar TEXT,
        chat_title TEXT NOT NULL,
        last_message_time INTEGER NOT NULL,
        last_message_content TEXT NOT NULL,
        last_active_time INTEGER NOT NULL,
        unread_count INTEGER NOT NULL DEFAULT 0,
        sticky_top INTEGER NOT NULL DEFAULT 0,
        priority INTEGER NOT NULL DEFAULT 0,
        read_seq_id INTEGER,
        max_seq_id INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE message (
        message_id INTEGER PRIMARY KEY,
        channel_id INTEGER NOT NULL,
        seq_id INTEGER NOT NULL,
        from_user_id INTEGER NOT NULL,
        message_type INTEGER NOT NULL,
        content TEXT NOT NULL,
        show_text TEXT NOT NULL,
        expire_time INTEGER NOT NULL DEFAULT 0,
        create_time INTEGER NOT NULL,
        update_time INTEGER NOT NULL DEFAULT 0,
        delete_time INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 创建索引用于优化查询
    await db.execute('CREATE INDEX idx_message_channel_seq ON message(channel_id, seq_id)');
    await db.execute('CREATE INDEX idx_message_create_time ON message(create_time)');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 检查chat_info表是否存在
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='chat_info'"
      );

      if (tables.isEmpty) {
        // 如果表不存在，创建新表
        await db.execute('''
          CREATE TABLE chat_info (
            chat_id TEXT PRIMARY KEY,
            avatar TEXT,
            chat_title TEXT NOT NULL,
            last_message_time INTEGER NOT NULL,
            last_message_content TEXT NOT NULL,
            last_active_time INTEGER NOT NULL,
            unread_count INTEGER NOT NULL DEFAULT 0,
            sticky_top INTEGER NOT NULL DEFAULT 0,
            priority INTEGER NOT NULL DEFAULT 0,
            read_seq_id INTEGER,
            max_seq_id INTEGER,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      } else {
        // 如果表存在，检查是否缺少avatar列
        final tableInfo = await db.rawQuery('PRAGMA table_info(chat_info)');
        final hasAvatarColumn = tableInfo.any((column) => column['name'] == 'avatar');

        if (!hasAvatarColumn) {
          // 添加avatar列
          await db.execute('ALTER TABLE chat_info ADD COLUMN avatar TEXT');
        }
      }
    }

    // 版本3的迁移：确保avatar列存在
    if (oldVersion < 3) {
      // 检查chat_info表是否存在
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='chat_info'"
      );

      if (tables.isNotEmpty) {
        // 如果表存在，检查是否缺少avatar列
        final tableInfo = await db.rawQuery('PRAGMA table_info(chat_info)');
        final hasAvatarColumn = tableInfo.any((column) => column['name'] == 'avatar');

        if (!hasAvatarColumn) {
          // 添加avatar列
          await db.execute('ALTER TABLE chat_info ADD COLUMN avatar TEXT');
        }
      }
    }

    // 版本4的迁移：创建message表
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS message (
          message_id INTEGER PRIMARY KEY,
          channel_id INTEGER NOT NULL,
          seq_id INTEGER NOT NULL,
          from_user_id INTEGER NOT NULL,
          message_type INTEGER NOT NULL,
          content TEXT NOT NULL,
          show_text TEXT NOT NULL,
          expire_time INTEGER NOT NULL DEFAULT 0,
          create_time INTEGER NOT NULL,
          update_time INTEGER NOT NULL DEFAULT 0,
          delete_time INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      // 创建索引
      await db.execute('CREATE INDEX IF NOT EXISTS idx_message_channel_seq ON message(channel_id, seq_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_message_create_time ON message(create_time)');
    }
  }

  static Future<void> saveToken(String tokenName, String tokenValue) async {
    // 所有平台都使用SharedPreferences作为主要存储
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenNameKey, tokenName);
    await prefs.setString(_tokenValueKey, tokenValue);

    // 移动平台同时使用SQLite作为备份
    if (!kIsWeb && _database != null) {
      final now = DateTime.now().millisecondsSinceEpoch;

      // 先清空现有的token记录
      await _database!.delete('user_token');

      // 插入新的token
      await _database!.insert(
        'user_token',
        {
          'token_name': tokenName,
          'token_value': tokenValue,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<Map<String, String>?> getToken() async {
    // 所有平台都优先从SharedPreferences读取
    final prefs = await SharedPreferences.getInstance();
    final tokenName = prefs.getString(_tokenNameKey);
    final tokenValue = prefs.getString(_tokenValueKey);

    if (tokenName != null && tokenValue != null) {
      return {
        'tokenName': tokenName,
        'tokenValue': tokenValue,
      };
    }

    // 如果SharedPreferences中没有，移动平台尝试从SQLite读取
    if (!kIsWeb && _database != null) {
      final List<Map<String, dynamic>> maps = await _database!.query(
        'user_token',
        orderBy: 'updated_at DESC',
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return {
          'tokenName': maps[0]['token_name'] as String,
          'tokenValue': maps[0]['token_value'] as String,
        };
      }
    }

    return null;
  }

  static Future<void> clearToken() async {
    // 清除SharedPreferences中的token
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenNameKey);
    await prefs.remove(_tokenValueKey);

    // 移动平台同时清除SQLite中的token
    if (!kIsWeb && _database != null) {
      await _database!.delete('user_token');
    }
  }

  // 用户ID相关方法
  static Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    print('✅ 保存userId到本地: $userId');
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  static Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
    print('✅ 保存username到本地: $username');
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  // 用户信息相关方法
  static Future<void> saveUserInfo(UserInfo userInfo) async {
    final prefs = await SharedPreferences.getInstance();
    // 将用户信息转换为JSON字符串存储
    final userInfoJson = userInfo.toJson();
    await prefs.setString(_userInfoKey, userInfoJson.toString());

    // 分别存储各个字段，便于单独获取
    await prefs.setString(_userIdKey, userInfo.userId.toString());
    await prefs.setString('user_nick_name', userInfo.nickName);
    await prefs.setString('user_avatar', userInfo.avatar);

    print('✅ 保存用户信息到本地: ${userInfo.toJson()}');
  }

  static Future<UserInfo?> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey);
    final nickName = prefs.getString('user_nick_name') ?? '';
    final avatar = prefs.getString('user_avatar') ?? '';

    if (userId != null) {
      return UserInfo(
        userId: int.tryParse(userId) ?? 0,
        nickName: nickName,
        avatar: avatar,
      );
    }
    return null;
  }

  static Future<void> saveUserNickName(String nickName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_nick_name', nickName);
    print('✅ 保存用户昵称到本地: $nickName');
  }

  static Future<void> saveUserAvatar(String avatar) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_avatar', avatar);
    print('✅ 保存用户头像到本地: $avatar');
  }

  // WebSocket地址相关方法
  static Future<void> saveWebSocketUrl(String websocketUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_websocketUrlKey, websocketUrl);
    print('✅ 保存WebSocket地址到本地: $websocketUrl');
  }

  static Future<String?> getWebSocketUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final websocketUrl = prefs.getString(_websocketUrlKey);
    if (websocketUrl != null) {
      print('✅ 获取WebSocket地址: $websocketUrl');
    }
    return websocketUrl;
  }

  // 默认WebSocket地址
  static String get defaultWebSocketUrl => 'ws://localhost:10086';

  // 获取WebSocket地址，如果本地没有保存则返回默认地址
  static Future<String> getWebSocketUrlOrDefault() async {
    final savedUrl = await getWebSocketUrl();
    return savedUrl ?? defaultWebSocketUrl;
  }

  static Future<void> clearUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_userInfoKey);
    await prefs.remove('user_nick_name');
    await prefs.remove('user_avatar');
    print('✅ 清除本地用户信息');
  }

  // 聊天数据存储方法
  static Future<void> saveChatList(List<ChatInfo> chatList) async {
    if (!kIsWeb && _database != null) {
      final batch = _database!.batch();
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final chatInfo in chatList) {
        batch.insert(
          'chat_info',
          {
            'chat_id': chatInfo.chatId.toString(),
            'avatar': chatInfo.avatar,
            'chat_title': chatInfo.chatTitle,
            'last_message_time': chatInfo.lastMessageTime,
            'last_message_content': chatInfo.lastMessageContent,
            'last_active_time': chatInfo.lastActiveTime,
            'unread_count': chatInfo.unreadCount,
            'sticky_top': chatInfo.stickyTop ? 1 : 0,
            'priority': chatInfo.priority,
            'read_seq_id': chatInfo.readSeqId,
            'max_seq_id': chatInfo.maxSeqId,
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    }
  }

  static Future<List<ChatInfo>> getChatList() async {
    if (!kIsWeb && _database != null) {
      final List<Map<String, dynamic>> maps = await _database!.query(
        'chat_info',
        orderBy: 'sticky_top DESC, last_active_time DESC, priority DESC',
      );

      return maps.map((map) => ChatInfo(
        chatId: int.tryParse(map['chat_id'] as String) ?? 0,
        avatar: map['avatar'] as String?,
        chatTitle: map['chat_title'] as String,
        lastMessageTime: map['last_message_time'] as int,
        lastMessageContent: map['last_message_content'] as String,
        lastActiveTime: map['last_active_time'] as int,
        unreadCount: map['unread_count'] as int,
        stickyTop: (map['sticky_top'] as int) == 1,
        priority: map['priority'] as int,
        readSeqId: map['read_seq_id'] as int?,
        maxSeqId: map['max_seq_id'] as int?,
      )).toList();
    }
    return [];
  }

  static Future<void> updateChatInfo(ChatInfo chatInfo) async {
    if (!kIsWeb && _database != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _database!.update(
        'chat_info',
        {
          'avatar': chatInfo.avatar,
          'chat_title': chatInfo.chatTitle,
          'last_message_time': chatInfo.lastMessageTime,
          'last_message_content': chatInfo.lastMessageContent,
          'last_active_time': chatInfo.lastActiveTime,
          'unread_count': chatInfo.unreadCount,
          'sticky_top': chatInfo.stickyTop ? 1 : 0,
          'priority': chatInfo.priority,
          'read_seq_id': chatInfo.readSeqId,
          'max_seq_id': chatInfo.maxSeqId,
          'updated_at': now,
        },
        where: 'chat_id = ?',
        whereArgs: [chatInfo.chatId.toString()],
      );
    }
  }

  static Future<void> deleteChatInfo(int chatId) async {
    if (!kIsWeb && _database != null) {
      await _database!.delete(
        'chat_info',
        where: 'chat_id = ?',
        whereArgs: [chatId.toString()],
      );
    }
  }

  static Future<void> clearChatList() async {
    if (!kIsWeb && _database != null) {
      await _database!.delete('chat_info');
    }
  }

  // 消息存储相关方法
  static Future<void> saveMessages(List<Message> messages) async {
    if (!kIsWeb && _database != null) {
      final batch = _database!.batch();
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final message in messages) {
        batch.insert(
          'message',
          {
            'message_id': message.messageId,
            'channel_id': message.channelId,
            'seq_id': message.seqId,
            'from_user_id': message.fromUserId,
            'message_type': message.messageType.value,
            'content': message.content,
            'show_text': message.showText,
            'expire_time': message.expireTime,
            'create_time': message.createTime,
            'update_time': message.updateTime,
            'delete_time': message.deleteTime,
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      print('✅ 保存${messages.length}条消息到本地');
    }
  }

  static Future<void> saveMessage(Message message) async {
    await saveMessages([message]);
  }

  static Future<List<Message>> getMessagesByChannelId(int channelId, {int limit = 50, int offset = 0}) async {
    if (!kIsWeb && _database != null) {
      final List<Map<String, dynamic>> maps = await _database!.query(
        'message',
        where: 'channel_id = ? AND delete_time = 0',
        whereArgs: [channelId],
        orderBy: 'seq_id DESC',
        limit: limit,
        offset: offset,
      );

      return maps.map((map) => Message(
        messageId: map['message_id'] as int,
        channelId: map['channel_id'] as int,
        seqId: map['seq_id'] as int,
        fromUserId: map['from_user_id'] as int,
        messageType: MessageType.fromValue(map['message_type'] as int),
        content: map['content'] as String,
        showText: map['show_text'] as String,
        expireTime: map['expire_time'] as int,
        createTime: map['create_time'] as int,
        updateTime: map['update_time'] as int,
        deleteTime: map['delete_time'] as int,
      )).toList();
    }
    return [];
  }

  static Future<List<Message>> getMessagesByChannelIdAfterSeq(int channelId, int seqId) async {
    if (!kIsWeb && _database != null) {
      final List<Map<String, dynamic>> maps = await _database!.query(
        'message',
        where: 'channel_id = ? AND seq_id > ? AND delete_time = 0',
        whereArgs: [channelId, seqId],
        orderBy: 'seq_id ASC',
      );

      return maps.map((map) => Message(
        messageId: map['message_id'] as int,
        channelId: map['channel_id'] as int,
        seqId: map['seq_id'] as int,
        fromUserId: map['from_user_id'] as int,
        messageType: MessageType.fromValue(map['message_type'] as int),
        content: map['content'] as String,
        showText: map['show_text'] as String,
        expireTime: map['expire_time'] as int,
        createTime: map['create_time'] as int,
        updateTime: map['update_time'] as int,
        deleteTime: map['delete_time'] as int,
      )).toList();
    }
    return [];
  }

  static Future<Message?> getLastMessageByChannelId(int channelId) async {
    final messages = await getMessagesByChannelId(channelId, limit: 1);
    return messages.isNotEmpty ? messages.first : null;
  }

  static Future<void> deleteMessage(int messageId) async {
    if (!kIsWeb && _database != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _database!.update(
        'message',
        {'delete_time': now, 'updated_at': now},
        where: 'message_id = ?',
        whereArgs: [messageId],
      );
    }
  }

  static Future<void> clearMessagesByChannelId(int channelId) async {
    if (!kIsWeb && _database != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _database!.update(
        'message',
        {'delete_time': now, 'updated_at': now},
        where: 'channel_id = ?',
        whereArgs: [channelId],
      );
    }
  }

  static Future<void> clearAllMessages() async {
    if (!kIsWeb && _database != null) {
      await _database!.delete('message');
    }
  }

  static Future<void> close() async {
    if (!kIsWeb) {
      final db = _database;
      if (db != null) {
        await db.close();
        _database = null;
      }
    }
  }
}