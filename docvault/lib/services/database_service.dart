import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/document.dart';
import '../models/category.dart';

class DatabaseService {
  static Database? _db;

  static Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'docvault.db');

    try {
      _db = await _openAndMigrate(path);
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      // If database is corrupted (SQLITE_NOTADB), delete and start fresh
      if (errorStr.contains('code 26') || 
          errorStr.contains('notadb') || 
          errorStr.contains('file is not a database') ||
          errorStr.contains('malformed')) {
        try {
          // Close existing connection if any
          await _db?.close();
          _db = null;
          
          await deleteDatabase(path);
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
          // Small delay to ensure file system is ready
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (_) {}
        
        // Final attempt to open/recreate
        _db = await _openAndMigrate(path);
      } else {
        rethrow;
      }
    }
  }

  static Future<Database> _openAndMigrate(String path) async {
    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await _createTables(db);
        await _insertDefaultCategories(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS categories (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              icon TEXT NOT NULL
            )
          ''');
          await _insertDefaultCategories(db);
          await db.execute('UPDATE documents SET category = category + 1');
        }
        if (oldVersion < 3) {
          // 1. Create document_files table
          await db.execute('''
            CREATE TABLE IF NOT EXISTS document_files (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              document_id INTEGER NOT NULL,
              encryptedFilePath TEXT NOT NULL,
              fileExtension TEXT NOT NULL,
              fileSizeBytes INTEGER NOT NULL,
              FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
            )
          ''');

          // 2. Migrate existing single files to document_files
          final existingDocs = await db.query('documents');
          for (var doc in existingDocs) {
            final docId = doc['id'];
            final path = doc['encryptedFilePath'];
            final ext = doc['fileExtension'];
            final size = doc['fileSizeBytes'];

            if (path != null) {
              await db.insert('document_files', {
                'document_id': docId,
                'encryptedFilePath': path,
                'fileExtension': ext,
                'fileSizeBytes': size,
              });
            }
          }

          // 3. Recreate documents table without old columns
          await db.execute('''
            CREATE TABLE documents_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              note TEXT,
              category INTEGER NOT NULL,
              issueDate INTEGER,
              expiryDate INTEGER,
              createdAt INTEGER NOT NULL,
              updatedAt INTEGER NOT NULL,
              isStarred INTEGER NOT NULL DEFAULT 0,
              tags TEXT NOT NULL DEFAULT ''
            )
          ''');

          await db.execute('''
            INSERT INTO documents_new (id, name, note, category, issueDate, expiryDate, createdAt, updatedAt, isStarred, tags)
            SELECT id, name, note, category, issueDate, expiryDate, createdAt, updatedAt, isStarred, tags FROM documents
          ''');

          await db.execute('DROP TABLE documents');
          await db.execute('ALTER TABLE documents_new RENAME TO documents');
        }
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        note TEXT,
        category INTEGER NOT NULL,
        issueDate INTEGER,
        expiryDate INTEGER,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        isStarred INTEGER NOT NULL DEFAULT 0,
        tags TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS document_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        encryptedFilePath TEXT NOT NULL,
        fileExtension TEXT NOT NULL,
        fileSizeBytes INTEGER NOT NULL,
        FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _insertDefaultCategories(Database db) async {
    final defaults = [
      {'name': 'Identity', 'icon': '🪪'},
      {'name': 'Vehicle', 'icon': '🚗'},
      {'name': 'Medical', 'icon': '🏥'},
      {'name': 'Education', 'icon': '🎓'},
      {'name': 'Finance', 'icon': '💳'},
      {'name': 'Property', 'icon': '🏠'},
      {'name': 'Other', 'icon': '📄'},
    ];

    for (var cat in defaults) {
      await db.insert('categories', cat);
    }
  }

  static Database get _database {
    if (_db == null) throw Exception('Database not initialized');
    return _db!;
  }

  // ── Categories ────────────────────────────────────────────────────────────

  Future<List<Category>> getAllCategories() async {
    final maps = await _database.query('categories', orderBy: 'id ASC');
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  Future<int> addCategory(Category category) async {
    return await _database.insert('categories', category.toMap());
  }

  Future<void> updateCategory(Category category) async {
    await _database.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> deleteCategory(int id) async {
    final categories = await getAllCategories();
    if (categories.length <= 1) return;

    final others = await _database.query(
      'categories',
      where: 'name = ?',
      whereArgs: ['Other'],
      limit: 1,
    );
    
    int? otherId;
    if (others.isNotEmpty) {
      otherId = others.first['id'] as int;
    }

    if (otherId == null || otherId == id) {
      otherId = categories.firstWhere((c) => c.id != id).id;
    }

    if (otherId != null) {
      await _database.update(
        'documents',
        {'category': otherId},
        where: 'category = ?',
        whereArgs: [id],
      );
    }

    await _database.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<int> addDocument(Document doc) async {
    return await _database.transaction((txn) async {
      final docId = await txn.insert('documents', doc.toMap());
      for (var file in doc.files) {
        await txn.insert('document_files', file.copyWith(documentId: docId).toMap());
      }
      return docId;
    });
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<List<Document>> getAllDocuments() async {
    final maps = await _database.query('documents', orderBy: 'createdAt DESC');
    List<Document> docs = [];
    for (var m in maps) {
      final files = await _getFilesForDocument(m['id'] as int);
      docs.add(Document.fromMap(m, files: files));
    }
    return docs;
  }

  Future<Document?> getDocumentById(int id) async {
    final maps = await _database.query('documents', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    final files = await _getFilesForDocument(id);
    return Document.fromMap(maps.first, files: files);
  }

  Future<List<DocumentFile>> _getFilesForDocument(int docId) async {
    final maps = await _database.query('document_files', where: 'document_id = ?', whereArgs: [docId]);
    return maps.map((m) => DocumentFile.fromMap(m)).toList();
  }

  Future<List<Document>> getByCategory(int categoryId) async {
    final maps = await _database.query('documents', where: 'category = ?', whereArgs: [categoryId], orderBy: 'createdAt DESC');
    List<Document> docs = [];
    for (var m in maps) {
      final files = await _getFilesForDocument(m['id'] as int);
      docs.add(Document.fromMap(m, files: files));
    }
    return docs;
  }

  Future<List<Document>> getStarred() async {
    final maps = await _database.query('documents', where: 'isStarred = 1', orderBy: 'createdAt DESC');
    List<Document> docs = [];
    for (var m in maps) {
      final files = await _getFilesForDocument(m['id'] as int);
      docs.add(Document.fromMap(m, files: files));
    }
    return docs;
  }

  Future<List<Document>> getExpiringSoon({int withinDays = 30}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final threshold = DateTime.now().add(Duration(days: withinDays)).millisecondsSinceEpoch;
    final maps = await _database.query('documents', where: 'expiryDate BETWEEN ? AND ?', whereArgs: [now, threshold], orderBy: 'expiryDate ASC');
    List<Document> docs = [];
    for (var m in maps) {
      final files = await _getFilesForDocument(m['id'] as int);
      docs.add(Document.fromMap(m, files: files));
    }
    return docs;
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
    List<Document> docs = [];
    for (var m in maps) {
      final files = await _getFilesForDocument(m['id'] as int);
      docs.add(Document.fromMap(m, files: files));
    }
    return docs;
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<void> updateDocument(Document doc) async {
    final updated = doc.copyWith(updatedAt: DateTime.now());
    await _database.transaction((txn) async {
      await txn.update('documents', updated.toMap(), where: 'id = ?', whereArgs: [doc.id]);
      
      // Update files: This is simpler if we just replace the file list for the doc
      // but we should only delete files that are NOT in the new list.
      // However, for an offline-first high security app, simple is often safer.
      // We'll delete all existing files for this doc and re-insert.
      // NOTE: File deletion from disk must be handled by the caller (AddDocumentScreen).
      await txn.delete('document_files', where: 'document_id = ?', whereArgs: [doc.id]);
      for (var file in doc.files) {
        await txn.insert('document_files', file.copyWith(documentId: doc.id).toMap());
      }
    });
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
    await _database.delete('documents', where: 'id = ?', whereArgs: [id]);
    // CASCADE ON DELETE should handle document_files, but we ensure it.
    await _database.delete('document_files', where: 'document_id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllDocuments() async {
    await _database.delete('documents');
    await _database.delete('document_files');
  }
}
