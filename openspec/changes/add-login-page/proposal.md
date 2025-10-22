## Why
用户需要通过身份验证才能访问应用的主要功能。当前应用直接显示主页，需要添加登录页面作为应用启动入口，确保只有通过身份验证的用户才能访问聊天、发现和个人中心功能。

## What Changes
- 创建登录页面作为应用启动页面
- 添加用户名和密码输入验证逻辑
- 修改 main.dart 将登录页面设为首页
- 实现表单验证（用户名：英文、下划线、数字，长度1-50；密码：长度1-30）
- 添加登录成功后跳转到主页的导航逻辑

## Impact
- Affected specs: 新增 user-auth 认证功能
- Affected code:
  - lib/main.dart (修改初始路由)
  - 新增 lib/page/login_page.dart
  - lib/config/route.dart (添加登录路由)