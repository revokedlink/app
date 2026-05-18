import '../../../core/config/app_config.dart';
import '../../../core/models/api_key.dart';
import '../../../core/network/api_client.dart';

/// Repository for CRUD operations on the `apiKeys` collection.
class ApiKeysRepository {
  final ApiClient _api;

  ApiKeysRepository(this._api);

  String get _basePath =>
      '/api/collections/${AppConfig.apiKeysCollection}/records';

  /// Fetch all API keys for the current user's active workspace.
  Future<List<ApiKey>> getAll({int page = 1, int perPage = 50}) async {
    final data = await _api.get(
      _basePath,
      queryParams: {
        'page': page.toString(),
        'perPage': perPage.toString(),
        'sort': '-created',
      },
    );
    final items = (data['items'] as List<dynamic>?) ?? [];
    return items
        .map((e) => ApiKey.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create a new API key.
  Future<ApiKey> create({
    required String label,
    required String user,
    required String workspace,
    required List<String> scopes,
  }) async {
    final response = await _api.postWithHeaders(
      _basePath,
      body: {
        'label': label,
        'user': user,
        'workspace': workspace,
        'scopes': scopes,
      },
    );

    final plainToken =
        response.headers['x-plain-token'] ?? response.headers['X-Plain-Token'];
    return ApiKey.fromJson(
      response.body as Map<String, dynamic>,
      plainToken: plainToken,
    );
  }

  /// Delete an API key.
  Future<void> delete(String id) async {
    await _api.delete('$_basePath/$id');
  }
}
