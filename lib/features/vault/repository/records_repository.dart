import '../../../core/config/app_config.dart';
import '../../../core/models/record.dart' as models;
import '../../../core/models/section.dart';
import '../../../core/network/api_client.dart';

/// Repository for CRUD operations on the `records` collection.
class VaultRepository {
  final ApiClient _api;

  VaultRepository(this._api);

  String get _basePath =>
      '/api/collections/${AppConfig.recordsCollection}/records';

  /// Fetch all records for the current user's active workspace.
  Future<List<models.Record>> getAll({int page = 1, int perPage = 50}) async {
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
        .map((e) => models.Record.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create a new record.
  Future<models.Record> create({
    required String key,
    required String value,
    required String label,
    required String type,
    required String format,
    required String user,
    required String workspace,
  }) async {
    final data = await _api.post(
      _basePath,
      body: {
        'key': key,
        'value': value,
        'label': label,
        'type': type,
        'format': format,
        'user': user,
        'workspace': workspace,
      },
    );
    return models.Record.fromJson(data as Map<String, dynamic>);
  }

  /// Update an existing record.
  Future<models.Record> update(String id, Map<String, dynamic> updates) async {
    final data = await _api.patch('$_basePath/$id', body: updates);
    return models.Record.fromJson(data as Map<String, dynamic>);
  }

  /// Delete a record.
  Future<void> delete(String id) async {
    await _api.delete('$_basePath/$id');
  }

  // --- Sections ---

  String get _sectionsPath =>
      '/api/collections/${AppConfig.sectionsCollection}/records';

  Future<List<Section>> getSections({int page = 1, int perPage = 50}) async {
    final data = await _api.get(
      _sectionsPath,
      queryParams: {
        'page': page.toString(),
        'perPage': perPage.toString(),
        'sort': '-created',
        'expand': 'records',
      },
    );
    final items = (data['items'] as List<dynamic>?) ?? [];
    return items
        .map((e) => Section.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Section> createSection({
    required String key,
    required String name,
    required List<String> records,
    required String user,
    required String workspace,
  }) async {
    final data = await _api.post(
      _sectionsPath,
      body: {
        'key': key,
        'name': name,
        'records': records,
        'user': user,
        'workspace': workspace,
      },
    );
    return Section.fromJson(data as Map<String, dynamic>);
  }

  Future<Section> updateSection(String id, Map<String, dynamic> updates) async {
    final data = await _api.patch('$_sectionsPath/$id', body: updates);
    return Section.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteSection(String id) async {
    await _api.delete('$_sectionsPath/$id');
  }
}
