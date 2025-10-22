import 'package:flutter/material.dart';

class ApiResponse<T> {
  final int code;
  final String message;
  final T? data;
  final bool success;

  ApiResponse({
    required this.code,
    required this.message,
    this.data,
    required this.success,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(dynamic)? fromJsonT) {
    return ApiResponse<T>(
      code: json['code'] ?? 0,
      message: json['message'] ?? '',
      data: json['data'] != null && fromJsonT != null ? fromJsonT(json['data']) : json['data'],
      success: json['success'] ?? false,
    );
  }

  bool get isSuccess => code == 200 && success;
}

class ResponseHandler {
  static BuildContext? _context;

  static void init(BuildContext context) {
    _context = context;
  }

  static void updateContext(BuildContext context) {
    _context = context;
  }

  static Future<bool> handleResponse<T>(
    ApiResponse<T> response, {
    bool showErrorDialog = true,
    String? successMessage,
  }) async {
    // 如果响应成功
    if (response.isSuccess) {
      // 如果有成功消息，显示Toast或SnackBar
      if (successMessage != null && successMessage.isNotEmpty) {
        _showSuccessMessage(successMessage);
      }
      return true;
    }

    // 如果响应失败，显示错误弹窗
    if (showErrorDialog && _context != null) {
      await _showErrorDialog(response.message);
    }

    return false;
  }

  static Future<bool> handleErrorResponse(
    int code,
    String message, {
    bool showErrorDialog = true,
  }) async {
    if (showErrorDialog && _context != null) {
      await _showErrorDialog(message);
    }
    return false;
  }

  static void _showSuccessMessage(String message) {
    if (_context == null) return;

    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static Future<void> _showErrorDialog(String message) async {
    if (_context == null) return;

    return showDialog<void>(
      context: _context!,
      barrierDismissible: false, // 用户必须点击按钮才能关闭
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('确定'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  static void showToast(String message, {bool isError = false}) {
    if (_context == null) return;

    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}