import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Exception thrown when an API call fails.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Represents an API response with both the decoded body and raw headers.
class ApiResponse {
  final dynamic body;
  final Map<String, String> headers;

  ApiResponse(this.body, this.headers);
}

/// Low-level HTTP client for PocketBase API.
/// Handles auth token injection and response parsing.
class ApiClient {
  final http.Client _httpClient;
  static const _tokenKey = 'pb_auth_token';
  static const _userKey = 'pb_user_data';

  String? _authToken;
  Map<String, dynamic>? _userData;

  ApiClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  String get baseUrl => AppConfig.baseUrl;
  String? get authToken => _authToken;
  Map<String, dynamic>? get userData => _userData;
  bool get isAuthenticated => _authToken != null && _authToken!.isNotEmpty;

  /// Load persisted auth state from SharedPreferences.
  Future<void> loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      _userData = jsonDecode(userJson) as Map<String, dynamic>;
    }
  }

  /// Persist auth state to SharedPreferences.
  Future<void> saveAuthState(String token, Map<String, dynamic> user) async {
    _authToken = token;
    _userData = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  /// Clear auth state.
  Future<void> clearAuthState() async {
    _authToken = null;
    _userData = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  /// GET request.
  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final response = await _httpClient.get(uri, headers: _headers);
    return _handleResponse(response);
  }

  /// POST request.
  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final response = await postWithHeaders(path, body: body);
    return response.body;
  }

  /// POST request returning both body and headers.
  Future<ApiResponse> postWithHeaders(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient.post(
      uri,
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    final decodedBody = _handleResponse(response);
    return ApiResponse(decodedBody, response.headers);
  }

  /// PATCH request.
  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient.patch(
      uri,
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// DELETE request.
  Future<dynamic> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient.delete(uri, headers: _headers);
    if (response.statusCode == 204) return null;
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    String message = 'Request failed';
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      message = body['message'] as String? ?? message;
    } catch (_) {}

    throw ApiException(response.statusCode, message);
  }

  void dispose() {
    _httpClient.close();
  }
}
