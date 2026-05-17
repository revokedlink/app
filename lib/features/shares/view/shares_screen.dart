import 'dart:math';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/services.dart'
    show
        Clipboard,
        ClipboardData,
        TextInputFormatter,
        TextEditingValue,
        TextSelection;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../store/shares_store.dart';
import '../../auth/store/auth_store.dart';
import '../../vault/store/vault_store.dart';
import '../../../core/models/link.dart';
import '../../../core/router/app_router.dart';

class SharesScreen extends StatefulWidget {
  const SharesScreen({super.key});

  @override
  State<SharesScreen> createState() => _SharesScreenState();
}

class _SharesScreenState extends State<SharesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SharesStore>().loadShares();
      context.read<VaultStore>().loadRecords();
    });
  }

  String _generateRandomSlug(int length) {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      length,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
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
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Public Shares').h4,
                        const Text(
                          'Create and manage public unauthenticated sharing links.',
                        ).muted.small,
                      ],
                    ),
                  ),

                  PrimaryButton(
                    density: ButtonDensity.icon,
                    onPressed: () =>
                        _showCreateSheet(context, store, authStore),
                    child: const Icon(BootstrapIcons.plus, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          BootstrapIcons.share,
                          size: 40,
                          color: Theme.of(context).colorScheme.mutedForeground,
                        ),
                        const SizedBox(height: 12),
                        const Text('No shared links').semiBold,
                        const SizedBox(height: 4),
                        const Text(
                          'Create a public share link to securely expose selected vault items.',
                        ).muted.small,
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.only(
                    left: innerPad,
                    right: innerPad,
                    bottom: 32,
                  ),
                  itemCount: store.shares.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final share = store.shares[index];
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

  void _showCreateSheet(
    BuildContext context,
    SharesStore store,
    AuthStore authStore, {
    Link? initialShare,
    Link? editShare,
  }) async {
    final isEditing = editShare != null;
    final labelCtrl = TextEditingController(
      text: isEditing
          ? editShare.label
          : (initialShare != null ? 'Copy of ${initialShare.label}' : ''),
    );

    // Pre-resolve initial slug so that it is synchronous in the UI, avoiding any race conditions or overwriting user input
    String initialSlug = '';
    if (isEditing) {
      initialSlug = editShare.slug;
    } else if (initialShare != null) {
      initialSlug = await store.generateAlternativeSlug(initialShare.slug);
    } else {
      initialSlug = _generateRandomSlug(6);
    }

    final slugCtrl = TextEditingController(text: initialSlug);

    String? slugWarning;
    String? suggestedSlug;
    bool isCheckingSlug = false;

    void validateSlug(String input, StateSetter setSheetState) async {
      if (input.isEmpty) {
        setSheetState(() {
          slugWarning = null;
          suggestedSlug = null;
        });
        return;
      }

      if (input.length < 6) {
        setSheetState(() {
          slugWarning = 'Slug must be at least 6 characters.';
          suggestedSlug = null;
        });
        return;
      }

      setSheetState(() {
        isCheckingSlug = true;
      });

      final taken = await store.isSlugTaken(input);
      if (taken) {
        final alt = await store.generateAlternativeSlug(input);
        setSheetState(() {
          slugWarning = 'This URL slug is already taken.';
          suggestedSlug = alt;
          isCheckingSlug = false;
        });
      } else {
        setSheetState(() {
          slugWarning = null;
          suggestedSlug = null;
          isCheckingSlug = false;
        });
      }
    }

    if (!context.mounted) return;

    openSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isEditing
                        ? 'Edit Public Share'
                        : (initialShare != null
                              ? 'Duplicate Public Share'
                              : 'New Public Share'),
                  ).h4,
                  const SizedBox(height: 4),
                  Text(
                    isEditing
                        ? 'Update the label of this public share link. The URL slug cannot be changed.'
                        : (initialShare != null
                              ? 'Duplicate this public share link with a new name and slug, copying its selected sections and records.'
                              : 'Create a new share link. You can add sections and records to it in the Vault view.'),
                  ).muted.small,
                  const SizedBox(height: 20),

                  const Text('Label').semiBold,
                  const SizedBox(height: 6),
                  TextField(
                    controller: labelCtrl,
                    placeholder: const Text('e.g. My Shared API Keys'),
                    onChanged: (text) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      const Text('Slug').semiBold,
                      const Spacer(),
                      if (isCheckingSlug)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: slugCtrl,
                          placeholder: const Text('e.g. shared-keys'),
                          enabled: !isEditing,
                          inputFormatters: [SlugInputFormatter()],
                          onChanged: (text) =>
                              validateSlug(text, setSheetState),
                        ),
                      ),
                      if (!isEditing) ...[
                        const SizedBox(width: 8),
                        GhostButton(
                          density: ButtonDensity.icon,
                          onPressed: () {
                            final slug = _generateRandomSlug(
                              Random().nextInt(6) + 6,
                            );
                            setSheetState(() {
                              slugCtrl.text = slug;
                            });
                            validateSlug(slug, setSheetState);
                          },
                          child: const Icon(
                            BootstrapIcons.arrowClockwise,
                            size: 20,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (slugWarning != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      slugWarning!,
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.destructive,
                      ),
                    ).xSmall,
                  ],
                  if (suggestedSlug != null) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        setSheetState(() {
                          slugCtrl.text = suggestedSlug!;
                          slugWarning = null;
                          suggestedSlug = null;
                        });
                      },
                      child: Text(
                        'Suggested alternative: ${suggestedSlug!}',
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ).xSmall.semiBold,
                    ),
                  ],
                  const SizedBox(height: 24),

                  PrimaryButton(
                    onPressed:
                        (slugWarning != null ||
                            labelCtrl.text.isEmpty ||
                            slugCtrl.text.isEmpty ||
                            isCheckingSlug)
                        ? null
                        : () async {
                            bool ok;
                            if (isEditing) {
                              ok = await store.updateShare(editShare.id, {
                                'label': labelCtrl.text.trim(),
                              });
                            } else {
                              ok = await store.createShare(
                                slug: slugCtrl.text.trim(),
                                label: labelCtrl.text.trim(),
                                user: authStore.userId,
                                workspace: authStore.activeWorkspace ?? '',
                                sections: initialShare?.sections ?? [],
                                records: initialShare?.records ?? [],
                                status: 'active',
                              );
                            }
                            if (ok && ctx.mounted) {
                              closeSheet(context);
                              showToast(
                                context: context,
                                builder: (context, overlay) => SurfaceCard(
                                  child: Basic(
                                    leading: const Icon(
                                      BootstrapIcons.check,
                                      size: 16,
                                    ),
                                    title: Text(
                                      isEditing
                                          ? 'Public share link updated successfully'
                                          : (initialShare != null
                                                ? 'Public share link duplicated successfully'
                                                : 'Public share link created successfully'),
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                    child: Text(
                      isEditing
                          ? 'Save Changes'
                          : (initialShare != null
                                ? 'Duplicate Public Share'
                                : 'Create Public Share'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      position: OverlayPosition.bottom,
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

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(share.label).semiBold,
                        const SizedBox(width: 8),
                        _buildStatusBadge(theme),
                        const SizedBox(width: 8),
                        _buildViewsBadge(theme),
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
                        const SizedBox(width: 4),
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
              GhostButton(
                onPressed: () {
                  context.go('${AppRoutes.vault}?shareFilterId=${share.id}');
                },
                child: Icon(BootstrapIcons.funnel),
              ),
              Gap(8),
              if (!isRevoked) ...[
                // Primary Edit Selection Button
                GhostButton(
                  density: ButtonDensity.icon,
                  onPressed: () {
                    context.go('${AppRoutes.vault}?editShareId=${share.id}');
                  },
                  child: const Icon(BootstrapIcons.plusSlashMinus, size: 16),
                ),
                const SizedBox(width: 8),
              ],
              // Burger options menu button
              GhostButton(
                density: ButtonDensity.icon,
                onPressed: () => _showShareOptionsSheet(context),
                child: const Icon(BootstrapIcons.threeDotsVertical, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewsBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            BootstrapIcons.eye,
            size: 10,
            color: theme.colorScheme.mutedForeground,
          ),
          const SizedBox(width: 4),
          Text(
            '${share.views} ${share.views == 1 ? 'view' : 'views'}',
            style: TextStyle(color: theme.colorScheme.mutedForeground),
          ).xSmall.medium,
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ThemeData theme) {
    if (share.status == 'active') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          'Active',
          style: TextStyle(color: theme.colorScheme.primary),
        ).xSmall.semiBold,
      );
    }
    if (share.status == 'paused') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        child: const Text(
          'Paused',
          style: TextStyle(color: Colors.amber),
        ).xSmall.semiBold,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.destructive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: theme.colorScheme.destructive.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        'Revoked',
        style: TextStyle(color: theme.colorScheme.destructive),
      ).xSmall.semiBold,
    );
  }
}

class SlugInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text
        .toLowerCase()
        .replaceAll(' ', '-')
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '');

    int end = newValue.selection.end;
    if (end > text.length) end = text.length;
    if (end < 0) end = 0;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: end),
    );
  }
}
