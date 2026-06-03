import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/encryption_service.dart';

// ── Database service ──────────────────────────────────────────────────────────

final dbProvider = Provider<DatabaseService>((ref) => DatabaseService());

// ── App lock ──────────────────────────────────────────────────────────────────

final isUnlockedProvider = StateProvider<bool>((ref) => true);

// ── Search query ──────────────────────────────────────────────────────────────

final searchQueryProvider = StateProvider<String>((ref) => '');

// ── Categories ────────────────────────────────────────────────────────────────

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, AsyncValue<List<Category>>>(
  (ref) => CategoriesNotifier(ref.watch(dbProvider)),
);

class CategoriesNotifier
    extends StateNotifier<AsyncValue<List<Category>>> {
  final DatabaseService _db;

  CategoriesNotifier(this._db) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final categories = await _db.getAllCategories();
      state = AsyncValue.data(categories);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addCategory(String name, String icon) async {
    await _db.addCategory(Category(name: name, icon: icon));
    await load();
  }

  Future<void> updateCategory(Category category) async {
    await _db.updateCategory(category);
    await load();
  }

  Future<void> deleteCategory(int id) async {
    await _db.deleteCategory(id);
    await load();
  }
}

// ── Selected category filter ──────────────────────────────────────────────────

final selectedCategoryProvider = StateProvider<int?>((ref) => null);

// ── Documents list (reloads when notified) ────────────────────────────────────

final documentsProvider =
    StateNotifierProvider<DocumentsNotifier, AsyncValue<List<Document>>>(
  (ref) {
    final categoryId = ref.watch(selectedCategoryProvider);
    final notifier = DocumentsNotifier(ref.watch(dbProvider), categoryId);
    // Refresh documents when categories change (in case of category deletion/reassignment)
    ref.listen(categoriesProvider, (_, __) => notifier.load());
    return notifier;
  },
);

class DocumentsNotifier
    extends StateNotifier<AsyncValue<List<Document>>> {
  final DatabaseService _db;
  final int? categoryId;

  DocumentsNotifier(this._db, this.categoryId) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final docs = categoryId == null
          ? await _db.getAllDocuments()
          : await _db.getByCategory(categoryId!);
      state = AsyncValue.data(docs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> search(String query) async {
    try {
      final docs = await _db.search(query);
      state = AsyncValue.data(docs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleStar(int id) async {
    await _db.toggleStar(id);
    await load();
  }

  Future<void> deleteDocument(int id) async {
    final doc = await _db.getDocumentById(id);
    if (doc != null) {
      for (var file in doc.files) {
        await EncryptionService.deleteEncryptedFile(file.encryptedFilePath);
      }
      await _db.deleteDocument(id);
      await load();
    }
  }
}

// ── Expiring soon ─────────────────────────────────────────────────────────────

final expiringSoonProvider =
    FutureProvider<List<Document>>((ref) async {
  final db = ref.watch(dbProvider);
  ref.watch(documentsProvider); // refresh when documents change
  return db.getExpiringSoon(withinDays: 30);
});
