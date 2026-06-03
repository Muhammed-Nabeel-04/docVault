import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document.dart';
import '../services/database_service.dart';
import '../services/encryption_service.dart';

// ── Database service ──────────────────────────────────────────────────────────

final dbProvider = Provider<DatabaseService>((ref) => DatabaseService());

// ── App lock ──────────────────────────────────────────────────────────────────

final isUnlockedProvider = StateProvider<bool>((ref) => false);

// ── Search query ──────────────────────────────────────────────────────────────

final searchQueryProvider = StateProvider<String>((ref) => '');

// ── Selected category filter ──────────────────────────────────────────────────

final selectedCategoryProvider =
    StateProvider<DocumentCategory?>((ref) => null);

// ── Documents list (reloads when notified) ────────────────────────────────────

final documentsProvider =
    StateNotifierProvider<DocumentsNotifier, AsyncValue<List<Document>>>(
  (ref) => DocumentsNotifier(ref.watch(dbProvider)),
);

class DocumentsNotifier
    extends StateNotifier<AsyncValue<List<Document>>> {
  final DatabaseService _db;

  DocumentsNotifier(this._db) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final docs = await _db.getAllDocuments();
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

  Future<void> filterByCategory(DocumentCategory? category) async {
    try {
      final docs = category == null
          ? await _db.getAllDocuments()
          : await _db.getByCategory(category);
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
      await EncryptionService.deleteEncryptedFile(doc.encryptedFilePath);
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
