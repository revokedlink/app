import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Exception thrown when an API call fails.
///
/// `code` mirrors the stable error codes emitted by the backend's
/// `appErrorResponse` helper (e.g. `link_password_required`,
/// `handshake_invalid`, `request_completed`). Code is empty when the
/// server returned a non-coded error (PocketBase's generic envelope).
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String code;
  final Map<String, dynamic>? data;

  ApiException(this.statusCode, this.message, {this.code = '', this.data});

  @override
  String toString() =>
      'ApiException($statusCode${code.isEmpty ? '' : ', $code'}): $message';
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

  Map<String, String> _buildHeaders([Map<String, String>? extra]) => {
    'Content-Type': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    if (extra != null) ...extra,
  };

  /// GET request.
  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: queryParams);
    final response = await _httpClient.get(uri, headers: _buildHeaders());
    return _handleResponse(response);
  }

  /// GET request returning both body and headers.
  Future<ApiResponse> getWithHeaders(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: queryParams);
    final response = await _httpClient.get(
      uri,
      headers: _buildHeaders(headers),
    );
    final decodedBody = _handleResponse(response);
    return ApiResponse(decodedBody, response.headers);
  }

  /// POST request.
  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final response = await postWithHeaders(path, body: body);
    return response.body;
  }

  /// POST request returning both body and headers.
  Future<ApiResponse> postWithHeaders(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient.post(
      uri,
      headers: _buildHeaders(headers),
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
      headers: _buildHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// DELETE request.
  Future<dynamic> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient.delete(uri, headers: _buildHeaders());
    if (response.statusCode == 204) return null;
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    String message = 'Request failed';
    String code = '';
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
        // Custom app-error envelope: {"code": "...", "message": "...", "status": int}
        if (decoded['code'] is String &&
            (decoded['code'] as String).isNotEmpty) {
          code = decoded['code'] as String;
        }
        if (decoded['message'] is String) {
          message = decoded['message'] as String;
        }
      }
    } catch (_) {
      // body wasn't JSON; keep generic message
    }

    throw ApiException(response.statusCode, message, code: code, data: data);
  }

  void dispose() {
    _httpClient.close();
  }
}
