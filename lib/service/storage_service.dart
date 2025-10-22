import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class StorageService {
  static Database? _database;
  static const String _dbName = 'say_hi.db';
  static const int _dbVersion = 1;

  // SharedPreferences keys for all platforms
  static const String _tokenNameKey = 'user_token_name';
  static const String _tokenValueKey = 'user_token_value';

  static Future<void> initDatabase() async {
    if (!kIsWeb) {
      // 只在移动平台上初始化SQLite
      _database = await _initMobileDatabase();
    }
  }

  static Future<Database> _initMobileDatabase() async {
    String path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
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