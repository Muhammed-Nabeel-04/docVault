# DocVault — Master Build Prompt
# Paste this entire prompt into Claude Code CLI to build the app from scratch.

---

You are an expert Flutter developer. Build a complete, production-ready Flutter Android app called **DocVault** from scratch. Follow every instruction exactly. Do not skip any file.

---

## WHAT THE APP DOES

DocVault is an **offline personal document vault**. Users can:
- Add documents (PDF, JPG, PNG) by picking from storage or taking a photo
- Give each document a name (e.g. "Aadhaar Card", "Driving Licence")
- Assign a category: Identity, Vehicle, Medical, Education, Finance, Property, Other
- Add optional notes, tags, issue date, expiry date
- Search documents instantly by name, tags, or notes
- View documents in-app (PDF viewer + image viewer)
- Share documents to other apps
- Star important documents
- Get notified before documents expire (30 days before)
- Lock the app with PIN or biometrics
- All files are AES-256 encrypted on-device. No internet. No account. No cloud.

---

## TECH STACK

- **Framework**: Flutter (latest stable)
- **Language**: Dart
- **Database**: isar ^4.0.0 (local, offline, fast search)
- **State management**: flutter_riverpod ^2.5.1
- **Encryption**: encrypt ^5.0.3 + flutter_secure_storage ^9.2.2
- **File picking**: file_picker ^8.0.3 + image_picker ^1.1.2
- **PDF viewer**: syncfusion_flutter_pdfviewer ^25.1.35
- **Sharing**: share_plus ^9.0.0
- **Biometrics/PIN**: local_auth ^2.3.0
- **Notifications**: flutter_local_notifications ^17.2.2 + timezone ^0.9.4
- **Animations**: flutter_animate ^4.5.0
- **Utilities**: uuid ^4.4.0 + intl ^0.19.0 + permission_handler ^11.3.1

---

## STEP 1 — CREATE FLUTTER PROJECT

Run:
```
flutter create docvault --org com.nabeel --platforms android
cd docvault
```

---

## STEP 2 — pubspec.yaml

Replace the entire contents of `pubspec.yaml` with:

```yaml
name: docvault
description: Offline personal document vault — secure, private, no cloud.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  isar: ^4.0.0
  isar_flutter_libs: ^4.0.0
  path_provider: ^2.1.2
  file_picker: ^8.0.3
  image_picker: ^1.1.2
  syncfusion_flutter_pdfviewer: ^25.1.35
  share_plus: ^9.0.0
  encrypt: ^5.0.3
  flutter_secure_storage: ^9.2.2
  local_auth: ^2.3.0
  flutter_local_notifications: ^17.2.2
  timezone: ^0.9.4
  flutter_animate: ^4.5.0
  flutter_riverpod: ^2.5.1
  uuid: ^4.4.0
  intl: ^0.19.0
  permission_handler: ^11.3.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  isar_generator: ^4.0.0
  build_runner: ^2.4.9

flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/icons/
```

Create asset folders:
```
mkdir -p assets/images assets/icons
```

---

## STEP 3 — ANDROID SETUP

### android/app/build.gradle
Make sure these are set:
- `minSdkVersion 21`
- `compileSdkVersion 34`
- `targetSdkVersion 34`

### android/app/src/main/AndroidManifest.xml
Replace with:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
    <uses-permission android:name="android.permission.USE_FINGERPRINT"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>

    <application
        android:label="DocVault"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="false">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data android:name="io.flutter.embedding.android.NormalTheme" android:resource="@style/NormalTheme"/>
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" android:exported="false"/>
        <receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver" android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
            </intent-filter>
        </receiver>
        <meta-data android:name="flutterEmbedding" android:value="2"/>
    </application>
