import '../../../core/config/app_config.dart';
import '../../../core/models/link.dart';
import '../../../core/network/api_client.dart';

/// Repository for CRUD operations on the `links` collection.
class SharesRepository {
  final ApiClient _api;

  SharesRepository(this._api);

  String get _basePath => '/api/collections/${AppConfig.linksCollection}/records';

  /// Fetch all shares for the current user's active workspace.
  Future<List<Link>> getAll({int page = 1, int perPage = 50}) async {
    final data = await _api.get(_basePath, queryParams: {
      'page': page.toString(),
      'perPage': perPage.toString(),
      'sort': '-created',
    });
    final items = (data['items'] as List<dynamic>?) ?? [];
    return items.map((e) => Link.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Fetch a single link by unique slug (including relation expansions for sections and records).
  /// This is used on the public unauthenticated view route.
  Future<Map<String, dynamic>> getPublicLinkDetails(String slug) async {
    final data = await _api.get(_basePath, queryParams: {
      'filter': 'slug = "$slug"',
      'expand': 'sections,records,sections.records',
    });
    final items = (data['items'] as List<dynamic>?) ?? [];
    if (items.isEmpty) {
      throw Exception('Link not found');
    }
    return items.first as Map<String, dynamic>;
  }

  /// Create a new share link.
  Future<Link> create({
    required String slug,
    required String label,
    required String user,
    required String workspace,
    required List<String> sections,
    required List<String> records,
    String status = 'active',
  }) async {
    final data = await _api.post(_basePath, body: {
      'slug': slug,
      'label': label,
      'user': user,
      'workspace': workspace,
      'sections': sections,
      'records': records,
      'status': status,
    });
    return Link.fromJson(data as Map<String, dynamic>);
  }

  /// Update an existing share link (for changing active/paused/revoked status or selections).
  Future<Link> update(String id, Map<String, dynamic> body) async {
    final data = await _api.patch('$_basePath/$id', body: body);
    return Link.fromJson(data as Map<String, dynamic>);
  }

  /// Check if a slug is taken database-wide.
  Future<bool> isSlugTaken(String slug) async {
    try {
      final data = await _api.get(_basePath, queryParams: {
        'filter': 'slug = "$slug"',
        'page': '1',
        'perPage': '1',
      });
      final items = (data['items'] as List<dynamic>?) ?? [];
      return items.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Generate a unique alternative slug by adding counter suffixes.
  Future<String> generateAlternativeSlug(String baseSlug) async {
    int counter = 1;
    while (true) {
      final candidate = '${baseSlug}_$counter';
      final taken = await isSlugTaken(candidate);
      if (!taken) {
        return candidate;
      }
      counter++;
    }
  }

  /// Delete a share link.
  Future<void> delete(String id) async {
    await _api.delete('$_basePath/$id');
  }
}
