import 'package:mobx/mobx.dart';
import '../../../core/models/template.dart';
import '../repository/templates_repository.dart';

class TemplatesStore {
  final TemplatesRepository _repository;

  TemplatesStore(this._repository) {
    templates = ObservableList<Template>();
  }

  late final ObservableList<Template> templates;

  final _isLoading = Observable(false);
  bool get isLoading => _isLoading.value;
  set isLoading(bool val) => Action(() { _isLoading.value = val; })();

  final _errorMessage = Observable<String?>(null);
  String? get errorMessage => _errorMessage.value;
  set errorMessage(String? val) => Action(() { _errorMessage.value = val; })();

  final _expandedTemplates = ObservableSet<String>();
  bool isTemplateExpanded(String id) => _expandedTemplates.contains(id);
  void toggleTemplateExpanded(String id) {
    Action(() {
      if (_expandedTemplates.contains(id)) {
        _expandedTemplates.remove(id);
      } else {
        _expandedTemplates.add(id);
      }
    })();
  }

  Future<void> loadTemplates(String workspaceId) async {
    isLoading = true;
    errorMessage = null;
    try {
      final result = await _repository.getAll(workspaceId: workspaceId);
      Action(() {
        templates.clear();
        templates.addAll(result);
      })();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }

  Future<bool> createTemplate({
    required String name,
    required Map<String, dynamic> schema,
    required String workspaceId,
  }) async {
    isLoading = true;
    errorMessage = null;
    try {
      final t = await _repository.create(
        name: name,
        schema: schema,
        workspaceId: workspaceId,
      );
      Action(() {
        templates.insert(0, t);
      })();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
    }
  }

  Future<bool> updateTemplate(
    String id, {
    required String name,
    required Map<String, dynamic> schema,
  }) async {
    isLoading = true;
    errorMessage = null;
    try {
      final updated = await _repository.update(id, name: name, schema: schema);
      Action(() {
        final idx = templates.indexWhere((t) => t.id == id);
        if (idx != -1) {
          templates[idx] = updated;
        }
      })();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
    }
  }

  Future<bool> deleteTemplate(String id) async {
    isLoading = true;
    errorMessage = null;
    try {
      await _repository.delete(id);
      Action(() {
        templates.removeWhere((t) => t.id == id);
      })();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
    }
  }

  void clearError() {
    Action(() {
      errorMessage = null;
    })();
  }
}
