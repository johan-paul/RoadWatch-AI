import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists authentication tokens and user data across sessions.
class SecureStorage {
  const SecureStorage._();
  static const SecureStorage instance = SecureStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Storage keys
  static const _kAccessToken  = 'rw_access_token';
  static const _kRefreshToken = 'rw_refresh_token';
  static const _kUserId       = 'rw_user_id';
  static const _kUserName     = 'rw_user_name';
  static const _kUserRole     = 'rw_user_role';
  static const _kUserPhone    = 'rw_user_phone';

  Future<void> saveAuthData({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String userName,
    required String role,
    String? phone,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessToken,  value: accessToken),
      _storage.write(key: _kRefreshToken, value: refreshToken),
      _storage.write(key: _kUserId,       value: userId),
      _storage.write(key: _kUserName,     value: userName),
      _storage.write(key: _kUserRole,     value: role),
      if (phone != null) _storage.write(key: _kUserPhone, value: phone),
    ]);
  }

  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessToken,  value: accessToken),
      _storage.write(key: _kRefreshToken, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken()  => _storage.read(key: _kAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _kRefreshToken);
  Future<String?> getUserId()       => _storage.read(key: _kUserId);
  Future<String?> getUserName()     => _storage.read(key: _kUserName);
  Future<String?> getUserRole()     => _storage.read(key: _kUserRole);
  Future<String?> getUserPhone()    => _storage.read(key: _kUserPhone);

  Future<void> clearAll() => _storage.deleteAll();

  /// Robust fallback — delete each known key individually.
  /// Used when deleteAll() throws (a known flutter_secure_storage Android quirk
  /// with encryptedSharedPreferences).
  Future<void> clearKeysIndividually() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kUserId),
      _storage.delete(key: _kUserName),
      _storage.delete(key: _kUserRole),
      _storage.delete(key: _kUserPhone),
    ]);
  }
}
