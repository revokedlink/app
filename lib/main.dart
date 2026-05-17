import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import 'core/di/service_locator.dart';
import 'core/router/app_router.dart';
import 'features/auth/store/auth_store.dart';
import 'features/api_keys/store/api_keys_store.dart';
import 'features/settings/store/settings_store.dart';
import 'features/vault/store/vault_store.dart';
import 'features/shares/store/shares_store.dart';
import 'features/templates/store/templates_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServiceLocator.init();
  runApp(const RevokedApp());
}

class RevokedApp extends StatelessWidget {
  const RevokedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthStore>(create: (_) => ServiceLocator.authStore),
        Provider<VaultStore>(create: (_) => ServiceLocator.vaultStore),
        Provider<ApiKeysStore>(create: (_) => ServiceLocator.apiKeysStore),
        Provider<SettingsStore>(create: (_) => ServiceLocator.settingsStore),
        Provider<SharesStore>(create: (_) => ServiceLocator.sharesStore),
        Provider<TemplatesStore>(create: (_) => ServiceLocator.templatesStore),
      ],
      child: Observer(
        builder: (_) {
          final _ = ServiceLocator.authStore.isAuthenticated;
          final router = AppRouter.create(ServiceLocator.authStore);
          return ShadcnApp.router(
            title: 'Revoked',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(colorScheme: ColorSchemes.lightZinc),
            routerConfig: router,
          );
        },
      ),
    );
  }
}
