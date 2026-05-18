import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../store/vault_store.dart';
import '../../auth/store/auth_store.dart';
import '../../shares/store/shares_store.dart';
import '../../templates/store/templates_store.dart';
import '../../../core/models/section.dart';
import '../../../core/models/record.dart' as models;
import '../../../core/models/link.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/data_table/filter_bar.dart';
import '../../../core/widgets/data_table/data_table_controller.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/text_formatters.dart';
import '../../../core/design/spacing.dart';
import 'record_create_sheet.dart';

class VaultScreen extends StatefulWidget {
  final String? editingShareId;
  final String? shareFilterId;

  const VaultScreen({super.key, this.editingShareId, this.shareFilterId});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  String? editingSectionId;
  late DataTableController<models.Record> _tableController;

  @override
  void initState() {
    super.initState();
    final store = context.read<VaultStore>();

    _tableController = DataTableController<models.Record>(
      getSourceItems: () => store.records.toList(),
      fieldGetters: {
        'label': (r) => r.label,
        'key': (r) => r.key,
        'value': (r) => r.value,
        'type': (r) => r.type,
        'format': (r) => r.format,
        'created': (r) => r.created ?? '',
      },
      defaultSort: 'created_desc',
    );
    _tableController.addListener(_onTableControllerChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.loadRecords();
      if (widget.editingShareId != null || widget.shareFilterId != null) {
        context.read<SharesStore>().loadShares();
      }
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
    final store = context.read<VaultStore>();
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
                  final count = store.recordCount;
                  final Widget primaryAction;
                  if (editingSectionId != null) {
                    primaryAction = PrimaryButton(
                      onPressed: () => setState(() => editingSectionId = null),
                      child: const Text('Done'),
                    );
                  } else if (widget.editingShareId != null ||
                      widget.shareFilterId != null) {
                    primaryAction = PrimaryButton(
                      onPressed: () => context.go(AppRoutes.shares),
                      child: const Text('Done'),
                    );
                  } else {
                    primaryAction = PrimaryButton(
                      density: ButtonDensity.icon,
                      onPressed: () =>
                          _showCreateOptionsSheet(context, store, authStore),
                      child: const Icon(BootstrapIcons.plus, size: 20),
                    );
                  }
                  return AppScreenHeader(
                    title: 'Vault',
                    badgeLabel: '$count ${count == 1 ? 'record' : 'records'}',
                    subtitle:
                        'Manage your personal information that is only visible to you.',
                    actions: [primaryAction],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              FilterBar<models.Record>(
                controller: _tableController,
                columns: const [
                  DataTableColumn(value: 'label', label: 'Label'),
                  DataTableColumn(value: 'key', label: 'Key'),
                  DataTableColumn(value: 'value', label: 'Value'),
                  DataTableColumn(value: 'type', label: 'Type'),
                  DataTableColumn(value: 'format', label: 'Format'),
                ],
              ),
              if (_tableController.filters.any(
                (f) =>
                    f.value.isNotEmpty &&
                    (f.column == 'value' ||
                        f.column == 'type' ||
                        f.column == 'format'),
              )) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      BootstrapIcons.info,
                      size: 14,
                      color: Theme.of(context).colorScheme.mutedForeground,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: const Text(
                        'Filters on Value, Type, or Format only apply to Records, while Label and Key apply to both.',
                      ).muted.xSmall,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        Expanded(
          child: Observer(
            builder: (_) {
              if (store.isLoading &&
                  store.records.isEmpty &&
                  store.sections.isEmpty) {
                return const Center(child: CircularProgressIndicator(size: 20));
              }

              if (store.errorMessage != null) {
                return Center(
                  child: Padding(
                    padding: horizontalPad,
                    child: Alert(
                      destructive: true,
                      leading: const Icon(BootstrapIcons.exclamation),
                      title: const Text('Failed to load data'),
                      content: Text(store.errorMessage!),
                    ),
                  ),
                );
              }

              if (store.records.isEmpty && store.sections.isEmpty) {
                return AppEmptyState(
                  icon: BootstrapIcons.safe,
                  title: 'Your vault is empty',
                  subtitle:
                      'Get started by creating a section or your first record.',
                  action: PrimaryButton(
                    onPressed: () =>
                        _showCreateOptionsSheet(context, store, authStore),
                    child: const Text('Create your first entry'),
                  ),
                );
              }

              if (editingSectionId != null) {
                // Render standard Record selection mode!
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: scrollbarMargin),
                  child: ListView(
                    padding: EdgeInsets.only(
                      left: innerPad,
                      right: innerPad,
                      bottom: 120,
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            Theme.of(context).radiusMd,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              BootstrapIcons.plusSlashMinus,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Editing section: ${store.sections.firstWhere((s) => s.id == editingSectionId).name}. Select entries below to include them in this section.',
                              ).small,
                            ),
                          ],
                        ),
                      ),
                      if (store.records.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Center(
                            child: const Text('No records created yet.').muted,
                          ),
                        )
                      else if (_tableController.filteredItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Center(
                            child: const Text(
                              'No records match your filters.',
                            ).muted,
                          ),
                        )
                      else
                        ..._tableController.filteredItems.map((record) {
                          Section? editingSection = store.sections.firstWhere(
                            (s) => s.id == editingSectionId,
                          );

                          return _RecordCard(
                            record: record,
                            isSelectableMode: true,
                            isSelected: editingSection.records.contains(
                              record.id,
                            ),
                            onToggleSelect: (bool selected) async {
                              final newRecords = List<String>.from(
                                editingSection.records,
                              );
                              if (selected && !newRecords.contains(record.id)) {
                                newRecords.add(record.id);
                              } else if (!selected) {
                                newRecords.remove(record.id);
                              }
                              final ok = await store.updateSection(
                                editingSection.id,
                                {'records': newRecords},
                              );
                              if (ok && context.mounted) {
                                showToast(
                                  context: context,
                                  builder: (context, overlay) => SurfaceCard(
                                    child: Basic(
                                      leading: const Icon(
                                        BootstrapIcons.check,
                                        size: 16,
                                      ),
                                      title: Text(
                                        selected
                                            ? 'Added record to section'
                                            : 'Removed record from section',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            },
                            onCopy: () {
                              Clipboard.setData(
                                ClipboardData(text: record.value),
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
                                        title: Text('Copied to clipboard'),
                                      ),
                                    ),
                              );
                            },
                            onEdit: () {},
                            onDelete: () =>
                                _confirmDeleteRecord(context, store, record.id),
                            onDuplicate: () => _showCreateSheet(
                              context,
                              store,
                              authStore,
                              initialRecord: record,
                            ),
                          );
                        }),
                    ],
                  ),
                );
              }

              // Render beautiful unified view!
              final rawFilteredRecords = _tableController.filteredItems;

              final sharesStore = context.watch<SharesStore>();
              Link? activeShareFilter;
              if (widget.shareFilterId != null &&
                  sharesStore.shares.isNotEmpty) {
                try {
                  activeShareFilter = sharesStore.shares.firstWhere(
                    (s) => s.id == widget.shareFilterId,
                  );
                } catch (_) {}
              }

              Link? activeShareEdit;
              if (widget.editingShareId != null &&
                  sharesStore.shares.isNotEmpty) {
                try {
                  activeShareEdit = sharesStore.shares.firstWhere(
                    (s) => s.id == widget.editingShareId,
                  );
                } catch (_) {}
              }

              // Let's filter records and sections if shareFilterId is active!
              List<models.Record> filteredRecords = rawFilteredRecords;
              List<Section> sectionsSource = store.sections.toList();

              if (activeShareFilter != null) {
                final allowedSectionIds = activeShareFilter.sections.toSet();
                final allowedRecordIdsFromSections = store.sections
                    .where((s) => allowedSectionIds.contains(s.id))
                    .expand((s) => s.records)
                    .toSet();
                final allowedRecordIds = activeShareFilter.records
                    .toSet()
                    .union(allowedRecordIdsFromSections);

                filteredRecords = rawFilteredRecords
                    .where((r) => allowedRecordIds.contains(r.id))
                    .toList();
                sectionsSource = store.sections
                    .where((s) => allowedSectionIds.contains(s.id))
                    .toList();
              }

              // Find which sections are visible
              final searchQuery = _tableController.searchQuery.toLowerCase();
              final visibleSections = sectionsSource.where((section) {
                // Get records in this section that also match the filters
                final sectionRecords = section.records
                    .map((id) {
                      try {
                        return filteredRecords.firstWhere((r) => r.id == id);
                      } catch (_) {
                        return null;
                      }
                    })
                    .whereType<models.Record>()
                    .toList();

                final matchesSearch =
                    section.name.toLowerCase().contains(searchQuery) ||
                    section.key.toLowerCase().contains(searchQuery);
                final matchesFilters = _sectionMatchesFilters(
                  section,
                  _tableController.filters,
                );
                return (matchesSearch && matchesFilters) ||
                    sectionRecords.isNotEmpty;
              }).toList();

              // Sort sections if active sort applies to them
              final sortBy = _tableController.sortBy;
              if (sortBy.isNotEmpty) {
                final parts = sortBy.split('_');
                if (parts.length >= 2) {
                  final col = parts.sublist(0, parts.length - 1).join('_');
                  final dir = parts.last;

                  if (col == 'label' || col == 'key' || col == 'created') {
                    visibleSections.sort((a, b) {
                      String valA = '';
                      String valB = '';
                      if (col == 'label') {
                        valA = a.name;
                        valB = b.name;
                      } else if (col == 'key') {
                        valA = a.key;
                        valB = b.key;
                      } else if (col == 'created') {
                        valA = a.created ?? '';
                        valB = b.created ?? '';
                      }

                      final comp = valA.toLowerCase().compareTo(
                        valB.toLowerCase(),
                      );
                      return dir == 'asc' ? comp : -comp;
                    });
                  }
                }
              }

              final assignedRecordIds = store.sections
                  .expand((s) => s.records)
                  .toSet();
              final ungroupedRecords = filteredRecords
                  .where((r) => !assignedRecordIds.contains(r.id))
                  .toList();

              // If absolutely nothing matches the filter anywhere in the sections or ungrouped lists, show search empty state
              final hasAnyMatching =
                  visibleSections.isNotEmpty || ungroupedRecords.isNotEmpty;

              if (!hasAnyMatching) {
                return Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Center(
                    child: const Text('No items match your filters.').muted,
                  ),
                );
              }

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: scrollbarMargin),
                child: ListView(
                  padding: EdgeInsets.only(
                    left: innerPad,
                    right: innerPad,
                    bottom: 120,
                  ),
                  children: [
                    if (activeShareFilter != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            Theme.of(context).radiusMd,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              BootstrapIcons.funnel,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Filtering by public share: "${activeShareFilter.label}". Only items shared are displayed.',
                              ).small,
                            ),
                            const SizedBox(width: 8),
                            GhostButton(
                              density: ButtonDensity.compact,
                              onPressed: () => context.go(AppRoutes.vault),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      ),
                    if (activeShareEdit != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            Theme.of(context).radiusMd,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              BootstrapIcons.plusSlashMinus,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Editing public share: "${activeShareEdit.label}". Select sections and records below to include them in this public share.',
                              ).small,
                            ),
                            const SizedBox(width: 8),
                            GhostButton(
                              density: ButtonDensity.compact,
                              onPressed: () => context.go(AppRoutes.shares),
                              child: const Text('Done'),
                            ),
                          ],
                        ),
                      ),
                    // Sections List
                    ...visibleSections.map((section) {
                      final sectionRecords = section.records
                          .map((id) {
                            try {
                              return filteredRecords.firstWhere(
                                (r) => r.id == id,
                              );
                            } catch (_) {
                              return null;
                            }
                          })
                          .whereType<models.Record>()
                          .toList();

                      return Collapsible(
                        children: [
                          _SectionCard(
                            section: section,
                            onAddRecords: () =>
                                setState(() => editingSectionId = section.id),
                            onRename: () => _showRenameSectionSheet(
                              context,
                              store,
                              section,
                            ),
                            onDelete: () => _confirmDeleteSection(
                              context,
                              store,
                              section.id,
                            ),
                            onDuplicate: () => _showCreateSectionSheet(
                              context,
                              store,
                              authStore,
                              initialSection: section,
                            ),
                            isSelectableMode: activeShareEdit != null,
                            isSelected:
                                activeShareEdit != null &&
                                activeShareEdit.sections.contains(section.id),
                            onToggleSelect: activeShareEdit == null
                                ? null
                                : (selected) async {
                                    final share = activeShareEdit;
                                    if (share == null) return;
                                    final newSections = List<String>.from(
                                      share.sections,
                                    );
                                    final newRecords = List<String>.from(
                                      share.records,
                                    );
                                    if (selected) {
                                      if (!newSections.contains(section.id)) {
                                        newSections.add(section.id);
                                      }
                                      for (final rId in section.records) {
                                        if (!newRecords.contains(rId)) {
                                          newRecords.add(rId);
                                        }
                                      }
                                    } else {
                                      newSections.remove(section.id);
                                      for (final rId in section.records) {
                                        newRecords.remove(rId);
                                      }
                                    }
                                    await sharesStore.updateShare(share.id, {
                                      'sections': newSections,
                                      'records': newRecords,
                                    });
                                    if (context.mounted) {
                                      showToast(
                                        context: context,
                                        builder: (context, overlay) => SurfaceCard(
                                          child: Basic(
                                            leading: const Icon(
                                              BootstrapIcons.check,
                                              size: 16,
                                            ),
                                            title: Text(
                                              selected
                                                  ? 'Added section to public share'
                                                  : 'Removed section from public share',
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                          ),
                          if (sectionRecords.isNotEmpty)
                            CollapsibleContent(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 32,
                                  bottom: 16,
                                  top: 8,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: sectionRecords.map((record) {
                                    return _RecordCard(
                                      record: record,
                                      isSelectableMode: activeShareEdit != null,
                                      isSelected:
                                          activeShareEdit != null &&
                                          activeShareEdit.records.contains(
                                            record.id,
                                          ),
                                      onToggleSelect: activeShareEdit == null
                                          ? null
                                          : (selected) async {
                                              final share = activeShareEdit;
                                              if (share == null) return;
                                              final newRecords =
                                                  List<String>.from(
                                                    share.records,
                                                  );
                                              if (selected) {
                                                if (!newRecords.contains(
                                                  record.id,
                                                )) {
                                                  newRecords.add(record.id);
                                                }
                                              } else {
                                                newRecords.remove(record.id);
                                              }
                                              await sharesStore.updateShare(
                                                share.id,
                                                {'records': newRecords},
                                              );
                                              if (context.mounted) {
                                                showToast(
                                                  context: context,
                                                  builder: (context, overlay) =>
                                                      SurfaceCard(
                                                        child: Basic(
                                                          leading: const Icon(
                                                            BootstrapIcons
                                                                .check,
                                                            size: 16,
                                                          ),
                                                          title: Text(
                                                            selected
                                                                ? 'Added record to public share'
                                                                : 'Removed record from public share',
                                                          ),
                                                        ),
                                                      ),
                                                );
                                              }
                                            },
                                      onCopy: () {
                                        Clipboard.setData(
                                          ClipboardData(text: record.value),
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
                                      onEdit: () => _showEditRecordSheet(
                                        context,
                                        store,
                                        record,
                                      ),
                                      onDelete: () => _confirmDeleteRecord(
                                        context,
                                        store,
                                        record.id,
                                      ),
                                      onDuplicate: () => _showCreateSheet(
                                        context,
                                        store,
                                        authStore,
                                        initialRecord: record,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                        ],
                      );
                    }),

                    // Ungrouped Records List
                    if (ungroupedRecords.isNotEmpty) ...[
                      if (visibleSections.isNotEmpty)
                        const SizedBox(height: 24),
                      Row(
                        children: [
                          Icon(
                            BootstrapIcons.folder2Open,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.mutedForeground,
                          ),
                          const SizedBox(width: 8),
                          const Text('Ungrouped Records').muted.semiBold,
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...ungroupedRecords.map((record) {
                        return _RecordCard(
                          record: record,
                          isSelectableMode: activeShareEdit != null,
                          isSelected:
                              activeShareEdit != null &&
                              activeShareEdit.records.contains(record.id),
                          onToggleSelect: activeShareEdit == null
                              ? null
                              : (selected) async {
                                  final share = activeShareEdit;
                                  if (share == null) return;
                                  final newRecords = List<String>.from(
                                    share.records,
                                  );
                                  if (selected) {
                                    if (!newRecords.contains(record.id)) {
                                      newRecords.add(record.id);
                                    }
                                  } else {
                                    newRecords.remove(record.id);
                                  }
                                  await sharesStore.updateShare(share.id, {
                                    'records': newRecords,
                                  });
                                  if (context.mounted) {
                                    showToast(
                                      context: context,
                                      builder: (context, overlay) => SurfaceCard(
                                        child: Basic(
                                          leading: const Icon(
                                            BootstrapIcons.check,
                                            size: 16,
                                          ),
                                          title: Text(
                                            selected
                                                ? 'Added record to public share'
                                                : 'Removed record from public share',
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                          onCopy: () {
                            Clipboard.setData(
                              ClipboardData(text: record.value),
                            );
                            showToast(
                              context: context,
                              builder: (context, overlay) => const SurfaceCard(
                                child: Basic(
                                  leading: Icon(BootstrapIcons.check, size: 16),
                                  title: Text('Copied to clipboard'),
                                ),
                              ),
                            );
                          },
                          onEdit: () =>
                              _showEditRecordSheet(context, store, record),
                          onDelete: () =>
                              _confirmDeleteRecord(context, store, record.id),
                          onDuplicate: () => _showCreateSheet(
                            context,
                            store,
                            authStore,
                            initialRecord: record,
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCreateOptionsSheet(
    BuildContext context,
    VaultStore store,
    AuthStore authStore,
  ) {
    openSheet(
      context: context,
      position: OverlayPosition.bottom,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Create New').h4,
              const SizedBox(height: 4),
              const Text('Select what you would like to create.').muted.small,
              const SizedBox(height: 24),
              GhostButton(
                onPressed: () {
                  closeSheet(sheetContext);
                  _showCreateSectionSheet(context, store, authStore);
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(theme.radiusSm),
                      ),
                      child: Icon(
                        BootstrapIcons.folderPlus,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('New Section').semiBold,
                          const SizedBox(height: 2),
                          const Text(
                            'Group records together within a section.',
                          ).muted.small,
                        ],
                      ),
                    ),
                    Icon(
                      BootstrapIcons.arrowRight,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GhostButton(
                onPressed: () {
                  closeSheet(sheetContext);
                  _showCreateSheet(context, store, authStore);
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(theme.radiusSm),
                      ),
                      child: Icon(
                        BootstrapIcons.filePlus,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('New Record').semiBold,
                          const SizedBox(height: 2),
                          const Text(
                            'Create a new key-value digital record.',
                          ).muted.small,
                        ],
                      ),
                    ),
                    Icon(
                      BootstrapIcons.arrowRight,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GhostButton(
                onPressed: () {
                  closeSheet(sheetContext);
                  _showFromTemplateSheet(context, store, authStore);
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(theme.radiusSm),
                      ),
                      child: Icon(
                        BootstrapIcons.cardList,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('From Template').semiBold,
                          const SizedBox(height: 2),
                          const Text(
                            'Generate structure from a workspace template.',
                          ).muted.small,
                        ],
                      ),
                    ),
                    Icon(
                      BootstrapIcons.arrowRight,
                      color: theme.colorScheme.mutedForeground,
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

  void _showFromTemplateSheet(
    BuildContext context,
    VaultStore store,
    AuthStore authStore,
  ) {
    final templatesStore = context.read<TemplatesStore>();
    // Pre-load templates to make sure we have the latest
    templatesStore.loadTemplates(authStore.activeWorkspace ?? '');

    openSheet(
      context: context,
      position: OverlayPosition.bottom,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Create from Template').h4.semiBold,
              const SizedBox(height: 4),
              const Text(
                'Select a structural blueprint to instantiate sections and records in your vault.',
              ).muted.small,
              const SizedBox(height: 20),

              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: Observer(
                  builder: (_) {
                    if (templatesStore.isLoading &&
                        templatesStore.templates.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(size: 24),
                        ),
                      );
                    }

                    if (templatesStore.templates.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32.0),
                          child: Column(
                            children: [
                              Icon(
                                BootstrapIcons.cardList,
                                size: 32,
                                color: theme.colorScheme.mutedForeground,
                              ),
                              const SizedBox(height: 12),
                              const Text('No templates available').semiBold,
                              const SizedBox(height: 4),
                              Text(
                                'Admins can configure templates in Settings.',
                                textAlign: TextAlign.center,
                              ).muted.small,
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: templatesStore.templates.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final template = templatesStore.templates[index];
                        final sections =
                            template.schema['sections'] as List<dynamic>? ?? [];
                        final records =
                            template.schema['records'] as List<dynamic>? ?? [];

                        return GhostButton(
                          onPressed: () async {
                            showToast(
                              context: context,
                              builder: (c, o) => const SurfaceCard(
                                child: Basic(
                                  leading: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  title: Text(
                                    'Instantiating template blueprints...',
                                  ),
                                ),
                              ),
                            );

                            final ok = await store.createFromTemplate(
                              template: template,
                              user: authStore.userId,
                              workspace: authStore.activeWorkspace ?? '',
                            );

                            if (sheetContext.mounted) {
                              closeSheet(sheetContext);
                            }

                            if (ok && context.mounted) {
                              showToast(
                                context: context,
                                builder: (c, o) => const SurfaceCard(
                                  child: Basic(
                                    leading: Icon(
                                      BootstrapIcons.checkCircle,
                                      color: Colors.green,
                                      size: 16,
                                    ),
                                    title: Text(
                                      'Vault items generated successfully!',
                                    ),
                                  ),
                                ),
                              );
                            } else if (context.mounted) {
                              showToast(
                                context: context,
                                builder: (c, o) => SurfaceCard(
                                  child: Basic(
                                    leading: const Icon(
                                      BootstrapIcons.exclamationOctagon,
                                      color: Colors.red,
                                      size: 16,
                                    ),
                                    title: const Text('Generation failed'),
                                    subtitle: Text(
                                      store.errorMessage ?? 'Unknown error',
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                          child: Row(
                            children: [
                              Icon(
                                BootstrapIcons.cardList,
                                color: theme.colorScheme.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(template.name).semiBold,
                                    const SizedBox(height: 2),
                                    Text(
                                      '${sections.length} sections • ${records.length} root records',
                                    ).muted.xSmall,
                                  ],
                                ),
                              ),
                              Icon(
                                BootstrapIcons.chevronRight,
                                size: 14,
                                color: theme.colorScheme.mutedForeground,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateSectionSheet(
    BuildContext context,
    VaultStore store,
    AuthStore authStore, {
    Section? initialSection,
  }) {
    store.clearError();
    final keyCtrl = TextEditingController(
      text: initialSection != null ? '${initialSection.key}_1' : '',
    );
    final nameCtrl = TextEditingController(text: initialSection?.name ?? '');
    String? localError;
    String? keyWarning;
    String? suggestedKey;

    void validateKey(String input, StateSetter setSheetState) {
      if (input.isEmpty) {
        setSheetState(() {
          keyWarning = null;
          suggestedKey = null;
        });
        return;
      }

      final exists = store.sections.any((s) => s.key == input);
      if (exists) {
        final alt = _generateAlternativeKey(input, true, store);
        setSheetState(() {
          keyWarning = 'This key is already taken.';
          suggestedKey = alt;
        });
      } else {
        setSheetState(() {
          keyWarning = null;
          suggestedKey = null;
        });
      }
    }

    bool checkedOnStart = false;

    openSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            if (!checkedOnStart && keyCtrl.text.isNotEmpty) {
              checkedOnStart = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                validateKey(keyCtrl.text, setSheetState);
              });
            }
            return Observer(
              builder: (context) {
                final _ = store.errorMessage;
                return Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        initialSection != null ? 'Duplicate' : 'New Section',
                      ).h4,
                      const SizedBox(height: 4),
                      Text(
                        initialSection != null
                            ? 'Duplicate this section with a new unique key.'
                            : 'Group records together within a section.',
                      ).muted,
                      const SizedBox(height: 20),

                      const Text('Name').semiBold,
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameCtrl,
                        placeholder: const Text('My Section'),
                      ),
                      const SizedBox(height: 14),

                      const Text('Key').semiBold,
                      const SizedBox(height: 6),
                      TextField(
                        controller: keyCtrl,
                        placeholder: const Text('section_key'),
                        inputFormatters: [KeyInputFormatter()],
                        onChanged: (v) => validateKey(v, setSheetState),
                      ),
                      if (keyWarning != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              BootstrapIcons.exclamation,
                              size: 14,
                              color: Theme.of(context).colorScheme.destructive,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                keyWarning!,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.destructive,
                                ),
                              ).xSmall,
                            ),
                          ],
                        ),
                      ],
                      if (suggestedKey != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              BootstrapIcons.lightbulb,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            const Text('Suggestion: ').small,
                            GestureDetector(
                              onTap: () {
                                keyCtrl.text = suggestedKey!;
                                validateKey(suggestedKey!, setSheetState);
                              },
                              child: Text(
                                suggestedKey!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ).semiBold.small,
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),

                      if (localError != null || store.errorMessage != null) ...[
                        Alert(
                          destructive: true,
                          leading: const Icon(BootstrapIcons.exclamation),
                          title: const Text('Error'),
                          content: Text(localError ?? store.errorMessage!),
                        ),
                        const SizedBox(height: 16),
                      ],

                      PrimaryButton(
                        onPressed: () async {
                          final keyInput = keyCtrl.text.trim();
                          final nameInput = nameCtrl.text.trim();
                          if (keyInput.isEmpty || nameInput.isEmpty) return;

                          final exists = store.sections.any(
                            (s) => s.key == keyInput,
                          );
                          if (exists) {
                            setSheetState(() {
                              localError = 'This key is already taken.';
                            });
                            return;
                          }

                          setSheetState(() {
                            localError = null;
                          });

                          final ok = await store.createSection(
                            key: keyInput,
                            name: nameInput,
                            recordIds: initialSection?.records ?? [],
                            user: authStore.userId,
                            workspace: authStore.activeWorkspace ?? '',
                          );
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
                                    initialSection != null
                                        ? 'Section duplicated successfully'
                                        : 'Section created successfully',
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                        child: Text(
                          initialSection != null
                              ? 'Duplicate'
                              : 'Create Section',
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
      position: OverlayPosition.bottom,
    );
  }

  // Record-create / duplicate moved to a 2-step bottom sheet
  // (record_create_sheet.dart) so the form no longer overflows on phones.
  void _showCreateSheet(
    BuildContext context,
    VaultStore store,
    AuthStore authStore, {
    models.Record? initialRecord,
  }) {
    openRecordCreateSheet(
      context: context,
      store: store,
      authStore: authStore,
      initialRecord: initialRecord,
    );
  }

  bool _sectionMatchesFilters(Section section, List<DataTableFilter> filters) {
    for (final f in filters) {
      if (f.value.isEmpty) continue;
      String? val;
      if (f.column == 'label') {
        val = section.name;
      } else if (f.column == 'key') {
        val = section.key;
      } else if (f.column == 'created') {
        val = section.created ?? '';
      }

      if (val != null) {
        final target = f.value.toLowerCase();
        final source = val.toLowerCase();
        bool match = true;
        switch (f.operator) {
          case 'equals':
            match = source == target;
            break;
          case 'contains':
            match = source.contains(target);
            break;
          case 'starts_with':
            match = source.startsWith(target);
            break;
          case 'ends_with':
            match = source.endsWith(target);
            break;
        }
        if (!match) return false;
      }
    }
    return true;
  }

  String _generateAlternativeKey(
    String baseKey,
    bool isSection,
    VaultStore store,
  ) {
    String sanitized = baseKey.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    if (sanitized.isEmpty) {
      sanitized = isSection ? 'section' : 'key';
    }

    int counter = 1;
    while (true) {
      final candidate = '${sanitized}_$counter';
      final exists = isSection
          ? store.sections.any((s) => s.key == candidate)
          : store.records.any((r) => r.key == candidate);
      if (!exists) {
        return candidate;
      }
      counter++;
    }
  }

  void _showRenameSectionSheet(
    BuildContext context,
    VaultStore store,
    Section section,
  ) {
    store.clearError();
    final nameCtrl = TextEditingController(text: section.name);
    String? localError;

    openSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Observer(
            builder: (context) {
              final _ = store.errorMessage;
              return Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Rename Section').h4,
                    const SizedBox(height: 4),
                    const Text(
                      'Change the display name of this section.',
                    ).muted,
                    const SizedBox(height: 20),

                    const Text('Name').semiBold,
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      placeholder: const Text('My Section'),
                    ),
                    const SizedBox(height: 14),

                    const Text('Key').semiBold,
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.muted,
                        borderRadius: BorderRadius.circular(
                          Theme.of(context).radiusMd,
                        ),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.border,
                        ),
                      ),
                      child: Text(section.key).mono.muted.small,
                    ),
                    const SizedBox(height: 24),

                    if (localError != null || store.errorMessage != null) ...[
                      Alert(
                        destructive: true,
                        leading: const Icon(BootstrapIcons.exclamation),
                        title: const Text('Error'),
                        content: Text(localError ?? store.errorMessage!),
                      ),
                      const SizedBox(height: 16),
                    ],

                    PrimaryButton(
                      onPressed: () async {
                        final nameInput = nameCtrl.text.trim();
                        if (nameInput.isEmpty) return;

                        setSheetState(() {
                          localError = null;
                        });

                        final ok = await store.updateSection(section.id, {
                          'name': nameInput,
                        });
                        if (ok && ctx.mounted) {
                          closeSheet(context);
                          showToast(
                            context: context,
                            builder: (context, overlay) => const SurfaceCard(
                              child: Basic(
                                leading: Icon(BootstrapIcons.check, size: 16),
                                title: Text('Section updated successfully'),
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      position: OverlayPosition.bottom,
    );
  }

  void _showEditRecordSheet(
    BuildContext context,
    VaultStore store,
    models.Record record,
  ) {
    store.clearError();
    final labelCtrl = TextEditingController(text: record.label);
    final valueCtrl = TextEditingController(text: record.value);
    String selectedType = record.type;
    String selectedFormat = record.format;

    openSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Observer(
            builder: (context) {
              final _ = store.errorMessage;
              return Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Edit Record').h4,
                    const SizedBox(height: 4),
                    const Text(
                      'Modify record parameters in your workspace.',
                    ).muted,
                    const SizedBox(height: 20),

                    const Text('Label').semiBold,
                    const SizedBox(height: 6),
                    TextField(
                      controller: labelCtrl,
                      placeholder: const Text('My Secret'),
                    ),
                    const SizedBox(height: 14),

                    const Text('Key').semiBold,
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.muted,
                        borderRadius: BorderRadius.circular(
                          Theme.of(context).radiusMd,
                        ),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.border,
                        ),
                      ),
                      child: Text(record.key).mono.muted.small,
                    ),
                    const SizedBox(height: 14),

                    const Text('Value').semiBold,
                    const SizedBox(height: 6),
                    TextField(
                      controller: valueCtrl,
                      placeholder: const Text('sk-1234...'),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Type').semiBold,
                              const SizedBox(height: 6),
                              Select<String>(
                                value: selectedType,
                                onChanged: (v) {
                                  if (v != null) {
                                    setSheetState(() => selectedType = v);
                                  }
                                },
                                itemBuilder: (ctx, item) => Text(item),
                                popup: SelectPopup(
                                  items: SelectItemList(
                                    children: const [
                                      SelectItemButton(
                                        value: 'text',
                                        child: Text('text'),
                                      ),
                                      SelectItemButton(
                                        value: 'number',
                                        child: Text('number'),
                                      ),
                                    ],
                                  ),
                                ).call,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Hidden Value').semiBold,
                              const SizedBox(height: 10),
                              Switch(
                                value: selectedFormat == 'hidden',
                                onChanged: (checked) {
                                  setSheetState(() {
                                    selectedFormat = checked
                                        ? 'hidden'
                                        : 'default';
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (store.errorMessage != null) ...[
                      Alert(
                        destructive: true,
                        leading: const Icon(BootstrapIcons.exclamation),
                        title: const Text('Error'),
                        content: Text(store.errorMessage!),
                      ),
                      const SizedBox(height: 16),
                    ],

                    PrimaryButton(
                      onPressed: () async {
                        if (valueCtrl.text.isEmpty || labelCtrl.text.isEmpty) {
                          return;
                        }
                        final ok = await store.updateRecord(record.id, {
                          'value': valueCtrl.text,
                          'label': labelCtrl.text,
                          'type': selectedType,
                          'format': selectedFormat,
                        });
                        if (ok && ctx.mounted) {
                          closeSheet(context);
                          showToast(
                            context: context,
                            builder: (context, overlay) => const SurfaceCard(
                              child: Basic(
                                leading: Icon(BootstrapIcons.check, size: 16),
                                title: Text('Record updated successfully'),
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      position: OverlayPosition.bottom,
    );
  }

  void _confirmDeleteRecord(BuildContext context, VaultStore store, String id) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete record'),
          content: const Text(
            'This action cannot be undone. This will permanently delete the record.',
          ),
          actions: [
            OutlineButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            DestructiveButton(
              onPressed: () async {
                final ok = await store.deleteRecord(id);
                if (context.mounted) Navigator.of(context).pop();
                if (ok && context.mounted) {
                  showToast(
                    context: context,
                    builder: (context, overlay) => const SurfaceCard(
                      child: Basic(
                        leading: Icon(BootstrapIcons.check, size: 16),
                        title: Text('Record deleted successfully'),
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

  void _confirmDeleteSection(
    BuildContext context,
    VaultStore store,
    String id,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete section'),
          content: const Text(
            'This action cannot be undone. This will permanently delete the section.',
          ),
          actions: [
            OutlineButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            DestructiveButton(
              onPressed: () async {
                final ok = await store.deleteSection(id);
                if (context.mounted) Navigator.of(context).pop();
                if (ok && context.mounted) {
                  showToast(
                    context: context,
                    builder: (context, overlay) => const SurfaceCard(
                      child: Basic(
                        leading: Icon(BootstrapIcons.check, size: 16),
                        title: Text('Section deleted successfully'),
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
}

class _SectionCard extends StatelessWidget {
  final Section section;
  final VoidCallback onAddRecords;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final bool isSelectableMode;
  final bool isSelected;
  final ValueChanged<bool>? onToggleSelect;

  const _SectionCard({
    required this.section,
    required this.onAddRecords,
    required this.onRename,
    required this.onDelete,
    required this.onDuplicate,
    this.isSelectableMode = false,
    this.isSelected = false,
    this.onToggleSelect,
  });

  void _showSectionOptionsSheet(BuildContext context) {
    openSheet(
      context: context,
      position: OverlayPosition.bottom,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(section.name).h4,
              const SizedBox(height: 4),
              Text(
                '${section.key} • ${section.records.length} records',
              ).muted.small,
              const SizedBox(height: 24),
              GhostButton(
                onPressed: () {
                  closeSheet(sheetContext);
                  onRename();
                },
                child: Row(
                  children: [
                    const Icon(BootstrapIcons.pen, size: 20),
                    const SizedBox(width: 16),
                    Expanded(child: Text('Rename').semiBold),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GhostButton(
                onPressed: () {
                  closeSheet(sheetContext);
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
              const SizedBox(height: 12),
              GhostButton(
                onPressed: () {
                  closeSheet(sheetContext);
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
                        'Delete',
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
    final collapsibleState = Data.maybeOf<CollapsibleStateData>(context);
    final isExpanded = collapsibleState?.isExpanded ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: collapsibleState?.handleTap,
                child: Row(
                  children: [
                    if (isSelectableMode) ...[
                      Checkbox(
                        state: isSelected
                            ? CheckboxState.checked
                            : CheckboxState.unchecked,
                        onChanged: (state) => onToggleSelect?.call(
                          state == CheckboxState.checked,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (collapsibleState != null) ...[
                      AnimatedRotation(
                        turns: isExpanded ? 0.25 : 0.0,
                        duration: const Duration(milliseconds: 150),
                        child: const Icon(
                          BootstrapIcons.chevronRight,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(
                      BootstrapIcons.folder,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(section.name).semiBold,
                          const SizedBox(height: 2),
                          Text(
                            '${section.key} • ${section.records.length} records',
                          ).muted.xSmall,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!isSelectableMode) ...[
              const SizedBox(width: 8),
              GhostButton(
                density: ButtonDensity.icon,
                onPressed: onAddRecords,
                child: const Icon(BootstrapIcons.plusSlashMinus, size: 16),
              ),
              const SizedBox(width: 8),
              GhostButton(
                density: ButtonDensity.icon,
                onPressed: () => _showSectionOptionsSheet(context),
                child: const Icon(BootstrapIcons.threeDotsVertical, size: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecordCard extends StatefulWidget {
  final dynamic record;
  final bool isSelectableMode;
  final bool isSelected;
  final ValueChanged<bool>? onToggleSelect;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  const _RecordCard({
    required this.record,
    this.isSelectableMode = false,
    this.isSelected = false,
    this.onToggleSelect,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
  });

  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> {
  bool _isObscured = true;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.record.isHidden;
  }

  @override
  void didUpdateWidget(covariant _RecordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.record.id != oldWidget.record.id ||
        widget.record.isHidden != oldWidget.record.isHidden) {
      _isObscured = widget.record.isHidden;
    }
  }

  void _showRecordOptionsSheet(BuildContext context) {
    openSheet(
      context: context,
      position: OverlayPosition.bottom,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.record.label).h4,
              const SizedBox(height: 4),
              Text(widget.record.key).mono.muted.small,
              const SizedBox(height: 24),
              GhostButton(
                onPressed: () {
                  closeSheet(sheetContext);
                  widget.onEdit();
                },
                child: Row(
                  children: [
                    const Icon(BootstrapIcons.pen, size: 20),
                    const SizedBox(width: 16),
                    Expanded(child: Text('Edit').semiBold),
                    Icon(
                      BootstrapIcons.arrowRight,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GhostButton(
                onPressed: () {
                  closeSheet(sheetContext);
                  widget.onDuplicate();
                },
                child: Row(
                  children: [
                    const Icon(BootstrapIcons.nodePlus, size: 20),
                    const SizedBox(width: 16),
                    Expanded(child: Text('Duplicate').semiBold),
                    Icon(
                      BootstrapIcons.arrowRight,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GhostButton(
                onPressed: () {
                  closeSheet(sheetContext);
                  widget.onDelete();
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
                        'Delete',
                        style: TextStyle(color: theme.colorScheme.destructive),
                      ).semiBold,
                    ),
                    Icon(
                      BootstrapIcons.arrowRight,
                      color: theme.colorScheme.mutedForeground,
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
    final isHiddenFormat = widget.record.isHidden;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isSelectableMode) ...[
              Checkbox(
                state: widget.isSelected
                    ? CheckboxState.checked
                    : CheckboxState.unchecked,
                onChanged: (state) =>
                    widget.onToggleSelect?.call(state == CheckboxState.checked),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.record.label).semiBold,
                            const SizedBox(height: 2),
                            Text(widget.record.key).mono.muted.xSmall,
                          ],
                        ),
                      ),
                      SecondaryBadge(child: Text(widget.record.type)),
                      if (isHiddenFormat) ...[
                        const SizedBox(width: 6),
                        const OutlineBadge(child: Text('hidden')),
                      ],
                      if (widget.record.isAlias) ...[
                        const SizedBox(width: 6),
                        const OutlineBadge(child: Text('alias')),
                      ],
                      if (!widget.isSelectableMode) ...[
                        const SizedBox(width: 8),
                        GhostButton(
                          density: ButtonDensity.icon,
                          onPressed: widget.onCopy,
                          child: const Icon(BootstrapIcons.copy, size: 14),
                        ),
                        GhostButton(
                          density: ButtonDensity.icon,
                          onPressed: () => _showRecordOptionsSheet(context),
                          child: const Icon(
                            BootstrapIcons.threeDotsVertical,
                            size: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!widget.isSelectableMode) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.muted,
                        borderRadius: BorderRadius.circular(theme.radiusSm),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _isObscured
                                  ? '••••••••••••••••'
                                  : widget.record.value,
                            ).mono.muted.xSmall,
                          ),
                          if (isHiddenFormat) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isObscured = !_isObscured;
                                });
                              },
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Icon(
                                  _isObscured
                                      ? BootstrapIcons.eye
                                      : BootstrapIcons.eyeSlash,
                                  size: 14,
                                  color: theme.colorScheme.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
