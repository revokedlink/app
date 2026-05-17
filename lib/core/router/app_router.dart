import 'package:go_router/go_router.dart';

import '../../features/auth/store/auth_store.dart';
import '../../features/auth/view/login_screen.dart';
import '../../features/auth/view/register_screen.dart';
import '../../features/shell/view/app_shell.dart';
import '../../features/settings/view/settings_screen.dart';
import '../../features/vault/view/vault_screen.dart';
import '../../features/shares/view/shares_screen.dart';
import '../../features/shares/view/public_share_screen.dart';

abstract class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const vault = '/vault';
  static const shares = '/shares';
  static const settings = '/settings';
  static const share = '/share/:slug';
}

class AppRouter {
  AppRouter._();

  static GoRouter create(AuthStore authStore) {
    return GoRouter(
      initialLocation: AppRoutes.vault,
      redirect: (context, state) {
        final isLoggedIn = authStore.isAuthenticated;
        final isPublicRoute = state.matchedLocation.startsWith('/share/');
        final isAuthRoute =
            state.matchedLocation == AppRoutes.login ||
            state.matchedLocation == AppRoutes.register;

        if (!isLoggedIn && !isAuthRoute && !isPublicRoute) return AppRoutes.login;
        if (isLoggedIn && isAuthRoute) return AppRoutes.vault;
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: AppRoutes.share,
          builder: (context, state) {
            final slug = state.pathParameters['slug'] ?? '';
            return PublicShareScreen(shareSlug: slug);
          },
        ),
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.vault,
              pageBuilder: (context, state) {
                final editShareId = state.uri.queryParameters['editShareId'];
                final shareFilterId = state.uri.queryParameters['shareFilterId'];
                return NoTransitionPage(
                  child: VaultScreen(
                    editingShareId: editShareId,
                    shareFilterId: shareFilterId,
                  ),
                );
              },
            ),
            GoRoute(
              path: AppRoutes.shares,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: SharesScreen()),
            ),
            GoRoute(
              path: AppRoutes.settings,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: SettingsScreen()),
            ),
          ],
        ),
      ],
    );
  }
}
