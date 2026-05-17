import 'package:mobx/mobx.dart';
import '../../../core/models/api_key.dart';
import '../repository/api_keys_repository.dart';

part 'api_keys_store.g.dart';

// ignore: library_private_types_in_public_api
class ApiKeysStore = _ApiKeysStore with _$ApiKeysStore;

abstract class _ApiKeysStore with Store {
  final ApiKeysRepository _repository;

  _ApiKeysStore(this._repository);

  @observable
  ObservableList<ApiKey> apiKeys = ObservableList<ApiKey>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String? lastCreatedPlainToken;

  @computed
  int get keyCount => apiKeys.length;

  @action
  Future<void> loadApiKeys() async {
    isLoading = true;
    errorMessage = null;
    try {
      final result = await _repository.getAll();
      apiKeys = ObservableList.of(result);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> createApiKey({
    required String label,
    required String user,
    required String workspace,
    required List<String> scopes,
  }) async {
    isLoading = true;
    errorMessage = null;
    try {
      final key = await _repository.create(
        label: label,
        user: user,
        workspace: workspace,
        scopes: scopes,
      );
      apiKeys.insert(0, key);
      lastCreatedPlainToken = key.plainToken;
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> deleteApiKey(String id) async {
    try {
      await _repository.delete(id);
      apiKeys.removeWhere((k) => k.id == id);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    }
  }

  @action
  void clearLastToken() {
    lastCreatedPlainToken = null;
  }

  @action
  void clearError() {
    errorMessage = null;
  }
}
