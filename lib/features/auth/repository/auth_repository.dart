import '../../../core/models/user.dart';
import '../../../core/network/api_client.dart';
import '../../../core/config/app_config.dart';

/// Repository for authentication operations against PocketBase.
class AuthRepository {
  final ApiClient _api;

  AuthRepository(this._api);

  /// Authenticate with email and password.
  Future<User> login(String email, String password) async {
    final data = await _api.post(
      '/api/collections/${AppConfig.usersCollection}/auth-with-password',
      body: {'identity': email, 'password': password},
    );

    final token = data['token'] as String;
    final record = data['record'] as Map<String, dynamic>;
    await _api.saveAuthState(token, record);
    return User.fromJson(record);
  }

  /// Register a new user account.
  Future<User> register(String email, String password, String passwordConfirm) async {
    final data = await _api.post(
      '/api/collections/${AppConfig.usersCollection}/records',
      body: {
        'email': email,
        'password': password,
        'passwordConfirm': passwordConfirm,
      },
    );
    return User.fromJson(data as Map<String, dynamic>);
  }

  /// Refresh the current auth token and get updated user data.
  Future<User?> refreshAuth() async {
    try {
      final data = await _api.post(
        '/api/collections/${AppConfig.usersCollection}/auth-refresh',
      );
      final token = data['token'] as String;
      final record = data['record'] as Map<String, dynamic>;
      await _api.saveAuthState(token, record);
      return User.fromJson(record);
    } catch (_) {
      return null;
    }
  }

  /// Log out the current user.
  Future<void> logout() async {
    await _api.clearAuthState();
  }

  /// Try to restore session from persisted auth state.
  Future<User?> tryRestoreSession() async {
    await _api.loadAuthState();
    if (!_api.isAuthenticated) return null;
    return refreshAuth();
  }
}
