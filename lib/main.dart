import 'package:flutter/material.dart';
import 'package:say_hi_flutter/config/route.dart';
import 'package:say_hi_flutter/service/http_service.dart';
import 'package:say_hi_flutter/service/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化HTTP服务
  HttpService().init();

  // 初始化数据库（仅移动平台）
  await StorageService.initDatabase();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Say Hi Flutter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: RoutePath.login,
      onGenerateRoute: onGenerateRoute,
    );
  }
}