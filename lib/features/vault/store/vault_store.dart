import 'package:mobx/mobx.dart';
import '../../../core/models/record.dart' as models;
import '../../../core/models/section.dart';
import '../../../core/models/template.dart';
import '../repository/records_repository.dart';

part 'vault_store.g.dart';

// ignore: library_private_types_in_public_api
class VaultStore = _VaultStore with _$VaultStore;

abstract class _VaultStore with Store {
  final VaultRepository _repository;

  _VaultStore(this._repository);

  @observable
  ObservableList<models.Record> records = ObservableList<models.Record>();

  @observable
  ObservableList<Section> sections = ObservableList<Section>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @computed
  int get recordCount => records.length;

  @computed
  List<models.Record> get visibleRecords =>
      records.where((r) => !r.isHidden).toList();

  @computed
  List<models.Record> get hiddenRecords =>
      records.where((r) => r.isHidden).toList();

  @action
  Future<void> loadRecords() async {
    isLoading = true;
    errorMessage = null;
    try {
      final recordsResult = await _repository.getAll();
      records = ObservableList.of(recordsResult);
      final sectionsResult = await _repository.getSections();
      sections = ObservableList.of(sectionsResult);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> createRecord({
    required String key,
    required String value,
    required String label,
    required String type,
    required String format,
    required String user,
    required String workspace,
  }) async {
    isLoading = true;
    errorMessage = null;
    try {
      final record = await _repository.create(
        key: key,
        value: value,
        label: label,
        type: type,
        format: format,
        user: user,
        workspace: workspace,
      );
      records.insert(0, record);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> deleteRecord(String id) async {
    try {
      await _repository.delete(id);
      records.removeWhere((r) => r.id == id);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    }
  }

  @action
  Future<bool> updateRecord(String id, Map<String, dynamic> updates) async {
    isLoading = true;
    errorMessage = null;
    try {
      final updated = await _repository.update(id, updates);
      final index = records.indexWhere((r) => r.id == id);
      if (index != -1) {
        records[index] = updated;
      }
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> createSection({
    required String key,
    required String name,
    required List<String> recordIds,
    required String user,
    required String workspace,
  }) async {
    isLoading = true;
    errorMessage = null;
    try {
      final section = await _repository.createSection(
        key: key,
        name: name,
        records: recordIds,
        user: user,
        workspace: workspace,
      );
      sections.insert(0, section);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> updateSection(String id, Map<String, dynamic> updates) async {
    try {
      final section = await _repository.updateSection(id, updates);
      final index = sections.indexWhere((s) => s.id == id);
      if (index != -1) {
        sections[index] = section;
      }
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    }
  }

  @action
  Future<bool> deleteSection(String id) async {
    try {
      await _repository.deleteSection(id);
      sections.removeWhere((s) => s.id == id);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    }
  }

  @action
  Future<bool> createFromTemplate({
    required Template template,
    required String user,
    required String workspace,
  }) async {
    isLoading = true;
    errorMessage = null;
    try {
      final sectionsList = template.schema['sections'] as List<dynamic>? ?? [];
      final rootRecords = template.schema['records'] as List<dynamic>? ?? [];

      // Helper to generate a unique key in the current store state
      String makeUniqueKey(String baseKey, bool isSection) {
        String key = baseKey.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9_-]'),
          '_',
        );
        if (key.isEmpty) {
          key = isSection ? 'section' : 'key';
        }

        final exists = isSection
            ? sections.any((s) => s.key == key)
            : records.any((r) => r.key == key);
        if (!exists) {
          return key;
        }

        int counter = 1;
        while (true) {
          final candidate = '${key}_$counter';
          final existsAlt = isSection
              ? sections.any((s) => s.key == candidate)
              : records.any((r) => r.key == candidate);
          if (!existsAlt) {
            return candidate;
          }
          counter++;
        }
      }

      // 1. Create root records
      for (final recMap in rootRecords) {
        if (recMap is! Map) continue;
        final baseKey = (recMap['key'] as String? ?? '').trim();
        final label = (recMap['label'] as String? ?? 'Record').trim();
        final value = (recMap['value'] as String? ?? '').trim();
        final type = (recMap['type'] as String? ?? 'text').trim();
        final format = (recMap['format'] as String? ?? 'default').trim();

        final uniqueKey = makeUniqueKey(baseKey, false);
        final createdRecord = await _repository.create(
          key: uniqueKey,
          value: value,
          label: label,
          type: type,
          format: format,
          user: user,
          workspace: workspace,
        );
        records.insert(0, createdRecord);
      }

      // 2. Create sections and their records
      for (final secMap in sectionsList) {
        if (secMap is! Map) continue;
        final baseSecKey = (secMap['key'] as String? ?? '').trim();
        final name = (secMap['name'] as String? ?? 'Section').trim();
        final childRecords = secMap['records'] as List<dynamic>? ?? [];

        final createdChildIds = <String>[];
        final uniqueSecKey = makeUniqueKey(baseSecKey, true);

        // Create child records
        for (final recMap in childRecords) {
          if (recMap is! Map) continue;
          final baseKey = (recMap['key'] as String? ?? '').trim();
          final label = (recMap['label'] as String? ?? 'Record').trim();
          final value = (recMap['value'] as String? ?? '').trim();
          final type = (recMap['type'] as String? ?? 'text').trim();
          final format = (recMap['format'] as String? ?? 'default').trim();

          final uniqueKey = makeUniqueKey(baseKey, false);
          final createdRecord = await _repository.create(
            key: uniqueKey,
            value: value,
            label: label,
            type: type,
            format: format,
            user: user,
            workspace: workspace,
          );
          records.insert(0, createdRecord);
          createdChildIds.add(createdRecord.id);
        }

        // Create parent section
        final createdSection = await _repository.createSection(
          key: uniqueSecKey,
          name: name,
          records: createdChildIds,
          user: user,
          workspace: workspace,
        );
        sections.insert(0, createdSection);
      }

      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  void clearError() {
    errorMessage = null;
  }
}
