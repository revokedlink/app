import '../../features/vault/repository/records_repository.dart';
import '../../features/vault/store/vault_store.dart';
import '../../features/shares/repository/shares_repository.dart';
import '../../features/shares/store/shares_store.dart';
import '../../features/templates/repository/templates_repository.dart';
import '../../features/templates/store/templates_store.dart';
import '../network/api_client.dart';
import '../../features/auth/repository/auth_repository.dart';
import '../../features/auth/store/auth_store.dart';
import '../../features/api_keys/repository/api_keys_repository.dart';
import '../../features/api_keys/store/api_keys_store.dart';
import '../../features/settings/repository/settings_repository.dart';
import '../../features/settings/store/settings_store.dart';

/// Simple service locator for dependency injection.
/// Initializes all singletons in the correct order.
class ServiceLocator {
  ServiceLocator._();

  static late final ApiClient apiClient;
  static late final AuthRepository authRepository;
  static late final VaultRepository vaultRepository;
  static late final ApiKeysRepository apiKeysRepository;
  static late final SettingsRepository settingsRepository;
  static late final SharesRepository sharesRepository;
  static late final TemplatesRepository templatesRepository;

  static late final AuthStore authStore;
  static late final VaultStore vaultStore;
  static late final ApiKeysStore apiKeysStore;
  static late final SettingsStore settingsStore;
  static late final SharesStore sharesStore;
  static late final TemplatesStore templatesStore;

  static Future<void> init() async {
    // Core
    apiClient = ApiClient();

    // Repositories
    authRepository = AuthRepository(apiClient);
    vaultRepository = VaultRepository(apiClient);
    apiKeysRepository = ApiKeysRepository(apiClient);
    settingsRepository = SettingsRepository(apiClient);
    sharesRepository = SharesRepository(apiClient);
    templatesRepository = TemplatesRepository(apiClient);

    // Stores
    authStore = AuthStore(authRepository);
    vaultStore = VaultStore(vaultRepository);
    apiKeysStore = ApiKeysStore(apiKeysRepository);
    settingsStore = SettingsStore(settingsRepository);
    sharesStore = SharesStore(sharesRepository);
    templatesStore = TemplatesStore(templatesRepository);

    // Try to restore previous session
    await authStore.initialize();
  }
}
