import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/document.dart';

class DatabaseService {
  static Database? _db;

  static Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'docvault.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            note TEXT,
            category INTEGER NOT NULL,
            encryptedFilePath TEXT NOT NULL,
            fileExtension TEXT NOT NULL,
            fileSizeBytes INTEGER NOT NULL,
            issueDate INTEGER,
            expiryDate INTEGER,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            isStarred INTEGER NOT NULL DEFAULT 0,
            tags TEXT NOT NULL DEFAULT ''
          )
        ''');
      },
    );
  }

  static Database get _database {
    if (_db == null) throw Exception('Database not initialized');
    return _db!;
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<int> addDocument(Document doc) async {
    return await _database.insert('documents', doc.toMap());
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<List<Document>> getAllDocuments() async {
    final maps = await _database.query(
      'documents',
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => Document.fromMap(m)).toList();
  }

  Future<Document?> getDocumentById(int id) async {
    final maps = await _database.query(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Document.fromMap(maps.first);
  }

  Future<List<Document>> getByCategory(DocumentCategory category) async {
    final maps = await _database.query(
      'documents',
      where: 'category = ?',
      whereArgs: [category.dbValue],
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => Document.fromMap(m)).toList();
  }

  Future<List<Document>> getStarred() async {
    final maps = await _database.query(
      'documents',
      where: 'isStarred = 1',
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => Document.fromMap(m)).toList();
  }

  Future<List<Document>> getExpiringSoon({int withinDays = 30}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final threshold =
        DateTime.now().add(Duration(days: withinDays)).millisecondsSinceEpoch;
    final maps = await _database.query(
      'documents',
      where: 'expiryDate BETWEEN ? AND ?',
      whereArgs: [now, threshold],
      orderBy: 'expiryDate ASC',
    );
    return maps.map((m) => Document.fromMap(m)).toList();
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<List<Document>> search(String query) async {
    if (query.trim().isEmpty) return getAllDocuments();
    final q = '%${query.trim().toLowerCase()}%';
    final maps = await _database.rawQuery(
      '''SELECT * FROM documents
         WHERE LOWER(name) LIKE ?
         OR LOWER(note) LIKE ?
         OR LOWER(tags) LIKE ?
         ORDER BY createdAt DESC''',
      [q, q, q],
    );
    return maps.map((m) => Document.fromMap(m)).toList();
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<void> updateDocument(Document doc) async {
    final updated = doc.copyWith(updatedAt: DateTime.now());
    await _database.update(
      'documents',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [doc.id],
    );
  }

  Future<void> toggleStar(int id) async {
    final doc = await getDocumentById(id);
    if (doc == null) return;
    await _database.update(
      'documents',
      {
        'isStarred': doc.isStarred ? 0 : 1,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteDocument(int id) async {
    await _database.delete(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAllDocuments() async {
    await _database.delete('documents');
  }
}
