import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'data_table_controller.dart';

/// A beautiful and premium filter bar widget styled using shadcn_flutter
/// to support search, multi-column filters, and sorting.
class FilterBar<T> extends StatefulWidget {
  final DataTableController<T> controller;
  final List<DataTableColumn> columns;

  const FilterBar({super.key, required this.controller, required this.columns});

  @override
  State<FilterBar<T>> createState() => _FilterBarState<T>();
}

class _FilterBarState<T> extends State<FilterBar<T>> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.controller.searchQuery,
    );
    _searchController.addListener(_onSearchChanged);
    widget.controller.addListener(_onControllerChanged);
  }

  void _onSearchChanged() {
    if (widget.controller.searchQuery != _searchController.text) {
      widget.controller.searchQuery = _searchController.text;
    }
  }

  void _onControllerChanged() {
    if (_searchController.text != widget.controller.searchQuery) {
      // Temporarily remove listener to avoid loop
      _searchController.removeListener(_onSearchChanged);
      _searchController.text = widget.controller.searchQuery;
      _searchController.addListener(_onSearchChanged);
    }
  }

  @override
  void didUpdateWidget(covariant FilterBar<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _searchController.text = widget.controller.searchQuery;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.of(context).size.width < 500;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final filters = widget.controller.filters;
        final hasActiveFilters = filters.isNotEmpty;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Global Search Box
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _searchController,
                  placeholder: const Text('Search...'),
                  features: [
                    InputFeature.leading(
                      Icon(
                        BootstrapIcons.search,
                        size: 16,
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // 2. Filters Button
            Builder(
              builder: (buttonContext) {
                return OutlineButton(
                  density: isCompact
                      ? ButtonDensity.icon
                      : ButtonDensity.normal,
                  leading: isCompact
                      ? null
                      : const Icon(BootstrapIcons.funnelFill, size: 16),
                  onPressed: () => _showFiltersPopover(buttonContext),
                  child: isCompact
                      ? const Icon(BootstrapIcons.funnelFill, size: 16)
                      : Text(
                          hasActiveFilters
                              ? 'Filters (${filters.length})'
                              : 'Filters',
                        ),
                );
              },
            ),
            const SizedBox(width: 8),

            // 3. Sort Button
            Builder(
              builder: (buttonContext) {
                return OutlineButton(
                  density: isCompact
                      ? ButtonDensity.icon
                      : ButtonDensity.normal,
                  leading: isCompact
                      ? null
                      : const Icon(BootstrapIcons.sortDown, size: 16),
                  onPressed: () => _showSortPopover(buttonContext),
                  child: isCompact
                      ? const Icon(BootstrapIcons.sortDown, size: 16)
                      : const Text('Sort'),
                );
              },
            ),

            // 4. Clear Filters External Button
            if (hasActiveFilters) ...[
              const SizedBox(width: 8),
              GhostButton(
                density: isCompact ? ButtonDensity.icon : ButtonDensity.normal,
                leading: isCompact
                    ? null
                    : Icon(
                        BootstrapIcons.x,
                        size: 16,
                        color: theme.colorScheme.destructive,
                      ),
                onPressed: () => widget.controller.clearFilters(),
                child: isCompact
                    ? Icon(
                        BootstrapIcons.x,
                        size: 16,
                        color: theme.colorScheme.destructive,
                      )
                    : Text(
                        'Clear Filters',
                        style: TextStyle(color: theme.colorScheme.destructive),
                      ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _showFiltersPopover(BuildContext buttonContext) {
    showPopover(
      context: buttonContext,
      alignment: Alignment.bottomLeft,
      builder: (popoverContext) {
        return SurfaceCard(
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, child) {
              final filters = widget.controller.filters;

              return Container(
                width: 500,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Popover Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Filters').semiBold,
                        SecondaryButton(
                          leading: const Icon(BootstrapIcons.plus, size: 14),
                          onPressed: () {
                            if (widget.columns.isNotEmpty) {
                              widget.controller.addFilter(
                                widget.columns.first.value,
                              );
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Filter list or empty state
                    if (filters.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: const Text('No filters applied').muted.small,
                        ),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: SingleChildScrollView(
                          child: Column(
                            children: filters.map((f) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: FilterRowWidget(
                                  filter: f,
                                  columns: widget.columns,
                                  onUpdate: (id, {column, operator, value}) {
                                    widget.controller.updateFilter(
                                      id,
                                      column: column,
                                      operator: operator,
                                      value: value,
                                    );
                                  },
                                  onDelete: () =>
                                      widget.controller.removeFilter(f.id),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                    // Clear Actions inside Popover
                    if (filters.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      GhostButton(
                        onPressed: () {
                          widget.controller.clearFilters();
                        },
                        child: const Text('Clear All Filters'),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showSortPopover(BuildContext buttonContext) {
    showPopover(
      context: buttonContext,
      alignment: Alignment.bottomLeft,
      builder: (popoverContext) {
        return SurfaceCard(
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, child) {
              final activeSort = widget.controller.sortBy;

              return SizedBox(
                width: 260,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sort Options for Columns passed
                    ...widget.columns.expand((col) {
                      final ascKey = '${col.value}_asc';
                      final descKey = '${col.value}_desc';

                      return [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: activeSort == ascKey
                              ? PrimaryButton(
                                  density: ButtonDensity.normal,
                                  onPressed: () {
                                    widget.controller.setSort(ascKey);
                                  },
                                  child: Text(
                                    '${col.label} (A-Z)',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )
                              : GhostButton(
                                  density: ButtonDensity.normal,
                                  onPressed: () {
                                    widget.controller.setSort(ascKey);
                                  },
                                  child: Text(
                                    '${col.label} (A-Z)',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: activeSort == descKey
                              ? PrimaryButton(
                                  density: ButtonDensity.normal,
                                  onPressed: () {
                                    widget.controller.setSort(descKey);
                                  },
                                  child: Text(
                                    '${col.label} (Z-A)',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )
                              : GhostButton(
                                  density: ButtonDensity.normal,
                                  onPressed: () {
                                    widget.controller.setSort(descKey);
                                  },
                                  child: Text(
                                    '${col.label} (Z-A)',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                        ),
                      ];
                    }),

                    const Divider(height: 16),

                    // Time Sort Options
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: activeSort == 'created_desc'
                          ? PrimaryButton(
                              density: ButtonDensity.normal,
                              onPressed: () {
                                widget.controller.setSort('created_desc');
                              },
                              child: const Text(
                                'Newest First',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : GhostButton(
                              density: ButtonDensity.normal,
                              onPressed: () {
                                widget.controller.setSort('created_desc');
                              },
                              child: const Text(
                                'Newest First',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: activeSort == 'created_asc'
                          ? PrimaryButton(
                              density: ButtonDensity.normal,
                              onPressed: () {
                                widget.controller.setSort('created_asc');
                              },
                              child: const Text(
                                'Oldest First',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : GhostButton(
                              density: ButtonDensity.normal,
                              onPressed: () {
                                widget.controller.setSort('created_asc');
                              },
                              child: const Text(
                                'Oldest First',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// A stateful widget representing a single filter row inside the popover list.
/// Implemented as a stateful widget to preserve text field keyboard focus while typing.
class FilterRowWidget extends StatefulWidget {
  final DataTableFilter filter;
  final List<DataTableColumn> columns;
  final Function(String, {String? column, String? operator, String? value})
  onUpdate;
  final VoidCallback onDelete;

  const FilterRowWidget({
    super.key,
    required this.filter,
    required this.columns,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<FilterRowWidget> createState() => _FilterRowWidgetState();
}

class _FilterRowWidgetState extends State<FilterRowWidget> {
  late TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController(text: widget.filter.value);
    _valueController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (widget.filter.value != _valueController.text) {
      widget.onUpdate(widget.filter.id, value: _valueController.text);
    }
  }

  @override
  void didUpdateWidget(covariant FilterRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter.value != widget.filter.value &&
        _valueController.text != widget.filter.value) {
      _valueController.removeListener(_onTextChanged);
      _valueController.text = widget.filter.value;
      _valueController.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    _valueController.removeListener(_onTextChanged);
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Column Selector Dropdown
        Expanded(
          flex: 4,
          child: SizedBox(
            height: 32,
            child: Select<String>(
              value: widget.filter.column,
              onChanged: (v) {
                if (v != null) {
                  widget.onUpdate(widget.filter.id, column: v);
                }
              },
              itemBuilder: (ctx, item) {
                final match = widget.columns.firstWhere(
                  (c) => c.value == item,
                  orElse: () => DataTableColumn(value: item, label: item),
                );
                return Text(match.label, style: const TextStyle(fontSize: 12));
              },
              popup: SelectPopup(
                items: SelectItemList(
                  children: widget.columns.map((col) {
                    return SelectItemButton(
                      value: col.value,
                      child: Text(
                        col.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),
              ).call,
            ),
          ),
        ),
        const SizedBox(width: 4),

        // Operator Selector Dropdown
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 32,
            child: Select<String>(
              value: widget.filter.operator,
              onChanged: (v) {
                if (v != null) {
                  widget.onUpdate(widget.filter.id, operator: v);
                }
              },
              itemBuilder: (ctx, item) {
                final label = _getOperatorLabel(item);
                return Text(label, style: const TextStyle(fontSize: 12));
              },
              popup: SelectPopup(
                items: SelectItemList(
                  children: const [
                    SelectItemButton(
                      value: 'contains',
                      child: Text('contains', style: TextStyle(fontSize: 12)),
                    ),
                    SelectItemButton(
                      value: 'equals',
                      child: Text('equals', style: TextStyle(fontSize: 12)),
                    ),
                    SelectItemButton(
                      value: 'starts_with',
                      child: Text(
                        'starts with',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    SelectItemButton(
                      value: 'ends_with',
                      child: Text('ends with', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ).call,
            ),
          ),
        ),
        const SizedBox(width: 4),

        // Value Input Field
        Expanded(
          flex: 4,
          child: SizedBox(
            height: 32,
            child: TextField(
              controller: _valueController,
              placeholder: const Text(
                'Value...',
                style: TextStyle(fontSize: 11),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        const SizedBox(width: 4),

        // Delete Row Button
        GhostButton(
          density: ButtonDensity.icon,
          onPressed: widget.onDelete,
          child: Icon(
            BootstrapIcons.x,
            size: 14,
            color: theme.colorScheme.mutedForeground,
          ),
        ),
      ],
    );
  }

  String _getOperatorLabel(String op) {
    switch (op) {
      case 'contains':
        return 'contains';
      case 'equals':
        return 'equals';
      case 'starts_with':
        return 'starts with';
      case 'ends_with':
        return 'ends with';
      default:
        return op;
    }
  }
}
