import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:say_hi_flutter/model/chat_info_model.dart';

class StorageService {
  static Database? _database;
  static const String _dbName = 'say_hi.db';
  static const int _dbVersion = 3;

  // SharedPreferences keys for all platforms
  static const String _tokenNameKey = 'user_token_name';
  static const String _tokenValueKey = 'user_token_value';

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

  // 聊天数据存储方法
  static Future<void> saveChatList(List<ChatInfo> chatList) async {
    if (!kIsWeb && _database != null) {
      final batch = _database!.batch();
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final chatInfo in chatList) {
        batch.insert(
          'chat_info',
          {
            'chat_id': chatInfo.chatId,
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
        chatId: map['chat_id'] as String,
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
        whereArgs: [chatInfo.chatId],
      );
    }
  }

  static Future<void> deleteChatInfo(String chatId) async {
    if (!kIsWeb && _database != null) {
      await _database!.delete(
        'chat_info',
        where: 'chat_id = ?',
        whereArgs: [chatId],
      );
    }
  }

  static Future<void> clearChatList() async {
    if (!kIsWeb && _database != null) {
      await _database!.delete('chat_info');
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