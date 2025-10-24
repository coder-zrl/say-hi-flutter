import 'package:flutter/material.dart';
import 'package:say_hi_flutter/page/tabs/chat_page.dart';
import 'package:say_hi_flutter/page/tabs/discover_page.dart';
import 'package:say_hi_flutter/page/tabs/mine_page.dart';
import 'package:say_hi_flutter/service/websocket_service.dart';

class HomePage extends StatefulWidget {
  final int initialIndex;

  const HomePage({super.key, this.initialIndex = 0});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _currentIndex;

  // 三个页面
  final List<Widget> _pages = [
    DiscoverPage(),
    ChatPage(),
    MinePage(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initWebSocket();
  }

  @override
  void dispose() {
    // 断开WebSocket连接
    WebSocketService.instance.disconnect();
    super.dispose();
  }

  /// 初始化WebSocket连接
  void _initWebSocket() async {
    try {
      // 延迟初始化，确保页面已经加载完成
      await Future.delayed(const Duration(milliseconds: 1000));

      // 连接WebSocket
      await WebSocketService.instance.connect();
      print('✅ WebSocket初始化完成');
    } catch (e) {
      print('❌ WebSocket初始化失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: '发现',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: '聊天',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
