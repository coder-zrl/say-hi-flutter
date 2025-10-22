import 'package:flutter/cupertino.dart';
import 'package:say_hi_flutter/page/home_page.dart';
import 'package:say_hi_flutter/page/login_page.dart';

class RoutePath {
  static const String login = '/login';
  static const String home = '/';
  static const String webViewPage = '/webViewPage';
}


// 1.配置路由
Map routes = {
  RoutePath.login: (context, {arguments}) => const LoginPage(),
  RoutePath.home: (context, {arguments}) => HomePage(
    initialIndex: arguments?['initialIndex'] ?? 0,
  ),
};

// 2.配置 onGenerateRoute
var onGenerateRoute = (RouteSettings settings) {
  // 固定写法
  final String? name = settings.name;
  final Function? pageContentBuilder = routes[name];
  if (pageContentBuilder != null) {
    if (settings.arguments != null) {
      // MaterialPageRoute 在安卓是上下切换页面跳转路由，在 ios 是左右切换跳转路由
      // 而 CupertinoPageRoute 可以让安卓和 ios 都实现左右切换路由
      final Route route = CupertinoPageRoute(
        builder: (context) =>
            pageContentBuilder(context, arguments: settings.arguments),
      );
      return route;
    } else {
      final Route route = CupertinoPageRoute(
        builder: (context) => pageContentBuilder(context),
      );
      return route;
    }
  }
  return null;
};
