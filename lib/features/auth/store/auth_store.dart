import 'package:mobx/mobx.dart';
import '../../../core/models/user.dart';
import '../repository/auth_repository.dart';

part 'auth_store.g.dart';

// ignore: library_private_types_in_public_api
class AuthStore = _AuthStore with _$AuthStore;

abstract class _AuthStore with Store {
  final AuthRepository _repository;

  _AuthStore(this._repository);

  @observable
  User? currentUser;

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  bool isInitialized = false;

  @computed
  bool get isAuthenticated => currentUser != null;

  @computed
  String get userEmail => currentUser?.email ?? '';

  @computed
  String get userId => currentUser?.id ?? '';

  @computed
  String? get activeWorkspace => currentUser?.activeWorkspace;

  @action
  Future<void> initialize() async {
    isLoading = true;
    errorMessage = null;
    try {
      currentUser = await _repository.tryRestoreSession();
    } catch (e) {
      currentUser = null;
    } finally {
      isLoading = false;
      isInitialized = true;
    }
  }

  @action
  Future<bool> login(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    try {
      currentUser = await _repository.login(email, password);
      return true;
    } catch (e) {
      errorMessage = _parseError(e);
      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> register(String email, String password, String passwordConfirm) async {
    isLoading = true;
    errorMessage = null;
    try {
      await _repository.register(email, password, passwordConfirm);
      // Auto-login after registration
      currentUser = await _repository.login(email, password);
      return true;
    } catch (e) {
      errorMessage = _parseError(e);
      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> logout() async {
    await _repository.logout();
    currentUser = null;
  }

  @action
  void clearError() {
    errorMessage = null;
  }

  String _parseError(dynamic e) {
    if (e.toString().contains('Failed to authenticate')) {
      return 'Invalid email or password';
    }
    if (e.toString().contains('validation_')) {
      return 'Please check your input and try again';
    }
    return e.toString().replaceAll('ApiException', '').replaceAll('Exception:', '').trim();
  }
}
