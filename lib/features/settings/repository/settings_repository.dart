import '../../../core/config/app_config.dart';
import '../../../core/models/workspace.dart';
import '../../../core/models/workspace_member.dart';
import '../../../core/network/api_client.dart';

/// Repository for workspace operations.
class SettingsRepository {
  final ApiClient _api;

  SettingsRepository(this._api);

  /// Fetch workspace memberships for the current user.
  Future<List<WorkspaceMember>> getUserMemberships(String userId) async {
    final data = await _api.get(
      '/api/collections/${AppConfig.workspaceMembersCollection}/records',
      queryParams: {'filter': 'user = "$userId"', 'sort': '-created'},
    );
    final items = (data['items'] as List<dynamic>?) ?? [];
    return items
        .map((e) => WorkspaceMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a workspace by ID.
  Future<Workspace> getWorkspace(String id) async {
    final data = await _api.get(
      '/api/collections/${AppConfig.workspacesCollection}/records/$id',
    );
    return Workspace.fromJson(data as Map<String, dynamic>);
  }

  /// Fetch all workspaces the user belongs to.
  Future<List<Workspace>> getUserWorkspaces(String userId) async {
    final memberships = await getUserMemberships(userId);
    final workspaces = <Workspace>[];
    for (final membership in memberships) {
      try {
        final ws = await getWorkspace(membership.workspace);
        workspaces.add(ws);
      } catch (_) {
        // Skip workspaces that fail to load
      }
    }
    return workspaces;
  }

  /// Switch the user's active workspace.
  Future<void> switchWorkspace(
    String userId,
    String workspaceId,
    String role,
  ) async {
    await _api.patch(
      '/api/collections/${AppConfig.usersCollection}/records/$userId',
      body: {'activeWorkspace': workspaceId, 'activeRole': role},
    );
  }

  /// Create a new workspace.
  Future<Workspace> createWorkspace(String name, String slug) async {
    final data = await _api.post(
      '/api/collections/${AppConfig.workspacesCollection}/records',
      body: {'name': name, 'slug': slug},
    );
    return Workspace.fromJson(data as Map<String, dynamic>);
  }

  /// Add a user to a workspace.
  Future<WorkspaceMember> addWorkspaceMember(
    String workspaceId,
    String userId,
    String role,
  ) async {
    final data = await _api.post(
      '/api/collections/${AppConfig.workspaceMembersCollection}/records',
      body: {'workspace': workspaceId, 'user': userId, 'role': role},
    );
    return WorkspaceMember.fromJson(data as Map<String, dynamic>);
  }
}
