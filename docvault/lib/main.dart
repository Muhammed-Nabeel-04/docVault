import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:docvault/services/database_service.dart';
import 'package:docvault/services/encryption_service.dart';
import 'package:docvault/services/notification_service.dart';
import 'package:docvault/theme/app_theme.dart';
import 'package:docvault/utils/app_router.dart';
import 'package:docvault/services/auth_service.dart';
import 'package:docvault/providers/providers.dart';

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
    
    // Wait for the next frame to ensure Navigator is ready
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final hasPin = await AuthService.hasPin();
      if (hasPin && mounted) {
        final unlocked = ref.read(isUnlockedProvider);
        if (!unlocked) {
          AppRouter.navigatorKey.currentState?.pushNamed(AppRouter.lock);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
