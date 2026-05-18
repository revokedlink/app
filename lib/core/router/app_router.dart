import 'package:go_router/go_router.dart';

import '../../features/auth/store/auth_store.dart';
import '../../features/auth/view/login_screen.dart';
import '../../features/auth/view/register_screen.dart';
import '../../features/shell/view/app_shell.dart';
import '../../features/settings/view/settings_screen.dart';
import '../../features/vault/view/vault_screen.dart';
import '../../features/shares/view/shares_screen.dart';
import '../../features/shares/view/public_share_screen.dart';
import '../../features/api_keys/view/api_keys_screen.dart';
import '../../features/templates/view/templates_screen.dart';
import '../../features/requests/view/inbox_screen.dart';
import '../../features/requests/view/public_request_screen.dart';

abstract class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const vault = '/vault';
  static const inbox = '/inbox';
  static const shares = '/shares';
  static const settings = '/settings';
  static const apiKeys = '/settings/api-keys';
  static const templates = '/settings/templates';
  static const share = '/share/:slug';
  static const request = '/request/:slug';

  // Legacy aliases — kept so any deep-links or bookmarks still resolve
  static const requests = '/requests';
  static const connections = '/connections';
  static const receivedVault = '/received-vault';
}

class AppRouter {
  AppRouter._();

  static GoRouter create(AuthStore authStore) {
    return GoRouter(
      initialLocation: AppRoutes.vault,
      redirect: (context, state) {
        final isLoggedIn = authStore.isAuthenticated;
        final isPublicRoute =
            state.matchedLocation.startsWith('/share/') ||
            state.matchedLocation.startsWith('/request/') ||
            state.uri.path.startsWith('/share/') ||
            state.uri.path.startsWith('/request/');
        final isAuthRoute =
            state.matchedLocation == AppRoutes.login ||
            state.matchedLocation == AppRoutes.register;

        if (!isLoggedIn && !isAuthRoute && !isPublicRoute) {
          return AppRoutes.login;
        }
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
        GoRoute(
          path: AppRoutes.request,
          builder: (context, state) {
            final slug = state.pathParameters['slug'] ?? '';
            return PublicRequestScreen(requestSlug: slug);
          },
        ),
        // Fallbacks for public URLs missing slugs
        GoRoute(
          path: '/request',
          redirect: (context, state) => AppRoutes.inbox,
        ),
        GoRoute(path: '/share', redirect: (context, state) => AppRoutes.shares),
        // Legacy route redirects
        GoRoute(
          path: AppRoutes.requests,
          redirect: (context, state) => AppRoutes.inbox,
        ),
        GoRoute(
          path: AppRoutes.connections,
          redirect: (context, state) => AppRoutes.inbox,
        ),
        GoRoute(
          path: AppRoutes.receivedVault,
          redirect: (context, state) => AppRoutes.inbox,
        ),
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.vault,
              pageBuilder: (context, state) {
                final editShareId = state.uri.queryParameters['editShareId'];
                final shareFilterId =
                    state.uri.queryParameters['shareFilterId'];
                return NoTransitionPage(
                  child: VaultScreen(
                    editingShareId: editShareId,
                    shareFilterId: shareFilterId,
                  ),
                );
              },
            ),
            GoRoute(
              path: AppRoutes.inbox,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: InboxScreen()),
            ),
            // Legacy /inbox/create — old full-screen flow replaced by a
            // multi-step bottom sheet opened from the Inbox header.
            GoRoute(
              path: '/inbox/create',
              redirect: (_, _) => AppRoutes.inbox,
            ),
            GoRoute(
              path: AppRoutes.shares,
              pageBuilder: (context, state) {
                final filterSlug = state.uri.queryParameters['filterSlug'];
                return NoTransitionPage(
                  child: SharesScreen(filterSlug: filterSlug),
                );
              },
            ),
            GoRoute(
              path: AppRoutes.settings,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: SettingsScreen()),
              routes: [
                GoRoute(
                  path: 'api-keys',
                  pageBuilder: (context, state) =>
                      const NoTransitionPage(child: ApiKeysScreen()),
                ),
                GoRoute(
                  path: 'templates',
                  pageBuilder: (context, state) =>
                      const NoTransitionPage(child: TemplatesScreen()),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