</manifest>
```

---

## STEP 4 — FOLDER STRUCTURE

Create this exact folder structure inside `lib/`:

```
lib/
├── main.dart
├── models/
│   └── document.dart
├── services/
│   ├── database_service.dart
│   ├── encryption_service.dart
│   ├── auth_service.dart
│   └── notification_service.dart
├── providers/
│   └── providers.dart
├── screens/
│   ├── home/
│   │   └── home_screen.dart
│   ├── add_document/
│   │   └── add_document_screen.dart
│   ├── view_document/
│   │   └── view_document_screen.dart
│   ├── search/
│   │   └── search_screen.dart
│   ├── settings/
│   │   └── settings_screen.dart
│   └── lock/
│       └── lock_screen.dart
├── widgets/
│   ├── document_card.dart
│   ├── category_filter_bar.dart
│   └── empty_state.dart
├── theme/
│   └── app_theme.dart
└── utils/
    ├── app_router.dart
    └── app_utils.dart
```

---

## STEP 5 — WRITE ALL FILES

### lib/models/document.dart
```dart
import 'package:isar/isar.dart';
part 'document.g.dart';

enum DocumentCategory {
  identity, vehicle, medical, education, finance, property, other
}

extension DocumentCategoryExtension on DocumentCategory {
  String get label {
    switch (this) {
      case DocumentCategory.identity:  return 'Identity';
      case DocumentCategory.vehicle:   return 'Vehicle';
      case DocumentCategory.medical:   return 'Medical';
      case DocumentCategory.education: return 'Education';
      case DocumentCategory.finance:   return 'Finance';
      case DocumentCategory.property:  return 'Property';
      case DocumentCategory.other:     return 'Other';
    }
  }
  String get icon {
    switch (this) {
      case DocumentCategory.identity:  return '🪪';
      case DocumentCategory.vehicle:   return '🚗';
      case DocumentCategory.medical:   return '🏥';
      case DocumentCategory.education: return '🎓';
      case DocumentCategory.finance:   return '💳';
      case DocumentCategory.property:  return '🏠';
      case DocumentCategory.other:     return '📄';
    }
  }
}

@collection
class Document {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String name;

  String? note;

  @enumerated
  late DocumentCategory category;

  late String encryptedFilePath;
  late String fileExtension;
  late int fileSizeBytes;

  DateTime? issueDate;
  DateTime? expiryDate;

  late DateTime createdAt;
  late DateTime updatedAt;

  bool isStarred = false;
  late List<String> tags;
}
```

---

### lib/services/database_service.dart
```dart
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/document.dart';

