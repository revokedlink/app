import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

import '../store/api_keys_store.dart';
import '../../auth/store/auth_store.dart';

class ApiKeysScreen extends StatefulWidget {
  const ApiKeysScreen({super.key});

  @override
  State<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends State<ApiKeysScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ApiKeysStore>().loadApiKeys();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<ApiKeysStore>();
    final authStore = context.read<AuthStore>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('API Keys').h4,
                    const Text(
                      'Manage programmatic access to your workspace.',
                    ).muted.small,
                  ],
                ),
              ),
              PrimaryButton(
                onPressed: () => _showCreateSheet(context, store, authStore),
                leading: const Icon(BootstrapIcons.plus, size: 16),
                child: const Text('New Key'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          Expanded(
            child: Observer(
              builder: (_) {
                if (store.isLoading && store.apiKeys.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(size: 20),
                  );
                }

                if (store.errorMessage != null) {
                  return Center(
                    child: Alert(
                      destructive: true,
                      leading: const Icon(BootstrapIcons.exclamation),
                      title: const Text('Failed to load API keys'),
                      content: Text(store.errorMessage!),
                      trailing: GhostButton(
                        onPressed: store.loadApiKeys,
                        child: const Text('Retry'),
                      ),
                    ),
                  );
                }

                if (store.apiKeys.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          BootstrapIcons.lock,
                          size: 40,
                          color: Theme.of(context).colorScheme.mutedForeground,
                        ),
                        const SizedBox(height: 12),
                        const Text('No API keys').semiBold,
                        const SizedBox(height: 4),
                        const Text(
                          'Create a key for programmatic access.',
                        ).muted.small,
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: store.apiKeys.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final key = store.apiKeys[index];
                    return _ApiKeyCard(
                      apiKey: key,
                      onRevoke: () => _confirmRevoke(context, store, key.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateSheet(
    BuildContext context,
    ApiKeysStore store,
    AuthStore authStore,
  ) {
    final labelCtrl = TextEditingController();
    final allScopes = [
      'record:read',
      'record:create',
      'record:update',
      'record:delete',
      'workspaces:read',
      'workspaces:create',
      'workspaces:update',
      'workspaces:delete',
      'workspaceMembers:read',
      'workspaceMembers:create',
      'workspaceMembers:update',
      'workspaceMembers:delete',
    ];
    final selectedScopes = <String>{};

    openSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('New API Key').h4,
                const SizedBox(height: 4),
                const Text(
                  'Select the scopes this key should have access to.',
                ).muted.small,
                const SizedBox(height: 20),

                const Text('Label').semiBold,
                const SizedBox(height: 6),
                TextField(
                  controller: labelCtrl,
                  placeholder: Text('Production Key'),
                ),
                const SizedBox(height: 16),

                const Text('Scopes').semiBold,
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: allScopes.map((scope) {
                        final sel = selectedScopes.contains(scope);
                        return sel
                            ? PrimaryButton(
                                density: ButtonDensity.compact,
                                onPressed: () => setSheetState(
                                  () => selectedScopes.remove(scope),
                                ),
                                trailing: const Icon(
                                  BootstrapIcons.check,
                                  size: 12,
                                ),
                                child: Text(scope).mono.xSmall,
                              )
                            : OutlineButton(
                                density: ButtonDensity.compact,
                                onPressed: () => setSheetState(
                                  () => selectedScopes.add(scope),
                                ),
                                child: Text(scope).mono.xSmall,
                              );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                PrimaryButton(
                  onPressed: () async {
                    if (labelCtrl.text.isEmpty || selectedScopes.isEmpty) {
                      return;
                    }
                    final ok = await store.createApiKey(
                      label: labelCtrl.text,
                      user: authStore.userId,
                      workspace: authStore.activeWorkspace ?? '',
                      scopes: selectedScopes.toList(),
                    );
                    if (ok && ctx.mounted) {
                      closeDrawer(context);
                      final token = store.lastCreatedPlainToken;
                      if (token != null) {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('API Key Created'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Please copy this key now. You will not be able to see it again.',
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.muted,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(token).mono.small),
                                        GhostButton(
                                          density: ButtonDensity.icon,
                                          onPressed: () {
                                            Clipboard.setData(
                                              ClipboardData(text: token),
                                            );
                                            showToast(
                                              context: context,
                                              builder: (context, overlay) =>
                                                  const SurfaceCard(
                                                    child: Basic(
                                                      leading: Icon(
                                                        BootstrapIcons.check,
                                                        size: 16,
                                                      ),
                                                      title: Text(
                                                        'Copied to clipboard',
                                                      ),
                                                    ),
                                                  ),
                                            );
                                          },
                                          child: const Icon(
                                            BootstrapIcons.copy,
                                            size: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                PrimaryButton(
                                  onPressed: () {
                                    store.clearLastToken();
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Done'),
                                ),
                              ],
                            );
                          },
                        );
                      }
                    }
                  },
                  child: const Text('Generate Key'),
                ),
              ],
            ),
          ),
        );
      },
      position: OverlayPosition.bottom,
    );
  }

  void _confirmRevoke(BuildContext context, ApiKeysStore store, String id) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Revoke API key'),
          content: const Text(
            'This key will stop working immediately. This action cannot be undone.',
          ),
          actions: [
            OutlineButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            DestructiveButton(
              onPressed: () {
                store.deleteApiKey(id);
                Navigator.of(context).pop();
              },
              child: const Text('Revoke'),
            ),
          ],
        );
      },
    );
  }
}

class _ApiKeyCard extends StatelessWidget {
  final dynamic apiKey;
  final VoidCallback onRevoke;

  const _ApiKeyCard({required this.apiKey, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(apiKey.label).semiBold,
                      const SizedBox(height: 2),
                      Text(
                        'Created ${apiKey.created ?? "recently"}',
                      ).muted.xSmall,
                    ],
                  ),
                ),
                DestructiveButton(
                  density: ButtonDensity.compact,
                  onPressed: onRevoke,
                  child: const Text('Revoke'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: (apiKey.scopes as List<String>).map((scope) {
                return SecondaryBadge(child: Text(scope).mono.xSmall);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
