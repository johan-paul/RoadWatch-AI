import '../../../core/models/user_model.dart';

/// Result of /auth/check-phone
class PhoneCheckResult {
  const PhoneCheckResult({required this.status, this.role});
  final String status; // 'new' | 'citizen' | 'officer' | 'suspended'
  final String? role;

  bool get isNew       => status == 'new';
  bool get isSuspended => status == 'suspended';
  bool get isExisting  => status == 'citizen' || status == 'officer';
}

/// Arguments passed to the OTP screen
class OtpArgs {
  const OtpArgs({
    required this.phone,
    required this.mode,
    this.name,
  });
  final String phone;
  final OtpMode mode;
  final String? name; // only for register mode
}

enum OtpMode { login, register }

/// Immutable auth state held by AuthNotifier.
class AuthState {
  const AuthState({
    this.isLoading = false,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.error,
  });

  final bool isLoading;
  final UserModel? user;
  final String? accessToken;
  final String? refreshToken;
  final String? error;

  bool get isAuthenticated => accessToken != null && user != null;

  AuthState copyWith({
    bool? isLoading,
    UserModel? user,
    String? accessToken,
    String? refreshToken,
    String? error,
    bool clearError = false,
    bool clearUser  = false,
  }) =>
      AuthState(
        isLoading:    isLoading    ?? this.isLoading,
        user:         clearUser    ? null : (user    ?? this.user),
        accessToken:  clearUser    ? null : (accessToken  ?? this.accessToken),
        refreshToken: clearUser    ? null : (refreshToken ?? this.refreshToken),
        error:        clearError   ? null : (error   ?? this.error),
      );
}
