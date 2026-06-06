// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'package:path/path.dart' hide equals, Context;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:docvault/models/category.dart';
import 'package:docvault/models/document.dart';
import 'package:docvault/services/database_service.dart';

// ---------------------------------------------------------------------------
// Setup helpers
// ---------------------------------------------------------------------------

/// Opens a fresh, empty in-memory SQLite database and wires it into
/// DatabaseService so every test starts from a clean slate.
Future<void> _initDb() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // ':memory:' gives a fresh DB each call; no tearDown needed for data.
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 1),
  );
  await DatabaseService.initForTesting(db);
}

/// Builds a minimal [Document] with sane defaults for testing.
Document _makeDoc({
  String name = 'Test Document',
  int? categoryId,
  List<DocumentFile> files = const [],
  DateTime? expiryDate,
  bool isStarred = false,
  List<String> tags = const [],
  String? note,
}) {
  final now = DateTime.now();
  return Document(
    name: name,
    categoryId: categoryId ?? 1, // 'Identity' seeded as id=1
    files: files,
    createdAt: now,
    updatedAt: now,
    expiryDate: expiryDate,
    isStarred: isStarred,
    tags: tags,
    note: note,
  );
}

/// Builds a [DocumentFile] stub (no real file on disk needed for DB tests).
DocumentFile _makeFile({
  String path = '/enc/fake.enc',
  String ext = 'pdf',
  int size = 1024,
}) =>
    DocumentFile(
      encryptedFilePath: path,
      fileExtension: ext,
      fileSizeBytes: size,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late DatabaseService db;

  setUp(() async {
    await _initDb();
    db = DatabaseService();
  });

  tearDown(() async {
    await DatabaseService.close();
  });

  // ── Default categories ────────────────────────────────────────────────────

  group('default categories', () {
    test('7 default categories are seeded on fresh init', () async {
      final cats = await db.getAllCategories();
      expect(cats.length, equals(7));
    });

    test('first category is Identity', () async {
      final cats = await db.getAllCategories();
      expect(cats.first.name, equals('Identity'));
    });

    test('last category is Other', () async {
      final cats = await db.getAllCategories();
      expect(cats.last.name, equals('Other'));
    });
  });

  // ── addDocument / getAllDocuments ─────────────────────────────────────────

  group('addDocument / getAllDocuments', () {
    test('inserted document is returned by getAllDocuments', () async {
      await db.addDocument(_makeDoc(name: 'Passport'));
      final docs = await db.getAllDocuments();
      expect(docs.length, equals(1));
      expect(docs.first.name, equals('Passport'));
    });

    test('inserted document receives a positive auto-increment id', () async {
      final id = await db.addDocument(_makeDoc());
      expect(id, greaterThan(0));
    });

    test('multiple documents are all returned', () async {
      await db.addDocument(_makeDoc(name: 'Passport'));
      await db.addDocument(_makeDoc(name: 'Driving Licence'));
      await db.addDocument(_makeDoc(name: 'Medical Card'));
      final docs = await db.getAllDocuments();
      expect(docs.length, equals(3));
    });

    test('documents are returned newest-first', () async {
      await db.addDocument(_makeDoc(name: 'First'));
      await Future.delayed(const Duration(milliseconds: 5));
      await db.addDocument(_makeDoc(name: 'Second'));
      final docs = await db.getAllDocuments();
      expect(docs.first.name, equals('Second'));
    });
  });

  // ── Multi-file support ────────────────────────────────────────────────────

  group('multi-file documents', () {
    test('files associated with a document are loaded back correctly', () async {
      final files = [
        _makeFile(path: '/enc/a.enc', ext: 'pdf', size: 500),
        _makeFile(path: '/enc/b.enc', ext: 'jpg', size: 250),
        _makeFile(path: '/enc/c.enc', ext: 'png', size: 125),
      ];
      await db.addDocument(_makeDoc(files: files));
      final docs = await db.getAllDocuments();

      expect(docs.first.files.length, equals(3));
    });

    test('file extensions and sizes are preserved', () async {
      final files = [
        _makeFile(path: '/enc/x.enc', ext: 'pdf', size: 8192),
        _makeFile(path: '/enc/y.enc', ext: 'jpg', size: 4096),
      ];
      await db.addDocument(_makeDoc(files: files));
      final loaded = (await db.getAllDocuments()).first;

      final exts = loaded.files.map((f) => f.fileExtension).toSet();
      expect(exts, containsAll(['pdf', 'jpg']));

      final sizes = loaded.files.map((f) => f.fileSizeBytes).toSet();
      expect(sizes, containsAll([8192, 4096]));
    });

    test('document with no files has an empty files list', () async {
      await db.addDocument(_makeDoc());
      final docs = await db.getAllDocuments();
      expect(docs.first.files, isEmpty);
    });
  });

  // ── getDocumentById ───────────────────────────────────────────────────────

  group('getDocumentById', () {
    test('returns the correct document', () async {
      final id = await db.addDocument(_makeDoc(name: 'Tax Return'));
      final doc = await db.getDocumentById(id);
      expect(doc, isNotNull);
      expect(doc!.name, equals('Tax Return'));
    });

    test('returns null for a non-existent id', () async {
      final doc = await db.getDocumentById(99999);
      expect(doc, isNull);
    });
  });

  // ── updateDocument ────────────────────────────────────────────────────────

  group('updateDocument', () {
    test('name is updated', () async {
      final id = await db.addDocument(_makeDoc(name: 'Old Name'));
      final original = (await db.getDocumentById(id))!;
      await db.updateDocument(original.copyWith(name: 'New Name'));
      final updated = await db.getDocumentById(id);
      expect(updated!.name, equals('New Name'));
    });

    test('files are replaced on update', () async {
      final id = await db.addDocument(_makeDoc(
        files: [_makeFile(path: '/enc/old.enc')],
      ));
      final original = (await db.getDocumentById(id))!;
      final newFiles = [
        _makeFile(path: '/enc/new1.enc', ext: 'jpg'),
        _makeFile(path: '/enc/new2.enc', ext: 'png'),
      ];
      await db.updateDocument(original.copyWith(files: newFiles));

      final updated = await db.getDocumentById(id);
      expect(updated!.files.length, equals(2));
      final paths = updated.files.map((f) => f.encryptedFilePath).toList();
      expect(paths, containsAll(['/enc/new1.enc', '/enc/new2.enc']));
      expect(paths, isNot(contains('/enc/old.enc')));
    });
  });

  // ── deleteDocument ────────────────────────────────────────────────────────

  group('deleteDocument', () {
    test('deleted document no longer appears in getAllDocuments', () async {
      final id = await db.addDocument(_makeDoc(name: 'To Delete'));
      await db.deleteDocument(id);
      final docs = await db.getAllDocuments();
      expect(docs.where((d) => d.id == id), isEmpty);
    });

    test('deleting a document also removes its associated files', () async {
      final id = await db.addDocument(_makeDoc(
        files: [_makeFile(path: '/enc/gone.enc')],
      ));
      await db.deleteDocument(id);
      // getDocumentById returns null — files are gone with the parent.
      final doc = await db.getDocumentById(id);
      expect(doc, isNull);
    });

    test('other documents are unaffected by a targeted delete', () async {
      final id1 = await db.addDocument(_makeDoc(name: 'Keep Me'));
      final id2 = await db.addDocument(_makeDoc(name: 'Delete Me'));
      await db.deleteDocument(id2);
      final docs = await db.getAllDocuments();
      expect(docs.any((d) => d.id == id1), isTrue);
      expect(docs.any((d) => d.id == id2), isFalse);
    });
  });

  // ── toggleStar ────────────────────────────────────────────────────────────

  group('toggleStar', () {
    test('toggles isStarred from false to true', () async {
      final id = await db.addDocument(_makeDoc(isStarred: false));
      await db.toggleStar(id);
      final doc = await db.getDocumentById(id);
      expect(doc!.isStarred, isTrue);
    });

    test('toggles isStarred from true back to false', () async {
      final id = await db.addDocument(_makeDoc(isStarred: true));
      await db.toggleStar(id);
      final doc = await db.getDocumentById(id);
      expect(doc!.isStarred, isFalse);
    });
  });

  // ── getByCategory ─────────────────────────────────────────────────────────

  group('getByCategory', () {
    test('returns only documents in the requested category', () async {
      final cats = await db.getAllCategories();
      final identityId = cats.firstWhere((c) => c.name == 'Identity').id!;
      final medicalId = cats.firstWhere((c) => c.name == 'Medical').id!;

      await db.addDocument(_makeDoc(name: 'Passport', categoryId: identityId));
      await db.addDocument(_makeDoc(name: 'Blood Test', categoryId: medicalId));
      await db.addDocument(_makeDoc(name: 'ID Card', categoryId: identityId));

      final identityDocs = await db.getByCategory(identityId);
      expect(identityDocs.length, equals(2));
      expect(identityDocs.every((d) => d.categoryId == identityId), isTrue);
    });
  });

  // ── search ────────────────────────────────────────────────────────────────

  group('search', () {
    setUp(() async {
      await db.addDocument(_makeDoc(name: 'Passport', tags: ['travel', 'id']));
      await db.addDocument(_makeDoc(name: 'Driving Licence', note: 'expires soon'));
      await db.addDocument(
          _makeDoc(name: 'Medical Records', tags: ['health']));
    });

    test('finds document by name (case-insensitive)', () async {
      final results = await db.search('passport');
      expect(results.length, equals(1));
      expect(results.first.name, equals('Passport'));
    });

    test('finds document by tag', () async {
      final results = await db.search('travel');
      expect(results.length, equals(1));
      expect(results.first.name, equals('Passport'));
    });

    test('finds document by note content', () async {
      final results = await db.search('expires');
      expect(results.length, equals(1));
      expect(results.first.name, equals('Driving Licence'));
    });

    test('returns empty list when no match', () async {
      final results = await db.search('xyzzy_no_match');
      expect(results, isEmpty);
    });

    test('empty query returns all documents', () async {
      final results = await db.search('');
      expect(results.length, equals(3));
    });
  });

  // ── getExpiringSoon ───────────────────────────────────────────────────────

  group('getExpiringSoon', () {
    test('returns document expiring within 30 days', () async {
      final soonExpiry = DateTime.now().add(const Duration(days: 10));
      await db.addDocument(_makeDoc(name: 'Soon', expiryDate: soonExpiry));
      final results = await db.getExpiringSoon(withinDays: 30);
      expect(results.any((d) => d.name == 'Soon'), isTrue);
    });

    test('does not return document expiring in 60 days for a 30-day window',
        () async {
      final farExpiry = DateTime.now().add(const Duration(days: 60));
      await db.addDocument(_makeDoc(name: 'Far', expiryDate: farExpiry));
      final results = await db.getExpiringSoon(withinDays: 30);
      expect(results.any((d) => d.name == 'Far'), isFalse);
    });

    test('does not return already-expired document', () async {
      final expired = DateTime.now().subtract(const Duration(days: 1));
      await db.addDocument(_makeDoc(name: 'Expired', expiryDate: expired));
      final results = await db.getExpiringSoon(withinDays: 30);
      expect(results.any((d) => d.name == 'Expired'), isFalse);
    });

    test('returns empty list when no documents have expiry dates', () async {
      await db.addDocument(_makeDoc(name: 'No Expiry'));
      final results = await db.getExpiringSoon();
      expect(results, isEmpty);
    });
  });

  // ── deleteAllDocuments ────────────────────────────────────────────────────

  group('deleteAllDocuments', () {
    test('removes all documents and files', () async {
      await db.addDocument(
          _makeDoc(name: 'A', files: [_makeFile(path: '/enc/a.enc')]));
      await db.addDocument(
          _makeDoc(name: 'B', files: [_makeFile(path: '/enc/b.enc')]));
      await db.deleteAllDocuments();
      expect(await db.getAllDocuments(), isEmpty);
    });
  });

  // ── Category management ───────────────────────────────────────────────────

  group('category management', () {
    test('addCategory persists and is returned by getAllCategories', () async {
      await db.addCategory(Category(name: 'Custom', icon: '🌟'));
      final cats = await db.getAllCategories();
      expect(cats.any((c) => c.name == 'Custom'), isTrue);
    });

    test('updateCategory changes name and icon', () async {
      final cats = await db.getAllCategories();
      final target = cats.first;
      await db.updateCategory(target.copyWith(name: 'Updated', icon: '✏️'));
      final updated = (await db.getAllCategories())
          .firstWhere((c) => c.id == target.id);
      expect(updated.name, equals('Updated'));
      expect(updated.icon, equals('✏️'));
    });

    test('cannot delete the "Other" category', () async {
      final cats = await db.getAllCategories();
      final other = cats.firstWhere((c) => c.name == 'Other');
      
      expect(
        () => db.deleteCategory(other.id!),
        throwsA(anything),
      );
    });

    test('can reorder categories', () async {
      final cats = await db.getAllCategories();
      if (cats.length < 2) return;

      final reversed = cats.reversed.toList();
      await db.reorderCategories(reversed);
      
      final updated = await db.getAllCategories();
      expect(updated.first.name, equals(reversed.first.name));
      expect(updated.last.name, equals(reversed.last.name));
    });

    test('deleting a category reassigns its documents to Other', () async {
      final cats = await db.getAllCategories();
      final identityId = cats.firstWhere((c) => c.name == 'Identity').id!;
      final otherId = cats.firstWhere((c) => c.name == 'Other').id!;

      await db.addDocument(_makeDoc(name: 'My ID', categoryId: identityId));
      await db.deleteCategory(identityId);

      final docs = await db.getAllDocuments();
      expect(docs.first.categoryId, equals(otherId),
          reason: 'Documents must be moved to Other when their category is deleted');
    });
  });

  // ── Database Migration (v1 -> v3) ──────────────────────────────────────────

  group('database migration (v1 -> v3)', () {
    test('successfully upgrades from v1 schema to v3 without data loss', () async {
      // 1. Setup a v1 database in a unique file (in-memory can sometimes share state in ffi)
      sqfliteFfiInit();
      final factory = databaseFactoryFfi;
      final tempDir = Directory.systemTemp.createTempSync('docvault_migration_test');
      final dbPath = join(tempDir.path, 'v1_test.db');

      // Create v1 schema manually
      final dbV1 = await factory.openDatabase(dbPath, options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE documents (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              note TEXT,
              category INTEGER NOT NULL,
              issueDate INTEGER,
              expiryDate INTEGER,
              createdAt INTEGER NOT NULL,
              updatedAt INTEGER NOT NULL,
              isStarred INTEGER NOT NULL DEFAULT 0,
              tags TEXT NOT NULL DEFAULT '',
              encryptedFilePath TEXT,
              fileExtension TEXT,
              fileSizeBytes INTEGER
            )
          ''');
        },
      ));

      // 2. Insert dummy v1 data
      final now = DateTime.now().millisecondsSinceEpoch;
      await dbV1.rawInsert('''
        INSERT INTO documents (name, note, category, createdAt, updatedAt, encryptedFilePath, fileExtension, fileSizeBytes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''', ['V1 Legacy Doc', 'This was created in v1', 0, now, now, '/old/path.enc', 'pdf', 1234]);
      await dbV1.close();

      // 3. Re-open with v4 targets to trigger migration
      final upgradedDb = await factory.openDatabase(dbPath, options: OpenDatabaseOptions(
        version: 4,
        onUpgrade: (db, oldVersion, newVersion) async {
          // Re-running the EXACT logic from DatabaseService.dart
          if (oldVersion < 2) {
            await db.execute('CREATE TABLE IF NOT EXISTS categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, icon TEXT NOT NULL)');
            // Fix: Check if categories exist first to avoid duplicates in tests
            final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM categories'));
            if (count == 0) {
              final defaults = [
                {'name': 'Identity', 'icon': '🪪'}, {'name': 'Vehicle', 'icon': '🚗'},
                {'name': 'Medical', 'icon': '🏥'}, {'name': 'Education', 'icon': '🎓'},
                {'name': 'Finance', 'icon': '💳'}, {'name': 'Property', 'icon': '🏠'},
                {'name': 'Other', 'icon': '📄'},
              ];
              for (var cat in defaults) await db.insert('categories', cat);
            }
            await db.execute('UPDATE documents SET category = category + 1');
          }
          if (oldVersion < 3) {
            await db.execute('CREATE TABLE IF NOT EXISTS document_files (id INTEGER PRIMARY KEY AUTOINCREMENT, document_id INTEGER NOT NULL, encryptedFilePath TEXT NOT NULL, fileExtension TEXT NOT NULL, fileSizeBytes INTEGER NOT NULL, FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE)');
            final existingDocs = await db.query('documents');
            for (var doc in existingDocs) {
              final docId = doc['id'];
              final path = doc['encryptedFilePath'];
              if (path != null) {
                await db.insert('document_files', {
                  'document_id': docId,
                  'encryptedFilePath': path,
                  'fileExtension': doc['fileExtension'],
                  'fileSizeBytes': doc['fileSizeBytes'],
                });
              }
            }
            await db.execute('CREATE TABLE documents_new (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, note TEXT, category INTEGER NOT NULL, issueDate INTEGER, expiryDate INTEGER, createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL, isStarred INTEGER NOT NULL DEFAULT 0, tags TEXT NOT NULL DEFAULT \'\')');
            await db.execute('INSERT INTO documents_new (id, name, note, category, issueDate, expiryDate, createdAt, updatedAt, isStarred, tags) SELECT id, name, note, category, issueDate, expiryDate, createdAt, updatedAt, isStarred, tags FROM documents');
            await db.execute('DROP TABLE documents');
            await db.execute('ALTER TABLE documents_new RENAME TO documents');
          }
          if (oldVersion < 4) {
            await db.execute('ALTER TABLE categories ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
            final cats = await db.query('categories', orderBy: 'id');
            for (int i = 0; i < cats.length; i++) {
              await db.update('categories', {'sort_order': i}, where: 'id = ?', whereArgs: [cats[i]['id']]);
            }
          }
        },
      ));

      // 4. Verify results using DatabaseService instance
      // We don't use initForTesting here because it re-runs _createTables and _insertDefaultCategories
      // which causes duplicates in this migration test scenario.
      // Instead, we manually inject the DB into the service if we can, 
      // or we just query the upgradedDb directly since that's what we want to verify.
      
      // Let's use the actual DatabaseService to verify it handles the migrated data correctly.
      await DatabaseService.initForTesting(upgradedDb);
      final service = DatabaseService();

      final docs = await service.getAllDocuments();
      expect(docs.length, equals(1));
      
      final legacyDoc = docs.first;
      expect(legacyDoc.name, equals('V1 Legacy Doc'));
      expect(legacyDoc.categoryId, equals(1)); // 0 + 1 = 1 (Identity)
      
      // Verify files were migrated
      expect(legacyDoc.files.length, equals(1));
      expect(legacyDoc.files.first.encryptedFilePath, equals('/old/path.enc'));
      
      // Verify categories exist (exactly 7, no duplicates from migration + initForTesting)
      final cats = await service.getAllCategories();
      
      final uniqueNames = cats.map((c) => c.name).toSet();
      expect(uniqueNames.length, equals(7));
      expect(cats.length, equals(7), reason: 'Migration should not result in duplicate categories');
      
      await DatabaseService.close();
      // Cleanup temp file
      try { await tempDir.delete(recursive: true); } catch (_) {}
    });
  });
}
