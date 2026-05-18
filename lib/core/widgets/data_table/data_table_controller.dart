import 'package:flutter/foundation.dart';

/// Represents a column in the filterable/sortable data table.
class DataTableColumn {
  final String value;
  final String label;

  const DataTableColumn({required this.value, required this.label});
}

/// Represents an active filter in the data table.
class DataTableFilter {
  final String id;
  final String column;
  final String operator; // 'contains' | 'equals' | 'starts_with' | 'ends_with'
  final String value;

  DataTableFilter({
    required this.id,
    required this.column,
    required this.operator,
    required this.value,
  });

  DataTableFilter copyWith({
    String? id,
    String? column,
    String? operator,
    String? value,
  }) {
    return DataTableFilter(
      id: id ?? this.id,
      column: column ?? this.column,
      operator: operator ?? this.operator,
      value: value ?? this.value,
    );
  }
}

/// Reusable controller that manages the state and logic for search, filters,
/// and sorting semi-automatically in a Flutter app.
class DataTableController<T> extends ChangeNotifier {
  /// Getter function to retrieve the raw source items.
  final List<T> Function() getSourceItems;

  /// Map of field names to comparable getters for sorting and filtering.
  final Map<String, Comparable Function(T)> fieldGetters;

  /// Default sort configuration (e.g. 'created_desc').
  final String defaultSort;

  final List<DataTableFilter> _filters = [];
  String _sortBy;
  String _searchQuery = '';

  DataTableController({
    required this.getSourceItems,
    required this.fieldGetters,
    this.defaultSort = 'created_desc',
  }) : _sortBy = defaultSort;

  List<DataTableFilter> get filters => _filters;
  String get sortBy => _sortBy;
  String get searchQuery => _searchQuery;

  set searchQuery(String value) {
    if (_searchQuery != value) {
      _searchQuery = value;
      notifyListeners();
    }
  }

  /// Adds a new filter with a default column.
  void addFilter(String defaultColumn) {
    final newId = DateTime.now().microsecondsSinceEpoch.toString();
    _filters.add(
      DataTableFilter(
        id: newId,
        column: defaultColumn,
        operator: 'contains',
        value: '',
      ),
    );
    notifyListeners();
  }

  /// Removes an active filter by its ID.
  void removeFilter(String id) {
    _filters.removeWhere((f) => f.id == id);
    notifyListeners();
  }

  /// Updates an active filter's parameters.
  void updateFilter(
    String id, {
    String? column,
    String? operator,
    String? value,
  }) {
    final index = _filters.indexWhere((f) => f.id == id);
    if (index != -1) {
      _filters[index] = _filters[index].copyWith(
        column: column,
        operator: operator,
        value: value,
      );
      notifyListeners();
    }
  }

  /// Clears all active filters.
  void clearFilters() {
    _filters.clear();
    notifyListeners();
  }

  /// Sets the active sorting string (e.g. 'label_asc').
  void setSort(String sort) {
    if (_sortBy != sort) {
      _sortBy = sort;
      notifyListeners();
    }
  }

  /// Semi-automatically computes the filtered and sorted list of items.
  List<T> get filteredItems {
    final source = getSourceItems();
    if (source.isEmpty) return [];

    List<T> result = List.from(source);

    // 1. Text Search Query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((item) {
        return fieldGetters.values.any((getter) {
          try {
            final val = getter(item).toString().toLowerCase();
            return val.contains(query);
          } catch (_) {
            return false;
          }
        });
      }).toList();
    }

    // 2. Active Column Filters
    for (final f in _filters) {
      if (f.value.isEmpty) continue;
      final target = f.value.toLowerCase();
      final getter = fieldGetters[f.column];
      if (getter == null) continue;

      result = result.where((item) {
        try {
          final val = getter(item).toString().toLowerCase();
          switch (f.operator) {
            case 'equals':
              return val == target;
            case 'contains':
              return val.contains(target);
            case 'starts_with':
              return val.startsWith(target);
            case 'ends_with':
              return val.endsWith(target);
            default:
              return true;
          }
        } catch (_) {
          return false;
        }
      }).toList();
    }

    // 3. Column Sorting
    if (_sortBy.isNotEmpty) {
      final parts = _sortBy.split('_');
      if (parts.length >= 2) {
        // Handle sorting columns like 'my_field_name_asc'
        final col = parts.sublist(0, parts.length - 1).join('_');
        final dir = parts.last;
        final getter = fieldGetters[col];

        if (getter != null) {
          result.sort((a, b) {
            final valA = getter(a);
            final valB = getter(b);

            int comp;
            if (valA is String && valB is String) {
              comp = valA.toLowerCase().compareTo(valB.toLowerCase());
            } else {
              comp = valA.compareTo(valB);
            }

            return dir == 'asc' ? comp : -comp;
          });
        }
      }
    }

    return result;
  }
}
