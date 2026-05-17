import 'package:mobx/mobx.dart';
import '../../../core/models/link.dart';
import '../repository/shares_repository.dart';

part 'shares_store.g.dart';

// ignore: library_private_types_in_public_api
class SharesStore = _SharesStore with _$SharesStore;

abstract class _SharesStore with Store {
  final SharesRepository _repository;

  _SharesStore(this._repository);

  @observable
  ObservableList<Link> shares = ObservableList<Link>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @computed
  int get shareCount => shares.length;

  @action
  Future<void> loadShares() async {
    isLoading = true;
    errorMessage = null;
    try {
      final result = await _repository.getAll();
      shares = ObservableList.of(result);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> createShare({
    required String slug,
    required String label,
    required String user,
    required String workspace,
    required List<String> sections,
    required List<String> records,
    String status = 'active',
  }) async {
    isLoading = true;
    errorMessage = null;
    try {
      final link = await _repository.create(
        slug: slug,
        label: label,
        user: user,
        workspace: workspace,
        sections: sections,
        records: records,
        status: status,
      );
      shares.insert(0, link);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<bool> updateShare(String id, Map<String, dynamic> updates) async {
    try {
      final updated = await _repository.update(id, updates);
      final idx = shares.indexWhere((s) => s.id == id);
      if (idx != -1) {
        shares[idx] = updated;
      }
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    }
  }

  @action
  Future<bool> deleteShare(String id) async {
    try {
      await _repository.delete(id);
      shares.removeWhere((s) => s.id == id);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    }
  }

  Future<bool> isSlugTaken(String slug) => _repository.isSlugTaken(slug);

  Future<String> generateAlternativeSlug(String baseSlug) => _repository.generateAlternativeSlug(baseSlug);

  @action
  void clearError() {
    errorMessage = null;
  }
}
