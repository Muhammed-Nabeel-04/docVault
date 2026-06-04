import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_core/core.dart';
import 'package:docvault/services/database_service.dart';
import 'package:docvault/services/encryption_service.dart';
import 'package:docvault/services/notification_service.dart';
import 'package:docvault/theme/app_theme.dart';
import 'package:docvault/utils/app_router.dart';
import 'package:docvault/services/auth_service.dart';
import 'package:docvault/providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // pdfViewer--licence
  const String syncfusionKey = String.fromEnvironment('SYNCFUSION_LICENSE_KEY');
  if (syncfusionKey.isNotEmpty) {
    SyncfusionLicense.registerLicense(syncfusionKey);
  } else {
    debugPrint('Warning: Syncfusion license key is missing. Set it via --dart-define=SYNCFUSION_LICENSE_KEY=your_key');
  }

  try {
    await DatabaseService.init();
    await EncryptionService.init();
    await NotificationService.init();
  } catch (e) {
    debugPrint('Initialization failed: $e');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Initialization failed: $e\n\nPlease try clearing app data if this persists.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    ));
    return;
  }

  runApp(const ProviderScope(child: DocVaultApp()));
}

class DocVaultApp extends StatelessWidget {
  const DocVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocVault',
      navigatorKey: AppRouter.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: AppRouter.home,
      onGenerateRoute: AppRouter.generateRoute,
      builder: (context, child) => _AppLockWrapper(child: child!),
    );
  }
}

class _AppLockWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const _AppLockWrapper({required this.child});

  @override
  ConsumerState<_AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends ConsumerState<_AppLockWrapper>
    with WidgetsBindingObserver {
  bool _checked = false;
  DateTime? _backgroundAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLock();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.requestPermissions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _checkAutoLock();
    }
  }

  Future<void> _checkAutoLock() async {
    if (_backgroundAt == null) return;

    final hasPin = await AuthService.hasPin();
    if (!hasPin) return;

    final duration = await AuthService.getAutoLockDuration();
    final elapsed = DateTime.now().difference(_backgroundAt!).inSeconds;

    // Add a 5-second grace period even for "Immediately" to allow system pickers
    final threshold = duration == 0 ? 5 : duration;

    if (elapsed >= threshold) {
      ref.read(isUnlockedProvider.notifier).state = false;
      AppRouter.navigatorKey.currentState?.pushNamed(AppRouter.lock);
    }
    _backgroundAt = null;
  }

  Future<void> _checkLock() async {
    if (_checked) return;
    _checked = true;

    final hasPin = await AuthService.hasPin();
    if (hasPin) {
      // Proactively set to locked
      ref.read(isUnlockedProvider.notifier).state = false;

      // Wait for the next frame to ensure Navigator is ready
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        // Small delay as fallback for real devices
        await Future.delayed(const Duration(milliseconds: 100));
        AppRouter.navigatorKey.currentState?.pushNamed(AppRouter.lock);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