class DatabaseService {
  static late Isar _isar;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open([DocumentSchema], directory: dir.path);
  }

  Future<Id> addDocument(Document doc) async {
    return await _isar.writeTxn(() async => await _isar.documents.put(doc));
  }

  Future<List<Document>> getAllDocuments() async {
    return await _isar.documents.where().sortByCreatedAtDesc().findAll();
  }

  Future<List<Document>> getByCategory(DocumentCategory category) async {
    return await _isar.documents.filter().categoryEqualTo(category).sortByCreatedAtDesc().findAll();
  }

  Future<List<Document>> getStarred() async {
    return await _isar.documents.filter().isStarredEqualTo(true).findAll();
  }

  Future<List<Document>> getExpiringSoon({int withinDays = 30}) async {
    final now = DateTime.now();
    final threshold = now.add(Duration(days: withinDays));
    return await _isar.documents.filter().expiryDateBetween(now, threshold).findAll();
  }

  Future<List<Document>> search(String query) async {
    if (query.trim().isEmpty) return getAllDocuments();
    final q = query.trim().toLowerCase();
    return await _isar.documents
        .filter()
        .nameContains(q, caseSensitive: false)
        .or()
        .noteContains(q, caseSensitive: false)
        .or()
        .tagsElementContains(q, caseSensitive: false)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Future<void> updateDocument(Document doc) async {
    doc.updatedAt = DateTime.now();
    await _isar.writeTxn(() async => await _isar.documents.put(doc));
  }

  Future<void> toggleStar(Id id) async {
    await _isar.writeTxn(() async {
      final doc = await _isar.documents.get(id);
      if (doc != null) {
        doc.isStarred = !doc.isStarred;
        doc.updatedAt = DateTime.now();
        await _isar.documents.put(doc);
      }
    });
  }

  Future<void> deleteDocument(Id id) async {
    await _isar.writeTxn(() async => await _isar.documents.delete(id));
  }

  Stream<List<Document>> watchAllDocuments() {
    return _isar.documents.where().sortByCreatedAtDesc().watch(fireImmediately: true);
  }

  Stream<List<Document>> watchSearch(String query) {
    if (query.trim().isEmpty) return watchAllDocuments();
    final q = query.trim().toLowerCase();
    return _isar.documents
        .filter()
        .nameContains(q, caseSensitive: false)
        .or()
        .tagsElementContains(q, caseSensitive: false)
        .watch(fireImmediately: true);
  }
}
```

---

### lib/services/encryption_service.dart
```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class EncryptionService {
  static const _keyAlias = 'docvault_aes_key';
  static const _ivAlias  = 'docvault_aes_iv';
  static const _storage  = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static late enc.Key _key;
  static late enc.IV  _iv;

  static Future<void> init() async {
    String? keyB64 = await _storage.read(key: _keyAlias);
    String? ivB64  = await _storage.read(key: _ivAlias);
    if (keyB64 == null || ivB64 == null) {
      final k = enc.Key.fromSecureRandom(32);
      final v = enc.IV.fromSecureRandom(16);
      await _storage.write(key: _keyAlias, value: k.base64);
      await _storage.write(key: _ivAlias,  value: v.base64);
      keyB64 = k.base64; ivB64 = v.base64;
    }
    _key = enc.Key.fromBase64(keyB64);
    _iv  = enc.IV.fromBase64(ivB64);
  }

  static Future<String> encryptFile(File source) async {
    final bytes     = await source.readAsBytes();
    final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(bytes, iv: _iv);
    final dir       = await getApplicationDocumentsDirectory();
    final encDir    = Directory('${dir.path}/enc');
    if (!await encDir.exists()) await encDir.create(recursive: true);
    final file = File('${encDir.path}/${const Uuid().v4()}.enc');
    await file.writeAsBytes(encrypted.bytes);
    return file.path;
  }

  static Future<Uint8List> decryptFile(String path) async {
    final bytes     = await File(path).readAsBytes();
    final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decryptBytes(enc.Encrypted(bytes), iv: _iv);
    return Uint8List.fromList(decrypted);
  }

  static Future<File> decryptToTemp(String path, String ext) async {
    final bytes   = await decryptFile(path);
    final tempDir = await getTemporaryDirectory();
    final file    = File('${tempDir.path}/${const Uuid().v4()}.$ext');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> deleteEncryptedFile(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
```

---

### lib/services/auth_service.dart
```dart
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AuthService {
  static const _pinKey = 'docvault_pin';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static final _auth = LocalAuthentication();

  static Future<bool> hasPin() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  static Future<void> setPin(String pin) async =>
      await _storage.write(key: _pinKey, value: pin);

  static Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinKey);
    return stored == pin;
  }

  static Future<void> removePin() async =>
      await _storage.delete(key: _pinKey);

  static Future<bool> isBiometricsAvailable() async {
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } on PlatformException { return false; }
  }

  static Future<bool> authenticateWithBiometrics() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to open DocVault',
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } on PlatformException { return false; }
  }
}
```

---

### lib/services/notification_service.dart
```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/document.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    const android  = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
  }

  static Future<void> scheduleExpiryReminder(Document doc) async {
    if (doc.expiryDate == null) return;
    final notifyAt = doc.expiryDate!.subtract(const Duration(days: 30));
    if (notifyAt.isBefore(DateTime.now())) return;
    await _plugin.zonedSchedule(
      doc.id,
      'Document expiring soon',
      '${doc.name} expires on ${doc.expiryDate!.day}/${doc.expiryDate!.month}/${doc.expiryDate!.year}',
      tz.TZDateTime.from(notifyAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'expiry_channel', 'Document Expiry Reminders',
          channelDescription: 'Alerts when documents are about to expire',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelReminder(int docId) async =>
      await _plugin.cancel(docId);
}
```

---

### lib/providers/providers.dart
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document.dart';
import '../services/database_service.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) => DatabaseService());

final allDocumentsProvider = StreamProvider<List<Document>>((ref) {
  return ref.watch(databaseServiceProvider).watchAllDocuments();
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final selectedCategoryProvider = StateProvider<DocumentCategory?>((ref) => null);

final filteredDocumentsProvider = StreamProvider<List<Document>>((ref) async* {
  final db       = ref.watch(databaseServiceProvider);
  final query    = ref.watch(searchQueryProvider);
  final category = ref.watch(selectedCategoryProvider);
  if (query.isEmpty && category == null) {
    yield* db.watchAllDocuments();
  } else if (query.isNotEmpty) {
    yield* db.watchSearch(query);
  } else {
    yield await db.getByCategory(category!);
  }
});

final starredDocumentsProvider = FutureProvider<List<Document>>((ref) {
  ref.watch(allDocumentsProvider);
  return ref.watch(databaseServiceProvider).getStarred();
});

final expiringSoonProvider = FutureProvider<List<Document>>((ref) {
  ref.watch(allDocumentsProvider);
  return ref.watch(databaseServiceProvider).getExpiringSoon(withinDays: 30);
});

final isUnlockedProvider = StateProvider<bool>((ref) => false);
```

---

### lib/theme/app_theme.dart
```dart
import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFF5B4CF5);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: _seed);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF6F5FB),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF6F5FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(color: scheme.onSurface, fontSize: 20, fontWeight: FontWeight.w600),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _seed, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _seed,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0F0E17),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0F0E17),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(color: scheme.onSurface, fontSize: 20, fontWeight: FontWeight.w600),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1C1B29),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2C2B3A)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1C1B29),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2C2B3A))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2C2B3A))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _seed, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _seed,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
```

---

### lib/utils/app_utils.dart
```dart
import 'package:intl/intl.dart';

class AppUtils {
  static String formatDate(DateTime? date) {
    if (date == null) return '—';
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30)  return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0)   return '${diff.inDays}d ago';
    if (diff.inHours > 0)  return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  static bool isExpiringSoon(DateTime? d, {int withinDays = 30}) {
    if (d == null) return false;
    final diff = d.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= withinDays;
  }

  static bool isExpired(DateTime? d) =>
      d != null && d.isBefore(DateTime.now());

  static String daysUntilExpiry(DateTime d) {
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0)  return 'Expired';
    if (days == 0) return 'Expires today';
    if (days == 1) return 'Expires tomorrow';
    return 'Expires in $days days';
  }
}
```

---

### lib/utils/app_router.dart
```dart
import 'package:flutter/material.dart';
import '../models/document.dart';
import '../screens/home/home_screen.dart';
import '../screens/add_document/add_document_screen.dart';
import '../screens/view_document/view_document_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/lock/lock_screen.dart';

class AppRouter {
  static const home        = '/';
  static const addDocument = '/add-document';
  static const viewDocument = '/view-document';
  static const search      = '/search';
  static const settings    = '/settings';
  static const lock        = '/lock';

  static Route<dynamic> generateRoute(RouteSettings s) {
    switch (s.name) {
      case home:         return MaterialPageRoute(builder: (_) => const HomeScreen());
      case addDocument:  return MaterialPageRoute(builder: (_) => AddDocumentScreen(existingDocument: s.arguments as Document?));
      case viewDocument: return MaterialPageRoute(builder: (_) => ViewDocumentScreen(document: s.arguments as Document));
      case search:       return MaterialPageRoute(builder: (_) => const SearchScreen());
      case settings:     return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case lock:         return MaterialPageRoute(builder: (_) => const LockScreen());
      default:           return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('Not found'))));
    }
  }
}
```

---

### lib/main.dart
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/database_service.dart';
import 'services/encryption_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'utils/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.init();
  await EncryptionService.init();
  await NotificationService.init();
  runApp(const ProviderScope(child: DocVaultApp()));
}

class DocVaultApp extends StatelessWidget {
  const DocVaultApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocVault',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: AppRouter.home,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
```

---

### lib/widgets/empty_state.dart
```dart
import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.folder_open_rounded,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: scheme.primaryContainer.withOpacity(0.5), shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: scheme.primary),
            ),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}
