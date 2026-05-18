import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../../core/router/app_router.dart';
import '../store/settings_store.dart';
import '../../auth/store/auth_store.dart';

import '../../../core/di/service_locator.dart';

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
        ServiceLocator.identitiesStore.loadIdentities();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authStore = context.read<AuthStore>();
    final settingsStore = context.read<SettingsStore>();

    final isMobile = MediaQuery.of(context).size.width < 600;
    final outerPad = isMobile ? 16.0 : 24.0;
    final horizontalPad = EdgeInsets.symmetric(horizontal: outerPad);

    return Observer(
      builder: (context) {
        final activeWorkspaceId = authStore.activeWorkspace ?? '';
        final userRole = settingsStore.getRoleForWorkspace(activeWorkspaceId);

        final workspaces = settingsStore.workspaces;
        final activeWorkspace = workspaces.any((w) => w.id == activeWorkspaceId)
            ? workspaces.firstWhere((w) => w.id == activeWorkspaceId)
            : null;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Header
              Padding(
                padding: horizontalPad,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Settings').h4(),
                    const SizedBox(height: 4),
                    const Text(
                      'Manage your account, workspaces, and workspace settings.',
                    ).muted.small,
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Merged Account & Workspace Section
              Padding(
                padding: horizontalPad,
                child: _SectionHeader(
                  title: 'Account & Workspace',
                  subtitle: 'Switch workspaces or manage your team settings.',
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
                child: Card(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // Part 1: Profile & Active Workspace Details
                      Padding(
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
                                  if (settingsStore.isLoading)
                                    const Text(
                                      'Loading workspaces...',
                                    ).muted.xSmall
                                  else if (activeWorkspace != null)
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
                                        Text(
                                          'Active: ${activeWorkspace.name} · $userRole',
                                        ).mono().muted.xSmall,
                                      ],
                                    )
                                  else
                                    Row(
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFEF4444),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'No Active Workspace',
                                        ).muted.xSmall,
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      // Part 2: Workspace List
                      if (settingsStore.isLoading)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(size: 20),
                          ),
                        )
                      else if (settingsStore.workspaces.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: _EmptyState(
                            icon: BootstrapIcons.personWorkspace,
                            label: 'No workspaces',
                            hint: 'Create a workspace to get started.',
                          ),
                        )
                      else
                        Column(
                          children: List.generate(
                            settingsStore.workspaces.length,
                            (index) {
                              final ws = settingsStore.workspaces[index];
                              final isActive = activeWorkspaceId == ws.id;
                              final role = settingsStore.getRoleForWorkspace(
                                ws.id,
                              );
                              return Column(
                                children: [
                                  if (index > 0)
                                    const Divider(
                                      height: 1,
                                      indent: 16,
                                      endIndent: 16,
                                    ),
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
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Color(
                                                          0xFF22C55E,
                                                        ),
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
                                              }
                                            },
                                            child: const Text('Switch'),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Cryptographic Identities Section
              Padding(
                padding: horizontalPad,
                child: _SectionHeader(
                  title: 'Cryptographic Identities',
                  subtitle:
                      'Manage anonymous profile identities for peer-to-peer sharing.',
                  action: PrimaryButton(
                    onPressed: () => _showCreateIdentityDialog(context),
                    leading: const Icon(BootstrapIcons.plus, size: 14),
                    child: const Text('New Identity'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: horizontalPad,
                child: Observer(
                  builder: (context) {
                    final store = ServiceLocator.identitiesStore;
                    if (store.isLoading && store.identities.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(size: 20),
                        ),
                      );
                    }

                    if (store.identities.isEmpty) {
                      return _EmptyState(
                        icon: BootstrapIcons.personBoundingBox,
                        label: 'No identities generated',
                        hint:
                            'Create an identity to share vault items securely.',
                      );
                    }

                    return Card(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: List.generate(store.identities.length, (
                          index,
                        ) {
                          final identity = store.identities[index];
                          final shortKey = identity.publicKey.length > 25
                              ? '${identity.publicKey.substring(0, 12)}...${identity.publicKey.substring(identity.publicKey.length - 12)}'
                              : identity.publicKey;

                          return Column(
                            children: [
                              if (index > 0)
                                const Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Avatar(
                                      initials: identity.name.isNotEmpty
                                          ? identity.name[0].toUpperCase()
                                          : '?',
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(identity.name).semiBold,
                                              if (identity.isPrimary) ...[
                                                const SizedBox(width: 8),
                                                SecondaryBadge(
                                                  child: const Text(
                                                    'Primary Name',
                                                  ).xSmall,
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Key: $shortKey',
                                          ).mono().muted.xSmall,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    if (!identity.isPrimary)
                                      OutlineButton(
                                        density: ButtonDensity.compact,
                                        onPressed: () =>
                                            store.togglePrimary(identity.id),
                                        child: const Text('Set Primary'),
                                      ),
                                    const SizedBox(width: 6),
                                    IconButton.ghost(
                                      density: ButtonDensity.compact,
                                      icon: const Icon(
                                        BootstrapIcons.copy,
                                        size: 14,
                                      ),
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: identity.publicKey,
                                          ),
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
                                                    'Public key copied to clipboard',
                                                  ),
                                                ),
                                              ),
                                        );
                                      },
                                    ),
                                    if (!identity.isPrimary) ...[
                                      const SizedBox(width: 6),
                                      IconButton.ghost(
                                        density: ButtonDensity.compact,
                                        onPressed: () =>
                                            store.deleteIdentity(identity.id),
                                        icon: Icon(
                                          BootstrapIcons.trash,
                                          size: 14,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.destructive,
                                        ),
                                      ),
                                    ],
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

              // Developer Tools / Configurations Section
              Padding(
                padding: horizontalPad,
                child: _SectionHeader(
                  title: 'Developer Tools',
                  subtitle: 'Manage API keys and templates for this workspace.',
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: horizontalPad,
                child: Column(
                  spacing: 12,
                  children: [
                    // API Keys Link Card
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.apiKeys),
                      child: Card(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                BootstrapIcons.key,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('API Keys').semiBold,
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Create and manage credentials for programmatic access.',
                                  ).muted.xSmall,
                                ],
                              ),
                            ),
                            Icon(
                              BootstrapIcons.chevronRight,
                              color: Theme.of(
                                context,
                              ).colorScheme.mutedForeground,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Templates Link Card
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.templates),
                      child: Card(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                BootstrapIcons.cardList,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Templates').semiBold,
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Define blueprint structures for credentials and entries.',
                                  ).muted.xSmall,
                                ],
                              ),
                            ),
                            Icon(
                              BootstrapIcons.chevronRight,
                              color: Theme.of(
                                context,
                              ).colorScheme.mutedForeground,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
      },
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

  void _showCreateIdentityDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    var isPrimary = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Cryptographic Identity').h4,
          content: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Profile Name').semiBold,
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  placeholder: const Text(
                    'e.g. Personal Profile, Anonymous Recruiter',
                  ),
                ),
                const SizedBox(height: 14),
                Checkbox(
                  state: isPrimary
                      ? CheckboxState.checked
                      : CheckboxState.unchecked,
                  onChanged: (state) {
                    setState(() {
                      isPrimary = state == CheckboxState.checked;
                    });
                  },
                  trailing: const Text('Mark as Primary Name').small,
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty) return;
                    final ok = await ServiceLocator.identitiesStore
                        .createIdentity(
                          name: nameCtrl.text.trim(),
                          isPrimary: isPrimary,
                        );
                    if (ok && context.mounted) {
                      Navigator.of(context).pop();
                      showToast(
                        context: context,
                        builder: (context, overlay) => const SurfaceCard(
                          child: Basic(
                            leading: Icon(BootstrapIcons.check, size: 16),
                            title: Text('Identity generated successfully'),
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Generate Cryptographic Keys'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
