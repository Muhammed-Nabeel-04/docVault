import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/database_service.dart';
import 'services/encryption_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'utils/app_router.dart';
import 'services/auth_service.dart';
import 'providers/providers.dart';

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

  Future<void> _checkLock() async {
    if (_checked) return;
    _checked = true;
    final hasPin = await AuthService.hasPin();
    if (hasPin && mounted) {
      final unlocked = ref.read(isUnlockedProvider);
      if (!unlocked) {
        Navigator.of(context).pushReplacementNamed(AppRouter.lock);
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
