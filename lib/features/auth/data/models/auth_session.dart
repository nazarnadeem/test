import 'user_model.dart';

/// Active authentication session model.
class AuthSession {
  final UserModel user;
  final String token;
  final String refreshToken;
  final DateTime expiresAt;
  final bool rememberMe;

  const AuthSession({
    required this.user,
    required this.token,
    required this.refreshToken,
    required this.expiresAt,
    this.rememberMe = true,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'token': token,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt.toIso8601String(),
      'rememberMe': rememberMe,
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      token: json['token'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      rememberMe: json['rememberMe'] as bool? ?? true,
    );
  }
}
