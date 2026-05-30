import '../../../core/models/user_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../models/auth_models.dart';

class AuthRepository {
  const AuthRepository(this._client);
  final ApiClient _client;

  /// Step 1 — check if a phone number has an account.
  Future<PhoneCheckResult> checkPhone(String phone) async {
    final res = await _client.post(
      ApiConstants.checkPhone,
      data: {'phone_number': phone},
    );
    final data = res.data as Map<String, dynamic>;
    return PhoneCheckResult(
      status: data['status'] as String,
      role:   data['role']   as String?,
    );
  }

  /// Step 2a — existing user logs in with Firebase OTP ID token.
  Future<AuthResponse> login(String firebaseIdToken) async {
    final res = await _client.post(
      ApiConstants.login,
      data: {'firebase_id_token': firebaseIdToken},
    );
    return AuthResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// Step 2b — new citizen registers.
  Future<AuthResponse> register({
    required String phone,
    required String name,
    required String firebaseIdToken,
  }) async {
    final res = await _client.post(
      ApiConstants.register,
      data: {
        'phone_number':      phone,
        'name':              name,
        'firebase_id_token': firebaseIdToken,
      },
    );
    return AuthResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// Silently refresh tokens — called by the interceptor.
  Future<AuthResponse> refreshTokens(String refreshToken) async {
    final res = await _client.post(
      ApiConstants.refresh,
      data: {'refresh_token': refreshToken},
    );
    return AuthResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// Revoke refresh token on the server.
  Future<void> logout(String refreshToken) async {
    try {
      await _client.post(
        ApiConstants.logout,
        data: {'refresh_token': refreshToken},
      );
    } catch (_) {
      // Best-effort — always clear local state even if server fails.
    }
  }

  Future<void> registerFcmToken(String token) async {
    try {
      await _client.post(
        ApiConstants.citizenFcmToken,
        data: {'fcm_token': token},
      );
    } catch (_) {
      // Non-critical
    }
  }
}

/// Public response returned by login / register / refreshTokens.
class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final UserModel user;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        accessToken:  json['access_token']  as String,
        refreshToken: json['refresh_token'] as String,
        user: UserModel(
          id:          json['user_id'] as String,
          phone:       '',
          name:        json['name']    as String,
          role:        (json['role']   as String),
          trustScore:  100,
          isSuspended: false,
        ),
      );
}
