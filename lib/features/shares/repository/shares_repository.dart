import '../../../core/config/app_config.dart';
import '../../../core/models/link.dart';
import '../../../core/network/api_client.dart';

/// Repository for CRUD operations on the `links` collection.
///
/// Note: since migration 000018 ("extend_links") the standard PocketBase
/// list/view rules are owner-only — public viewers MUST use the dedicated
/// `/api/public/links/:slug` endpoints handled by [getPublicLinkProbe] and
/// [submitPublicLink].
class SharesRepository {
  final ApiClient _api;

  SharesRepository(this._api);

  String get _basePath =>
      '/api/collections/${AppConfig.linksCollection}/records';

  /// Fetch all shares for the current user's active workspace.
  Future<List<Link>> getAll({int page = 1, int perPage = 50}) async {
    final data = await _api.get(
      _basePath,
      queryParams: {
        'page': page.toString(),
        'perPage': perPage.toString(),
        'sort': '-created',
      },
    );
    final items = (data['items'] as List<dynamic>?) ?? [];
    return items.map((e) => Link.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Owner-side single fetch (sees viewCount, expiresAt, etc.).
  Future<Link> getById(String id) async {
    final data = await _api.get('$_basePath/$id');
    return Link.fromJson(data as Map<String, dynamic>);
  }

  /// Public probe — never returns the actual records, only the gates that
  /// must be satisfied (password? handshake? identity?). Implemented by
  /// `cmd/revoked/routes/publicLinks.go` GET handler.
  Future<Map<String, dynamic>> getPublicLinkProbe(String slug) async {
    final data = await _api.get('/api/public/links/$slug');
    return data as Map<String, dynamic>;
  }

  /// Public submission — supplies password / handshake / identity, returns
  /// the sanitized records + sections plus an updated `viewCount`. The
  /// server sets the `X-Handshake-Token` header on first handshake; the
  /// caller MUST persist it for any subsequent visit.
  ///
  /// Returns the decoded body and the response headers so the caller can
  /// extract `X-Handshake-Token`.
  Future<ApiResponse> submitPublicLink(
    String slug, {
    String? password,
    String? handshakeToken,
    String? identityId,
    String? challengeNonce,
    String? challengeSignature,
  }) async {
    return _api.postWithHeaders(
      '/api/public/links/$slug',
      body: {
        'password': ?password,
        'handshakeToken': ?handshakeToken,
        'identityId': ?identityId,
        'challengeNonce': ?challengeNonce,
        'challengeSignature': ?challengeSignature,
      },
    );
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
    String? identityId,
    String? password,
    DateTime? expiresAt,
    int? maxViews,
    bool requireHandshake = false,
  }) async {
    final data = await _api.post(
      _basePath,
      body: {
        'slug': slug,
        'label': label,
        'user': user,
        'workspace': workspace,
        'sections': sections,
        'records': records,
        'status': status,
        if (identityId != null && identityId.isNotEmpty) 'identity': identityId,
        if (password != null && password.isNotEmpty) 'password': password,
        if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
        if (maxViews != null && maxViews > 0) 'maxViews': maxViews,
        'requireHandshake': requireHandshake,
      },
    );
    return Link.fromJson(data as Map<String, dynamic>);
  }

  /// Update an existing share link (for changing status, label, password etc.).
  ///
  /// Pass an empty-string for `password` to clear it (hook will skip
  /// hashing). Pass `null` to leave it unchanged — the caller controls
  /// this by simply omitting the key from the body.
  Future<Link> update(String id, Map<String, dynamic> body) async {
    final data = await _api.patch('$_basePath/$id', body: body);
    return Link.fromJson(data as Map<String, dynamic>);
  }

  /// Check if a slug is taken database-wide.
  Future<bool> isSlugTaken(String slug) async {
    try {
      final data = await _api.get(
        _basePath,
        queryParams: {'filter': 'slug = "$slug"', 'page': '1', 'perPage': '1'},
      );
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
