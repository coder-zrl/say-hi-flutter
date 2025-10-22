class LoginRequest {
  final String username;
  final String password;

  LoginRequest({
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
    };
  }
}

class LoginResponse {
  final int code;
  final String message;
  final LoginData data;
  final bool success;

  LoginResponse({
    required this.code,
    required this.message,
    required this.data,
    required this.success,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      code: json['code'] ?? 0,
      message: json['message'] ?? '',
      data: LoginData.fromJson(json['data'] ?? {}),
      success: json['success'] ?? false,
    );
  }
}

class LoginData {
  final String tokenName;
  final String tokenValue;
  final bool isLogin;
  final String loginId;
  final String loginType;
  final int tokenTimeout;
  final int sessionTimeout;
  final int tokenSessionTimeout;
  final int tokenActiveTimeout;
  final String loginDeviceType;
  final String? tag;

  LoginData({
    required this.tokenName,
    required this.tokenValue,
    required this.isLogin,
    required this.loginId,
    required this.loginType,
    required this.tokenTimeout,
    required this.sessionTimeout,
    required this.tokenSessionTimeout,
    required this.tokenActiveTimeout,
    required this.loginDeviceType,
    this.tag,
  });

  factory LoginData.fromJson(Map<String, dynamic> json) {
    return LoginData(
      tokenName: json['tokenName'] ?? '',
      tokenValue: json['tokenValue'] ?? '',
      isLogin: json['isLogin'] ?? false,
      loginId: json['loginId']?.toString() ?? '',
      loginType: json['loginType'] ?? '',
      tokenTimeout: json['tokenTimeout'] ?? 0,
      sessionTimeout: json['sessionTimeout'] ?? 0,
      tokenSessionTimeout: json['tokenSessionTimeout'] ?? 0,
      tokenActiveTimeout: json['tokenActiveTimeout'] ?? 0,
      loginDeviceType: json['loginDeviceType'] ?? '',
      tag: json['tag'],
    );
  }
}