import 'dart:convert';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../../core/router/app_router.dart';
import '../../../core/models/template.dart';
import '../store/settings_store.dart';
import '../../auth/store/auth_store.dart';
import '../../api_keys/store/api_keys_store.dart';
import '../../templates/store/templates_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authStore = context.read<AuthStore>();
      if (authStore.isAuthenticated) {
        context.read<SettingsStore>().loadWorkspaces(authStore.userId);
        context.read<ApiKeysStore>().loadApiKeys();
        context.read<TemplatesStore>().loadTemplates(
          authStore.activeWorkspace ?? '',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authStore = context.read<AuthStore>();
    final settingsStore = context.read<SettingsStore>();
    final apiKeysStore = context.read<ApiKeysStore>();
    final templatesStore = context.read<TemplatesStore>();

    final activeWorkspaceId = authStore.activeWorkspace ?? '';
    final userRole = settingsStore.getRoleForWorkspace(activeWorkspaceId);
    final isAdmin = userRole == 'admin';

    final isMobile = MediaQuery.of(context).size.width < 600;
    final outerPad = isMobile ? 16.0 : 24.0;
    final horizontalPad = EdgeInsets.symmetric(horizontal: outerPad);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: horizontalPad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Settings').h4(),
                const SizedBox(height: 4),
                const Text(
                  'Manage your account, workspaces, and API keys.',
                ).muted.small,
              ],
            ),
          ),

          const SizedBox(height: 32),

          Padding(
            padding: horizontalPad,
            child: _SectionHeader(
              title: 'Account',
              subtitle: 'Your authentication details.',
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: horizontalPad,
            child: Observer(
              builder: (_) => Card(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Avatar(
                      initials: authStore.userEmail.isNotEmpty
                          ? authStore.userEmail[0].toUpperCase()
                          : '?',
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(authStore.userEmail).semiBold,
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('Active').muted.xSmall,
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          Padding(
            padding: horizontalPad,
            child: _SectionHeader(
              title: 'Workspaces',
              subtitle: 'Switch between or create new workspaces.',
              action: PrimaryButton(
                onPressed: () => _showCreateWorkspaceDialog(
                  context,
                  settingsStore,
                  authStore,
                ),
                leading: const Icon(BootstrapIcons.plus, size: 14),
                child: const Text('New Workspace'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: horizontalPad,
            child: Observer(
              builder: (_) {
                if (settingsStore.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(size: 20),
                  );
                }
                if (settingsStore.workspaces.isEmpty) {
                  return _EmptyState(
                    icon: BootstrapIcons.personWorkspace,
                    label: 'No workspaces',
                    hint: 'Create a workspace to get started.',
                  );
                }
                return Card(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: List.generate(settingsStore.workspaces.length, (
                      index,
                    ) {
                      final ws = settingsStore.workspaces[index];
                      final isActive = authStore.activeWorkspace == ws.id;
                      final role = settingsStore.getRoleForWorkspace(ws.id);
                      return Column(
                        children: [
                          if (index > 0)
                            const Divider(height: 1, indent: 16, endIndent: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Avatar(
                                  initials: ws.name.isNotEmpty
                                      ? ws.name[0].toUpperCase()
                                      : '?',
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(ws.name).semiBold,
                                      const SizedBox(height: 2),
                                      Text(
                                        '${ws.slug} · $role',
                                      ).mono().muted.xSmall,
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (isActive)
                                  SecondaryBadge(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF22C55E),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        const Text('Active').xSmall,
                                      ],
                                    ),
                                  )
                                else
                                  OutlineButton(
                                    density: ButtonDensity.compact,
                                    onPressed: () async {
                                      final ok = await settingsStore
                                          .switchWorkspace(
                                            authStore.userId,
                                            ws.id,
                                          );
                                      if (ok) {
                                        await authStore.initialize();
                                        if (context.mounted) {
                                          context
                                              .read<ApiKeysStore>()
                                              .loadApiKeys();
                                          context
                                              .read<TemplatesStore>()
                                              .loadTemplates(
                                                authStore.activeWorkspace ?? '',
                                              );
                                        }
                                      }
                                    },
                                    child: const Text('Switch'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 32),

          Padding(
            padding: horizontalPad,
            child: _SectionHeader(
              title: 'API Keys',
              subtitle: 'Manage programmatic access to your workspace.',
              action: PrimaryButton(
                onPressed: () =>
                    _showCreateApiKeySheet(context, apiKeysStore, authStore),
                leading: const Icon(BootstrapIcons.plus, size: 14),
                child: const Text('New Key'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: horizontalPad,
            child: Observer(
              builder: (_) {
                final _ = apiKeysStore.errorMessage;
                if (apiKeysStore.isLoading && apiKeysStore.apiKeys.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(size: 20),
                  );
                }
                if (apiKeysStore.apiKeys.isEmpty) {
                  return _EmptyState(
                    icon: BootstrapIcons.key,
                    label: 'No API keys',
                    hint: 'Create a key for programmatic access.',
                  );
                }
                return Column(
                  spacing: 8,
                  children: apiKeysStore.apiKeys.map((key) {
                    return _ApiKeyCard(
                      apiKey: key,
                      onRevoke: () =>
                          _confirmRevokeApiKey(context, apiKeysStore, key.id),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          const SizedBox(height: 32),

          Padding(
            padding: horizontalPad,
            child: _SectionHeader(
              title: 'Templates',
              subtitle:
                  'Structural blueprints for creating sections and records.',
              action: isAdmin
                  ? PrimaryButton(
                      onPressed: () => _showCreateTemplateSheet(
                        context,
                        templatesStore,
                        authStore,
                      ),
                      leading: const Icon(BootstrapIcons.plus, size: 14),
                      child: const Text('New Template'),
                    )
                  : const OutlineBadge(child: Text('Read-Only')),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: horizontalPad,
            child: Observer(
              builder: (_) {
                final _ = templatesStore.errorMessage;
                if (templatesStore.isLoading &&
                    templatesStore.templates.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(size: 20),
                  );
                }
                if (templatesStore.templates.isEmpty) {
                  return _EmptyState(
                    icon: BootstrapIcons.cardList,
                    label: 'No templates',
                    hint: isAdmin
                        ? 'Create a template to define shared structure.'
                        : 'Contact your workspace admin to add structural templates.',
                  );
                }
                return Column(
                  spacing: 8,
                  children: templatesStore.templates.map((template) {
                    return _TemplateCard(
                      template: template,
                      isAdmin: isAdmin,
                      onEdit: () => _showCreateTemplateSheet(
                        context,
                        templatesStore,
                        authStore,
                        initialTemplate: template,
                      ),
                      onDelete: () => _confirmDeleteTemplate(
                        context,
                        templatesStore,
                        template.id,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          const SizedBox(height: 40),
          Padding(padding: horizontalPad, child: const Divider()),
          const SizedBox(height: 20),

          Padding(
            padding: horizontalPad,
            child: Align(
              alignment: Alignment.centerLeft,
              child: DestructiveButton(
                leading: const Icon(BootstrapIcons.boxArrowLeft, size: 16),
                onPressed: () async {
                  await authStore.logout();
                  if (context.mounted) context.go(AppRoutes.login);
                },
                child: const Text('Sign out'),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showCreateWorkspaceDialog(
    BuildContext context,
    SettingsStore settingsStore,
    AuthStore authStore,
  ) {
    final nameCtrl = TextEditingController();
    final slugCtrl = TextEditingController();

    nameCtrl.addListener(() {
      final text = nameCtrl.text
          .toLowerCase()
          .replaceAll(' ', '-')
          .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
      slugCtrl.text = text;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Workspace').h4,
        content: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Name').semiBold,
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                placeholder: const Text('My Team'),
              ),
              const SizedBox(height: 14),
              const Text('Slug').semiBold,
              const SizedBox(height: 6),
              TextField(
                controller: slugCtrl,
                placeholder: const Text('my-team'),
                inputFormatters: [
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    final text = newValue.text
                        .toLowerCase()
                        .replaceAll(' ', '-')
                        .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
                    return TextEditingValue(
                      text: text,
                      selection: TextSelection.collapsed(offset: text.length),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty || slugCtrl.text.isEmpty) return;
                  final ok = await settingsStore.createWorkspace(
                    name: nameCtrl.text.trim(),
                    slug: slugCtrl.text.trim(),
                    userId: authStore.userId,
                  );
                  if (ok) {
                    await authStore.initialize();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      showToast(
                        context: context,
                        builder: (context, overlay) => const SurfaceCard(
                          child: Basic(
                            leading: Icon(BootstrapIcons.check, size: 16),
                            title: Text('Workspace created successfully'),
                          ),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Create Workspace'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateApiKeySheet(
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
      builder: (context) => StatefulBuilder(
        builder: (ctx, setSheetState) => Observer(
          builder: (context) {
            final _ = store.errorMessage;
            return Container(
              constraints: const BoxConstraints(maxWidth: 420),
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
                    placeholder: const Text('Production Key'),
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
                      if (labelCtrl.text.isEmpty || selectedScopes.isEmpty)
                        return;
                      final ok = await store.createApiKey(
                        label: labelCtrl.text,
                        user: authStore.userId,
                        workspace: authStore.activeWorkspace ?? '',
                        scopes: selectedScopes.toList(),
                      );
                      if (ok && ctx.mounted) {
                        closeSheet(context);
                        final token = store.lastCreatedPlainToken;
                        if (token != null) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('API Key Created'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Copy this key now — you won\'t be able to see it again.',
                                  ).muted.small,
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.muted,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(token).mono.small),
                                        const SizedBox(width: 8),
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
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Generate Key'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      position: OverlayPosition.bottom,
    );
  }

  void _confirmRevokeApiKey(
    BuildContext context,
    ApiKeysStore store,
    String id,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
      ),
    );
  }
}

/// Section title + subtitle row, with an optional trailing action button.
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title).semiBold,
              const SizedBox(height: 3),
              Text(subtitle).muted.small,
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 12), action!],
      ],
    );
  }
}

/// Consistent empty state used for both workspaces and API keys.
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;

  const _EmptyState({
    required this.icon,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 28,
              color: Theme.of(context).colorScheme.mutedForeground,
            ),
            const SizedBox(height: 10),
            Text(label).semiBold.small,
            const SizedBox(height: 4),
            Text(hint).muted.xSmall,
          ],
        ),
      ),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(apiKey.label).semiBold,
                    const SizedBox(height: 3),
                    Text(
                      'Created ${apiKey.created ?? "recently"}',
                    ).muted.xSmall,
                  ],
                ),
              ),
              const SizedBox(width: 12),
              DestructiveButton(
                density: ButtonDensity.compact,
                onPressed: onRevoke,
                child: const Text('Revoke'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: (apiKey.scopes as List<String>).map((scope) {
              return SecondaryBadge(child: Text(scope).mono.xSmall);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

void _showCreateTemplateSheet(
  BuildContext context,
  TemplatesStore templatesStore,
  AuthStore authStore, {
  Template? initialTemplate,
}) {
  final isEdit = initialTemplate != null;
  final nameController = TextEditingController(
    text: initialTemplate?.name ?? '',
  );
  final schemaController = TextEditingController(
    text: initialTemplate != null
        ? const JsonEncoder.withIndent('  ').convert(initialTemplate.schema)
        : '''{
  "sections": [
    {
      "name": "Database Credentials",
      "key": "db",
      "records": [
        {
          "label": "DB Host",
          "key": "host",
          "value": "127.0.0.1",
          "type": "text",
          "format": "default"
        },
        {
          "label": "Password",
          "key": "password",
          "value": "secret",
          "type": "text",
          "format": "hidden"
        }
      ]
    }
  ],
  "records": [
    {
      "label": "API Endpoint",
      "key": "api_url",
      "value": "https://api.example.com",
      "type": "text",
      "format": "default"
    }
  ]
}''',
  );

  openSheet(
    context: context,
    position: OverlayPosition.bottom,
    builder: (sheetContext) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isEdit ? 'Edit Template' : 'New Template').h3().semiBold,
              const SizedBox(height: 6),
              const Text(
                'Define the structure for automatic section and record generation.',
              ).muted.small,
              const SizedBox(height: 20),

              const Text('Template Name').small.semiBold,
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                placeholder: const Text('e.g. AWS Project Setup'),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  const Text('Template Schema (JSON)').small.semiBold,
                  const Spacer(),
                  const OutlineBadge(child: Text('Monospace JSON')),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: schemaController,
                maxLines: 12,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                placeholder: const Text(
                  '{\n  "sections": [...],\n  "records": [...]\n}',
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GhostButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  PrimaryButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        showToast(
                          context: context,
                          builder: (c, o) => const SurfaceCard(
                            child: Basic(
                              leading: Icon(
                                BootstrapIcons.exclamationTriangle,
                                size: 16,
                              ),
                              title: Text('Name cannot be empty'),
                            ),
                          ),
                        );
                        return;
                      }

                      // Validate JSON schema
                      Map<String, dynamic> schemaMap;
                      try {
                        schemaMap =
                            jsonDecode(schemaController.text.trim())
                                as Map<String, dynamic>;
                      } catch (e) {
                        showToast(
                          context: context,
                          builder: (c, o) => SurfaceCard(
                            child: Basic(
                              leading: const Icon(
                                BootstrapIcons.exclamationOctagon,
                                size: 16,
                              ),
                              title: const Text('Invalid JSON structure'),
                              subtitle: Text(e.toString()),
                            ),
                          ),
                        );
                        return;
                      }

                      bool ok;
                      if (isEdit) {
                        ok = await templatesStore.updateTemplate(
                          initialTemplate.id,
                          name: name,
                          schema: schemaMap,
                        );
                      } else {
                        ok = await templatesStore.createTemplate(
                          name: name,
                          schema: schemaMap,
                          workspaceId: authStore.activeWorkspace ?? '',
                        );
                      }

                      if (ok && sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                        showToast(
                          context: context,
                          builder: (c, o) => SurfaceCard(
                            child: Basic(
                              leading: const Icon(
                                BootstrapIcons.check,
                                size: 16,
                              ),
                              title: Text(
                                isEdit
                                    ? 'Template updated'
                                    : 'Template created',
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    child: Text(isEdit ? 'Save Changes' : 'Create Template'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _confirmDeleteTemplate(
  BuildContext context,
  TemplatesStore templatesStore,
  String templateId,
) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete Template'),
        content: const Text(
          'Are you sure you want to permanently delete this template? Existing vault items created from this template will not be affected.',
        ),
        actions: [
          GhostButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          DestructiveButton(
            onPressed: () async {
              final ok = await templatesStore.deleteTemplate(templateId);
              if (ok && dialogContext.mounted) {
                Navigator.pop(dialogContext);
                showToast(
                  context: context,
                  builder: (c, o) => const SurfaceCard(
                    child: Basic(
                      leading: Icon(BootstrapIcons.check, size: 16),
                      title: Text('Template permanently deleted'),
                    ),
                  ),
                );
              }
            },
            child: const Text('Delete permanently'),
          ),
        ],
      );
    },
  );
}

class _TemplateCard extends StatefulWidget {
  final Template template;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.template,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = widget.template.schema['sections'] as List<dynamic>? ?? [];
    final records = widget.template.schema['records'] as List<dynamic>? ?? [];

    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                BootstrapIcons.cardList,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.template.name).semiBold,
                    const SizedBox(height: 2),
                    Text(
                      '${sections.length} sections • ${records.length} records',
                    ).muted.xSmall,
                  ],
                ),
              ),
              if (widget.isAdmin) ...[
                GhostButton(
                  density: ButtonDensity.icon,
                  onPressed: widget.onEdit,
                  child: const Icon(BootstrapIcons.pencil, size: 14),
                ),
                const SizedBox(width: 4),
                GhostButton(
                  density: ButtonDensity.icon,
                  onPressed: widget.onDelete,
                  child: Icon(
                    BootstrapIcons.trash,
                    size: 14,
                    color: theme.colorScheme.destructive,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: GhostButton(
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isExpanded ? BootstrapIcons.eyeSlash : BootstrapIcons.eye,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isExpanded ? 'Hide Blueprint' : 'Visualize Blueprint',
                  ).small,
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            const Text('Blueprint Structure').small.semiBold.muted,
            const SizedBox(height: 10),
            if (records.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                child: Row(
                  children: [
                    Icon(
                      BootstrapIcons.folderSymlink,
                      size: 14,
                      color: theme.colorScheme.mutedForeground,
                    ),
                    const SizedBox(width: 6),
                    const Text('Root Records').semiBold.xSmall.muted,
                  ],
                ),
              ),
              ...records.map((rec) {
                final r = rec as Map<String, dynamic>? ?? {};
                final label = r['label'] as String? ?? 'Record';
                final key = r['key'] as String? ?? '';
                final type = r['type'] as String? ?? 'text';
                final format = r['format'] as String? ?? 'default';
                return Container(
                  margin: const EdgeInsets.only(left: 16, bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.muted.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(theme.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        type == 'number'
                            ? BootstrapIcons.hash
                            : BootstrapIcons.fileText,
                        size: 12,
                        color: theme.colorScheme.mutedForeground,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text('$label ($key)').xSmall.mono),
                      const SizedBox(width: 6),
                      SecondaryBadge(child: Text(type).xSmall),
                      if (format == 'hidden') ...[
                        const SizedBox(width: 4),
                        const OutlineBadge(child: Text('hidden')),
                      ],
                    ],
                  ),
                );
              }),
            ],
            if (sections.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...sections.map((sec) {
                final s = sec as Map<String, dynamic>? ?? {};
                final name = s['name'] as String? ?? 'Section';
                final key = s['key'] as String? ?? '';
                final secRecords = s['records'] as List<dynamic>? ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 4.0,
                        top: 4.0,
                        bottom: 6.0,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            BootstrapIcons.folder,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text('$name ($key)').semiBold.xSmall,
                        ],
                      ),
                    ),
                    if (secRecords.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 24.0, bottom: 8.0),
                        child: const Text(
                          'No records in this section',
                        ).muted.xSmall.italic,
                      )
                    else
                      ...secRecords.map((rec) {
                        final r = rec as Map<String, dynamic>? ?? {};
                        final label = r['label'] as String? ?? 'Record';
                        final key = r['key'] as String? ?? '';
                        final type = r['type'] as String? ?? 'text';
                        final format = r['format'] as String? ?? 'default';
                        return Container(
                          margin: const EdgeInsets.only(left: 24, bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.muted.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(theme.radiusSm),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                type == 'number'
                                    ? BootstrapIcons.hash
                                    : BootstrapIcons.fileText,
                                size: 12,
                                color: theme.colorScheme.mutedForeground,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('$label ($key)').xSmall.mono,
                              ),
                              const SizedBox(width: 6),
                              SecondaryBadge(child: Text(type).xSmall),
                              if (format == 'hidden') ...[
                                const SizedBox(width: 4),
                                const OutlineBadge(child: Text('hidden')),
                              ],
                            ],
                          ),
                        );
                      }),
                  ],
                );
              }),
            ],
          ],
        ],
      ),
    );
  }
}