```

---

### lib/widgets/category_filter_bar.dart
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document.dart';
import '../providers/providers.dart';

class CategoryFilterBar extends ConsumerWidget {
  const CategoryFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoryProvider);
    final scheme   = Theme.of(context).colorScheme;
    final categories = [null, ...DocumentCategory.values];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final isSelected = selected == cat;
          return FilterChip(
            selected: isSelected,
            label: Row(mainAxisSize: MainAxisSize.min, children: [
              if (cat != null) ...[Text(cat.icon, style: const TextStyle(fontSize: 13)), const SizedBox(width: 4)],
              Text(cat == null ? 'All' : cat.label, style: const TextStyle(fontSize: 13)),
            ]),
            onSelected: (_) => ref.read(selectedCategoryProvider.notifier).state = cat,
            selectedColor: scheme.primaryContainer,
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
      ),
    );
  }
}
```

---

### lib/widgets/document_card.dart
```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/document.dart';
import '../utils/app_utils.dart';
import '../utils/app_router.dart';

class DocumentCard extends StatelessWidget {
  final Document document;
  final VoidCallback? onStar;
  final VoidCallback? onDelete;
  final int index;

  const DocumentCard({super.key, required this.document, this.onStar, this.onDelete, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final scheme      = Theme.of(context).colorScheme;
    final expired     = AppUtils.isExpired(document.expiryDate);
    final expiringSoon = !expired && AppUtils.isExpiringSoon(document.expiryDate);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRouter.viewDocument, arguments: document),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(document.category.icon, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(document.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (expired) _badge('Expired', Colors.red.shade100, Colors.red.shade700)
                else if (expiringSoon) _badge(AppUtils.daysUntilExpiry(document.expiryDate!), Colors.orange.shade100, Colors.orange.shade700),
              ]),
              const SizedBox(height: 4),
              Text('${document.category.label}  ·  ${AppUtils.formatFileSize(document.fileSizeBytes)}  ·  ${AppUtils.timeAgo(document.createdAt)}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              if (document.note != null && document.note!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(document.note!, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ])),
            IconButton(
              icon: Icon(document.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                color: document.isStarred ? Colors.amber : scheme.onSurfaceVariant, size: 22),
              onPressed: onStar,
            ),
          ]),
        ),
      ),
    ).animate(delay: Duration(milliseconds: index * 40)).fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0, duration: 200.ms);
  }

  Widget _badge(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
  );
}
```

