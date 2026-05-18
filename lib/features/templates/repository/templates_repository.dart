import '../../../core/config/app_config.dart';
import '../../../core/models/template.dart';
import '../../../core/network/api_client.dart';

/// Repository for CRUD operations on the `templates` collection.
class TemplatesRepository {
  final ApiClient _api;

  TemplatesRepository(this._api);

  String get _basePath =>
      '/api/collections/${AppConfig.templatesCollection}/records';

  /// Fetch all templates for the current active workspace.
  Future<List<Template>> getAll({
    required String workspaceId,
    int page = 1,
    int perPage = 50,
  }) async {
    final data = await _api.get(
      _basePath,
      queryParams: {
        'page': page.toString(),
        'perPage': perPage.toString(),
        'filter': 'workspace = "$workspaceId"',
        'sort': '-created',
      },
    );
    final items = (data['items'] as List<dynamic>?) ?? [];
    return items
        .map((e) => Template.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create a new template.
  Future<Template> create({
    required String name,
    required Map<String, dynamic> schema,
    required String workspaceId,
  }) async {
    final data = await _api.post(
      _basePath,
      body: {'name': name, 'schema': schema, 'workspace': workspaceId},
    );
    return Template.fromJson(data as Map<String, dynamic>);
  }

  /// Update an existing template.
  Future<Template> update(
    String id, {
    required String name,
    required Map<String, dynamic> schema,
  }) async {
    final data = await _api.patch(
      '$_basePath/$id',
      body: {'name': name, 'schema': schema},
    );
    return Template.fromJson(data as Map<String, dynamic>);
  }

  /// Delete a template.
  Future<void> delete(String id) async {
    await _api.delete('$_basePath/$id');
  }
}
