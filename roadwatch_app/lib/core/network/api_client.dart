import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => 'AuthException: $message';
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Central Dio HTTP client.
/// • Attaches Bearer token on every request.
/// • On 401: tries to silently refresh; if refresh fails, calls [onSessionExpired].
class ApiClient {
  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 120), // AI inference can take up to 90s on first run
        sendTimeout:    const Duration(seconds: 60),  // image upload
        headers: {'Accept': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest:  _attachToken,
        onError:    _handleError,
      ),
    );
  }

  late final Dio _dio;
  final _storage = SecureStorage.instance;

  /// Called when both access-token and refresh-token are invalid.
  /// Typically, the auth provider sets this to trigger a logout.
  void Function()? onSessionExpired;

  // ── Interceptors ──────────────────────────────────────────────────────────

  Future<void> _attachToken(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _handleError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      final retried = await _tryRefreshAndRetry(err.requestOptions);
      if (retried != null) {
        handler.resolve(retried);
        return;
      }
      onSessionExpired?.call();
    }
    handler.next(_toDioException(err));
  }

  Future<Response?> _tryRefreshAndRetry(RequestOptions original) async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) return null;

      // Use a fresh Dio instance to avoid interceptor loops
      final res = await Dio().post(
        '${ApiConstants.baseUrl}${ApiConstants.refresh}',
        data: {'refresh_token': refreshToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final newAccess  = res.data['access_token']  as String;
      final newRefresh = res.data['refresh_token'] as String;

      await _storage.updateTokens(
        accessToken:  newAccess,
        refreshToken: newRefresh,
      );

      // Retry original request with the new token
      original.headers['Authorization'] = 'Bearer $newAccess';
      return await _dio.fetch(original);
    } catch (_) {
      return null;
    }
  }

  DioException _toDioException(DioException err) => err;

  // ── Public helpers ────────────────────────────────────────────────────────

  Future<Response> get(
    String path, {
    Map<String, dynamic>? query,
    Options? options,
  }) =>
      _request(() => _dio.get(path, queryParameters: query, options: options));

  Future<Response> post(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      _request(() => _dio.post(path, data: data, options: options));

  Future<Response> patch(
    String path, {
    dynamic data,
  }) =>
      _request(() => _dio.patch(path, data: data));

  Future<Response> postForm(String path, FormData formData) =>
      _request(() => _dio.post(
            path,
            data: formData,
            options: Options(
              contentType: 'multipart/form-data',
              receiveTimeout: const Duration(seconds: 180), // AI + upload
              sendTimeout:    const Duration(seconds: 90),
            ),
          ));

  Future<Response> _request(Future<Response> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      final msg = detail is String
          ? detail
          : (detail is List ? detail.first['msg'] : e.message);
      throw ApiException(msg ?? 'Something went wrong.', statusCode: e.response?.statusCode);
    }
  }
}
