import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/firebase_messaging_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/auth_repository.dart';
import '../models/auth_models.dart';

// ── Singleton providers ───────────────────────────────────────────────────────

// No circular dep: apiClientProvider creates a bare client.
// The onSessionExpired callback is wired inside AuthNotifier below.
final apiClientProvider = Provider<ApiClient>((_) => ApiClient());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

// ── Auth state ────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo, ApiClient client)
      : super(const AuthState(isLoading: true)) {
    // Wire session-expiry callback here to avoid a circular provider dependency.
    client.onSessionExpired = forceLogout;
    _initialize();
  }

  final AuthRepository _repo;
  final _storage = SecureStorage.instance;

  // ── Startup: restore session ──────────────────────────────────────────────

  Future<void> _initialize() async {
    try {
      final token  = await _storage.getAccessToken();
      final userId = await _storage.getUserId();
      final name   = await _storage.getUserName();
      final role   = await _storage.getUserRole();
      final phone  = await _storage.getUserPhone();

      if (token != null && userId != null && name != null && role != null) {
        state = AuthState(
          accessToken:  token,
          refreshToken: await _storage.getRefreshToken(),
          user: UserModel(
            id:          userId,
            phone:       phone ?? '',
            name:        name,
            role:        role,
            trustScore:  100,
            isSuspended: false,
          ),
        );
        return;
      }
    } catch (_) {}
    state = const AuthState();
  }

  // ── Phone check (Step 1 of auth flow) ────────────────────────────────────

  Future<PhoneCheckResult> checkPhone(String phone) =>
      _repo.checkPhone(phone);

  // ── Login (Step 2a — existing user) ──────────────────────────────────────

  Future<void> login({
    required String firebaseIdToken,
    required String phone,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _repo.login(firebaseIdToken);
      await _apply(res, phone: phone);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Register (Step 2b — new citizen only) ────────────────────────────────

  Future<void> register({
    required String phone,
    required String name,
    required String firebaseIdToken,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _repo.register(
        phone:           phone,
        name:            name,
        firebaseIdToken: firebaseIdToken,
      );
      await _apply(res, phone: phone);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    final refresh = state.refreshToken;

    // 1. Clear persisted storage FIRST so a reopen can never restore the session.
    try {
      await _storage.clearAll();
    } catch (_) {
      await _storage.clearKeysIndividually();
    }

    // 2. Fire server-side logout in the background — don't block the UI on it.
    if (refresh != null) {
      _repo.logout(refresh); // intentionally not awaited
    }

    // 3. Flip in-memory state LAST. This triggers the router redirect.
    state = const AuthState();
  }

  /// Called by the API interceptor when tokens are permanently invalid.
  void forceLogout() {
    state = const AuthState(
      error: 'Your session has expired. Please log in again.',
    );
    _storage.clearAll();
  }

  void clearError() => state = state.copyWith(clearError: true);

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _apply(AuthResponse res, {required String phone}) async {
    final user = UserModel(
      id:          res.user.id,
      phone:       phone,
      name:        res.user.name,
      role:        res.user.role,
      trustScore:  res.user.trustScore,
      isSuspended: res.user.isSuspended,
      avatarUrl:   res.user.avatarUrl,
    );

    await _storage.saveAuthData(
      accessToken:  res.accessToken,
      refreshToken: res.refreshToken,
      userId:       user.id,
      userName:     user.name,
      role:         user.role,
      phone:        phone,
    );

    state = AuthState(
      accessToken:  res.accessToken,
      refreshToken: res.refreshToken,
      user:         user,
    );

    // Register FCM token with the backend after successful login/register
    _registerFcmToken(res.accessToken);
  }

  /// Fetch the device's FCM token and send it to the backend.
  Future<void> _registerFcmToken(String accessToken) async {
    try {
      final messaging = FirebaseMessagingService.instance;
      final token = await messaging.getToken();
      if (token == null) return;
      await _repo.registerFcmToken(token);
    } catch (e) {
      // Non-critical — swallow silently
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(apiClientProvider),
  );
});
