class UserInfo {
  final int userId;
  final String nickName;
  final String avatar;

  UserInfo({
    required this.userId,
    required this.nickName,
    required this.avatar,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      userId: json['userId'] ?? 0,
      nickName: json['nickName'] ?? '',
      avatar: json['avatar'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'nickName': nickName,
      'avatar': avatar,
    };
  }
}

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

class TokenInfo {
  final String tokenName;
  final String tokenValue;
  final bool isLogin;
  final dynamic loginId;
  final String loginType;
  final int tokenTimeout;
  final int sessionTimeout;
  final int tokenSessionTimeout;
  final int tokenActiveTimeout;
  final String loginDeviceType;
  final String tag;

  TokenInfo({
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
    required this.tag,
  });

  factory TokenInfo.fromJson(Map<String, dynamic> json) {
    return TokenInfo(
      tokenName: json['tokenName'] ?? '',
      tokenValue: json['tokenValue'] ?? '',
      isLogin: json['isLogin'] ?? false,
      loginId: json['loginId'],
      loginType: json['loginType'] ?? '',
      tokenTimeout: json['tokenTimeout'] ?? 0,
      sessionTimeout: json['sessionTimeout'] ?? 0,
      tokenSessionTimeout: json['tokenSessionTimeout'] ?? 0,
      tokenActiveTimeout: json['tokenActiveTimeout'] ?? 0,
      loginDeviceType: json['loginDeviceType'] ?? '',
      tag: json['tag'] ?? '',
    );
  }
}

class LoginData {
  final UserInfo userInfo;
  final TokenInfo tokenInfo;

  LoginData({
    required this.userInfo,
    required this.tokenInfo,
  });

  factory LoginData.fromJson(Map<String, dynamic> json) {
    return LoginData(
      userInfo: UserInfo.fromJson(json['userInfo'] ?? {}),
      tokenInfo: TokenInfo.fromJson(json['tokenInfo'] ?? {}),
    );
  }
}