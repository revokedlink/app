import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../store/shares_store.dart';
import '../../auth/store/auth_store.dart';
import '../../vault/store/vault_store.dart';
import '../../../core/models/link.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/data_table/filter_bar.dart';
import '../../../core/widgets/data_table/data_table_controller.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/app_security_chip.dart';
import '../../../core/design/spacing.dart';
import 'share_create_sheet.dart';

class SharesScreen extends StatefulWidget {
  final String? filterSlug;

  const SharesScreen({super.key, this.filterSlug});

  @override
  State<SharesScreen> createState() => _SharesScreenState();
}

class _SharesScreenState extends State<SharesScreen> {
  late DataTableController<Link> _tableController;

  @override
  void initState() {
    super.initState();
    final store = context.read<SharesStore>();

    _tableController = DataTableController<Link>(
      getSourceItems: () => store.shares.toList(),
      fieldGetters: {
        'label': (l) => l.label,
        'slug': (l) => l.slug,
        'status': (l) => l.status,
        'created': (l) => l.created ?? '',
      },
      defaultSort: 'created_desc',
    );
    if (widget.filterSlug != null) {
      _tableController.searchQuery = widget.filterSlug!;
    }
    _tableController.addListener(_onTableControllerChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.loadShares();
      context.read<VaultStore>().loadRecords();
      ServiceLocator.identitiesStore.loadIdentities();
    });
  }

  void _onTableControllerChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _tableController.removeListener(_onTableControllerChanged);
    _tableController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<SharesStore>();
    final authStore = context.read<AuthStore>();

    final isMobile = MediaQuery.of(context).size.width < 600;
    final outerPad = isMobile ? 16.0 : 24.0;
    final scrollbarMargin = isMobile ? 4.0 : 6.0;
    final innerPad = outerPad - scrollbarMargin;
    final horizontalPad = EdgeInsets.symmetric(horizontal: outerPad);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: horizontalPad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Observer(
                builder: (_) {
                  final count = store.shares.length;
                  return AppScreenHeader(
                    title: 'Public Shares',
                    badgeLabel: '$count ${count == 1 ? 'link' : 'links'}',
                    subtitle:
                        'Create and manage public unauthenticated sharing links.',
                    actions: [
                      PrimaryButton(
                        density: ButtonDensity.icon,
                        onPressed: () {
                          _showCreateSheet(context, store, authStore);
                        },
                        child: const Icon(BootstrapIcons.plus, size: 20),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              FilterBar<Link>(
                controller: _tableController,
                columns: const [
                  DataTableColumn(value: 'label', label: 'Label'),
                  DataTableColumn(value: 'slug', label: 'Slug'),
                  DataTableColumn(value: 'status', label: 'Status'),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: scrollbarMargin),
            child: Observer(
              builder: (_) {
                if (store.isLoading && store.shares.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(size: 20),
                  );
                }

                if (store.errorMessage != null) {
                  return Center(
                    child: Alert(
                      destructive: true,
                      leading: const Icon(BootstrapIcons.exclamation),
                      title: const Text('Failed to load shares'),
                      content: Text(store.errorMessage!),
                      trailing: GhostButton(
                        onPressed: store.loadShares,
                        child: const Text('Retry'),
                      ),
                    ),
                  );
                }

                if (store.shares.isEmpty) {
                  return AppEmptyState(
                    icon: BootstrapIcons.share,
                    title: 'No shared links',
                    subtitle:
                        'Create a public share link to securely expose selected vault items.',
                    action: PrimaryButton(
                      onPressed: () =>
                          _showCreateSheet(context, store, authStore),
                      child: const Text('Create your first link'),
                    ),
                  );
                }

                if (_tableController.filteredItems.isEmpty &&
                    store.shares.isNotEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: const Text('No shares match your filters.').muted,
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.only(
                    left: innerPad,
                    right: innerPad,
                    bottom: 32,
                  ),
                  itemCount: _tableController.filteredItems.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final share = _tableController.filteredItems[index];
                    return _ShareCard(
                      share: share,
                      onDelete: () => _confirmDelete(context, store, share.id),
                      onPause: () async {
                        await store.updateShare(share.id, {'status': 'paused'});
                      },
                      onActivate: () async {
                        await store.updateShare(share.id, {'status': 'active'});
                      },
                      onRevoke: () => _confirmRevoke(context, store, share),
                      onDuplicate: () => _showCreateSheet(
                        context,
                        store,
                        authStore,
                        initialShare: share,
                      ),
                      onEdit: () => _showCreateSheet(
                        context,
                        store,
                        authStore,
                        editShare: share,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // New multi-step share create/edit. The huge inline form moved to
  // share_create_sheet.dart so a screen-overflowing sheet is split into
  // basics → security → review.
  void _showCreateSheet(
    BuildContext context,
    SharesStore store,
    AuthStore authStore, {
    Link? initialShare,
    Link? editShare,
  }) {
    openShareCreateSheet(
      context: context,
      store: store,
      authStore: authStore,
      initialShare: initialShare,
      editShare: editShare,
    );
  }

  void _confirmDelete(BuildContext context, SharesStore store, String id) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Share Link'),
          content: const Text(
            'This public link will stop working immediately. This action cannot be undone.',
          ),
          actions: [
            OutlineButton(
              onPressed: () => closeSheet(context),
              child: const Text('Cancel'),
            ),
            DestructiveButton(
              onPressed: () async {
                final ok = await store.deleteShare(id);
                if (context.mounted) Navigator.of(context).pop();

                if (ok && context.mounted) {
                  showToast(
                    context: context,
                    builder: (context, overlay) => const SurfaceCard(
                      child: Basic(
                        leading: Icon(BootstrapIcons.check, size: 16),
                        title: Text('Share link deleted successfully'),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _confirmRevoke(BuildContext context, SharesStore store, Link share) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Revoke Share Link'),
          content: const Text(
            'Once a public share link is revoked, it can NEVER be activated or shared again. Are you sure?',
          ),
          actions: [
            OutlineButton(
              onPressed: () => closeSheet(context),

              child: const Text('Cancel'),
            ),
            DestructiveButton(
              onPressed: () async {
                final ok = await store.updateShare(share.id, {
                  'status': 'revoked',
                });
                if (context.mounted) Navigator.of(context).pop();
                if (ok && context.mounted) {
                  showToast(
                    context: context,
                    builder: (context, overlay) => const SurfaceCard(
                      child: Basic(
                        leading: Icon(BootstrapIcons.check, size: 16),
                        title: Text('Share link permanently revoked'),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Revoke Permanently'),
            ),
          ],
        );
      },
    );
  }
}

class _ShareCard extends StatelessWidget {
  final Link share;
  final VoidCallback onDelete;
  final VoidCallback onPause;
  final VoidCallback onActivate;
  final VoidCallback onRevoke;
  final VoidCallback onDuplicate;
  final VoidCallback onEdit;

  const _ShareCard({
    required this.share,
    required this.onDelete,
    required this.onPause,
    required this.onActivate,
    required this.onRevoke,
    required this.onDuplicate,
    required this.onEdit,
  });

  void _showShareOptionsSheet(BuildContext context) {
    final theme = Theme.of(context);
    final publicUrl =
        '${Uri.base.scheme}://${Uri.base.host}${Uri.base.port != 80 && Uri.base.port != 443 && Uri.base.port != 0 ? ":${Uri.base.port}" : ""}/#/share/${share.slug}';
    final isActive = share.status == 'active';
    final isPaused = share.status == 'paused';
    final isRevoked = share.status == 'revoked';

    openSheet(
      context: context,
      position: OverlayPosition.bottom,
      builder: (sheetContext) {
        return Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(share.label).h4,
              const SizedBox(height: 4),
              Text(share.slug).muted.small,
              const SizedBox(height: 24),

              // Copy Link Option (only if active)
              GhostButton(
                onPressed: !isActive
                    ? null
                    : () {
                        closeSheet(context);

                        Clipboard.setData(ClipboardData(text: publicUrl));
                        showToast(
                          context: context,
                          builder: (context, overlay) => const SurfaceCard(
                            child: Basic(
                              leading: Icon(BootstrapIcons.check, size: 16),
                              title: Text('Copied share link to clipboard'),
                            ),
                          ),
                        );
                      },
                child: Row(
                  children: [
                    const Icon(BootstrapIcons.copy, size: 20),
                    const SizedBox(width: 16),
                    Expanded(child: Text('Copy Link').semiBold),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Filter Option
              GhostButton(
                onPressed: () {
                  closeSheet(context);

                  context.go('${AppRoutes.vault}?shareFilterId=${share.id}');
                },
                child: Row(
                  children: [
                    const Icon(BootstrapIcons.funnel, size: 20),
                    const SizedBox(width: 16),
                    Expanded(child: Text('Filter').semiBold),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Duplicate Option
              GhostButton(
                onPressed: () {
                  closeSheet(context);
                  onDuplicate();
                },
                child: Row(
                  children: [
                    const Icon(BootstrapIcons.nodePlus, size: 20),
                    const SizedBox(width: 16),
                    Expanded(child: Text('Duplicate').semiBold),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Edit Details Option
              GhostButton(
                onPressed: () {
                  closeSheet(context);
                  onEdit();
                },
                child: Row(
                  children: [
                    const Icon(BootstrapIcons.pencil, size: 20),
                    const SizedBox(width: 16),
                    Expanded(child: Text('Edit').semiBold),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Pause/Activate Status Transition Option
              if (isActive) ...[
                GhostButton(
                  onPressed: () {
                    closeSheet(context);

                    onPause();
                  },
                  child: Row(
                    children: [
                      const Icon(BootstrapIcons.pause, size: 20),
                      const SizedBox(width: 16),
                      Expanded(child: Text('Pause').semiBold),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ] else if (isPaused) ...[
                GhostButton(
                  onPressed: () {
                    closeSheet(context);

                    onActivate();
                  },
                  child: Row(
                    children: [
                      const Icon(BootstrapIcons.play, size: 20),
                      const SizedBox(width: 16),
                      Expanded(child: Text('Activate').semiBold),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Revoke Option (only if not revoked)
              if (!isRevoked) ...[
                GhostButton(
                  onPressed: () {
                    closeSheet(context);

                    onRevoke();
                  },
                  child: Row(
                    children: [
                      Icon(
                        BootstrapIcons.xCircle,
                        size: 20,
                        color: theme.colorScheme.destructive,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Revoke',
                          style: TextStyle(
                            color: theme.colorScheme.destructive,
                          ),
                        ).semiBold,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Delete Option
              GhostButton(
                onPressed: () {
                  closeSheet(context);
                  onDelete();
                },
                child: Row(
                  children: [
                    Icon(
                      BootstrapIcons.trash,
                      size: 20,
                      color: theme.colorScheme.destructive,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Revoke & Delete',
                        style: TextStyle(color: theme.colorScheme.destructive),
                      ).semiBold,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRevoked = share.status == 'revoked';
    final securityChips = _buildSecurityChips();

    return Card(
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
                    Row(
                      children: [
                        Flexible(child: Text(share.label).semiBold),
                        const SizedBox(width: AppSpacing.sm),
                        AppStatusBadge(status: share.status),
                        const SizedBox(width: AppSpacing.sm),
                        _viewsChip(theme),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          BootstrapIcons.link,
                          size: 12,
                          color: theme.colorScheme.mutedForeground,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Expanded(
                          child: Text(
                            share.slug,
                            style: TextStyle(
                              color: theme.colorScheme.mutedForeground,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ).mono.xSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isRevoked) ...[
                GhostButton(
                  density: ButtonDensity.icon,
                  onPressed: () {
                    context.go('${AppRoutes.vault}?editShareId=${share.id}');
                  },
                  child: const Icon(BootstrapIcons.plusSlashMinus, size: 16),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              GhostButton(
                density: ButtonDensity.icon,
                onPressed: () => _showShareOptionsSheet(context),
                child: const Icon(BootstrapIcons.threeDotsVertical, size: 16),
              ),
            ],
          ),
          if (securityChips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: securityChips,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          GhostButton(
            onPressed: () {
              context.go('${AppRoutes.vault}?shareFilterId=${share.id}');
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(BootstrapIcons.funnel, size: 14),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${share.sections.length} Sections • ${share.records.length} Records',
                ).small,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewsChip(ThemeData theme) {
    final label = share.maxViews > 0
        ? '${share.viewCount}/${share.maxViews} ${share.maxViews == 1 ? 'view' : 'views'}'
        : '${share.viewCount} ${share.viewCount == 1 ? 'view' : 'views'}';
    return AppSecurityChip(icon: BootstrapIcons.eye, label: label);
  }

  List<Widget> _buildSecurityChips() {
    final out = <Widget>[];
    if (share.hasPassword) {
      out.add(
        const AppSecurityChip(icon: BootstrapIcons.lock, label: 'Password'),
      );
    }
    if (share.expiresAt != null) {
      String label = 'Expires';
      try {
        final dt = DateTime.parse(share.expiresAt!).toLocal();
        label =
            'Expires ${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {}
      out.add(AppSecurityChip(icon: BootstrapIcons.clock, label: label));
    }
    if (share.requireHandshake) {
      out.add(
        const AppSecurityChip(
          icon: BootstrapIcons.shieldCheck,
          label: 'Handshake',
        ),
      );
    }
    return out;
  }
}