---

### lib/screens/home/home_screen.dart
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../services/database_service.dart';
import '../../utils/app_router.dart';
import '../../widgets/document_card.dart';
import '../../widgets/category_filter_bar.dart';
import '../../widgets/empty_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync   = ref.watch(filteredDocumentsProvider);
    final expiring    = ref.watch(expiringSoonProvider);

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          floating: true, snap: true,
          title: const Text('DocVault'),
          actions: [
            IconButton(icon: const Icon(Icons.search_rounded), onPressed: () => Navigator.pushNamed(context, AppRouter.search)),
            IconButton(icon: const Icon(Icons.settings_rounded), onPressed: () => Navigator.pushNamed(context, AppRouter.settings)),
          ],
        ),
        expiring.when(
          data: (docs) => docs.isEmpty ? const SliverToBoxAdapter(child: SizedBox.shrink())
            : SliverToBoxAdapter(child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('${docs.length} document${docs.length > 1 ? 's' : ''} expiring within 30 days',
                  style: TextStyle(fontSize: 13, color: Colors.orange.shade800, fontWeight: FontWeight.w500))),
              ]),
            )),
          loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),
        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(vertical: 10), child: CategoryFilterBar())),
        docsAsync.when(
          data: (docs) => docs.isEmpty
            ? SliverFillRemaining(child: EmptyState(title: 'No documents yet', subtitle: 'Tap + to add your first document', icon: Icons.description_rounded))
            : SliverList(delegate: SliverChildBuilderDelegate(
                (ctx, i) => DocumentCard(
                  document: docs[i], index: i,
                  onStar: () => ref.read(databaseServiceProvider).toggleStar(docs[i].id),
                  onDelete: () => _confirmDelete(context, ref, docs[i].id),
                ),
                childCount: docs.length,
              )),
          loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
          error: (e, _) => SliverFillRemaining(child: Center(child: Text('Error: $e'))),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRouter.addDocument),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add document'),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int docId) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete document?'),
      content: const Text('This permanently deletes the document from your device.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () { Navigator.pop(ctx); ref.read(databaseServiceProvider).deleteDocument(docId); },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ));
  }
}
```

---

### lib/screens/add_document/add_document_screen.dart
Build a full-screen form with:
- A file picker area (tap to pick PDF/image from storage OR take photo with camera)
- TextFormField for document name (required, validated)
- Category selector grid (all 7 categories shown as tappable chips with emoji + label)
- Optional note text field
- Optional tags field (comma separated)
- Two date pickers side by side: Issue date and Expiry date
- A "Save document" FilledButton at the bottom with loading indicator
- On save: encrypt the file with EncryptionService, save metadata to Isar via DatabaseService, schedule expiry notification if expiry date set
- Support editing existing documents (passed as route argument)
- Use ConsumerStatefulWidget + Riverpod

---

### lib/screens/view_document/view_document_screen.dart
Build a screen that:
- Receives a Document object via route argument
- Decrypts the file to a temp location using EncryptionService.decryptToTemp
- Shows document metadata (category icon, name, note, issue/expiry dates) in a card at top
- Shows PDF using SfPdfViewer.file() for .pdf files
- Shows image using InteractiveViewer + Image.file() for image files
- Has AppBar with edit button (navigate to add_document with doc as argument) and share button (Share.shareXFiles)
- Deletes temp file on dispose

---

### lib/screens/search/search_screen.dart
Build a screen that:
- Has an autofocus TextField in the AppBar
- Uses searchQueryProvider to store query string
- Watches filteredDocumentsProvider to show results
- Shows EmptyState when query is empty ("Search your documents")
- Shows EmptyState when no results found
- Shows list of DocumentCard when results exist
- Has clear button in TextField when query is not empty
- Uses ConsumerStatefulWidget

---

### lib/screens/settings/settings_screen.dart
Build a settings screen with:
- Security section: PIN lock toggle (SwitchListTile), biometrics tile
- Storage section: "All files encrypted" status tile, "Clear all documents" danger tile
- About section: app name/version, privacy policy link
- PIN setup dialog (4-digit, obscured TextField)
- Uses ConsumerStatefulWidget

---

### lib/screens/lock/lock_screen.dart
Build a lock screen with:
- App icon + "DocVault" title + subtitle
- 4 PIN dot indicators (filled/unfilled)
- Numeric keypad (0-9 + backspace) built from rows
- PIN verification via AuthService.verifyPin
- Biometrics button shown if available
- On success: set isUnlockedProvider to true and navigate to home
- Error message on wrong PIN
- Uses ConsumerStatefulWidget

---

## STEP 6 — GENERATE ISAR FILES

After writing all files, run:
```
dart run build_runner build --delete-conflicting-outputs
```

This generates `lib/models/document.g.dart` which Isar requires.

---

## STEP 7 — RUN THE APP

```
flutter run
```

---

## IMPORTANT NOTES FOR THE CLI

1. **Do not use `cunning_document_scanner`** — it has compatibility issues. Skip document scanning, use camera via image_picker instead.
2. **isar must be version 4.x** — version 3.x is incompatible with modern Android Gradle Plugin.
3. **CardTheme must be CardThemeData** in Flutter 3.x+.
4. **Run `flutter pub get` before `build_runner`**.
5. **All screens that use Riverpod must extend ConsumerWidget or ConsumerStatefulWidget**, not StatelessWidget or StatefulWidget.
6. **document.g.dart is auto-generated** — never write it manually, always use build_runner.
7. The app is **fully offline** — no Firebase, no Supabase, no internet required at all.
8. Encrypt every file before saving, decrypt to temp only for viewing/sharing, delete temp file after use.
