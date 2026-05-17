import 'package:mobx/mobx.dart';
import '../../../core/models/workspace.dart';
import '../../../core/models/workspace_member.dart';
import '../repository/settings_repository.dart';

part 'settings_store.g.dart';

// ignore: library_private_types_in_public_api
class SettingsStore = _SettingsStore with _$SettingsStore;

abstract class _SettingsStore with Store {
  final SettingsRepository _repository;

  _SettingsStore(this._repository);

  @observable
  ObservableList<Workspace> workspaces = ObservableList<Workspace>();

  @observable
  ObservableList<WorkspaceMember> memberships =
      ObservableList<WorkspaceMember>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @computed
  int get workspaceCount => workspaces.length;

  @action
  Future<void> loadWorkspaces(String userId) async {
    isLoading = true;
    errorMessage = null;
    try {
      final results = await _repository.getUserWorkspaces(userId);
      workspaces = ObservableList.of(results);

      final memberResults = await _repository.getUserMemberships(userId);
      memberships = ObservableList.of(memberResults);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> switchWorkspace(String userId, String workspaceId) async {
    try {
      // Find the membership to get the role
      final membership = memberships.firstWhere(
        (m) => m.workspace == workspaceId,
      );
      await _repository.switchWorkspace(userId, workspaceId, membership.role);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    }
  }

  /// Get the role for a specific workspace.
  String getRoleForWorkspace(String workspaceId) {
    try {
      return memberships.firstWhere((m) => m.workspace == workspaceId).role;
    } catch (_) {
      return 'member';
    }
  }

  @action
  Future<bool> createWorkspace({
    required String name,
    required String slug,
    required String userId,
  }) async {
    isLoading = true;
    errorMessage = null;
    try {
      final ws = await _repository.createWorkspace(name, slug);
      workspaces.add(ws);

      // Switch active workspace to the new one
      await _repository.switchWorkspace(userId, ws.id, 'admin');

      // Reload workspaces list
      await loadWorkspaces(userId);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  void clearError() {
    errorMessage = null;
  }
}
