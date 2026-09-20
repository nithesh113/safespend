import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:safespend/features/dashboard/providers/dashboard_provider.dart';
import 'package:safespend/features/dashboard/providers/app_settings_provider.dart';
import 'package:safespend/features/expenses/providers/expense_provider.dart';
import 'package:safespend/features/savings/providers/savings_provider.dart';
import 'package:safespend/features/dashboard/screens/dashboard_screen.dart';
import 'package:safespend/features/expenses/screens/expense_screen.dart';
import 'package:safespend/features/savings/screens/savings_screen.dart';
import 'package:safespend/features/settings/screens/settings_screen.dart';
import 'package:safespend/features/bills/screens/bills_screen.dart';
import 'package:safespend/features/transactions/screens/transactions_screen.dart';
import 'package:safespend/features/activity/screens/activity_screen.dart';
import 'package:safespend/core/security/app_lock_gate.dart';
import 'package:safespend/core/security/app_lock_provider.dart';
import 'package:safespend/core/notifications/bill_notification_service.dart';
import 'package:safespend/shared/widgets/app_shell.dart';

void main() {
  FlutterError.onError = (FlutterErrorDetails details) =>
      FlutterError.presentError(details);
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await BillNotificationService.instance.initialize(
        onTap: (payload) => _router.go(payload ?? '/bills'),
      );
      runApp(const SafeSpendApp());
    },
    (Object error, StackTrace stack) =>
        debugPrint('UNHANDLED ASYNC ERROR: $error\n$stack'),
  );
}

class SafeSpendApp extends StatelessWidget {
  const SafeSpendApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => SavingsProvider()),
        ChangeNotifierProvider(create: (_) => AppLockProvider()),
      ],
      child: MaterialApp.router(
        title: 'SafeSpend',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        routerConfig: _router,
        builder: (context, child) =>
            AppLockGate(child: child ?? const SizedBox.shrink()),
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: const Color(0xFF6C3CEB),
      scaffoldBackgroundColor: const Color(0xFFF8F7FC),
      appBarTheme: const AppBarTheme(
        scrolledUnderElevation: 0,
        backgroundColor: Color(0xFFF8F7FC),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
        color: Colors.white,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: const Color(0xFF6C3CEB),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

final _router = GoRouter(
  initialLocation: '/dashboard',
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text(
        'Page not found',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ),
  ),
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (c, s) =>
              const NoTransitionPage(child: DashboardScreen()),
        ),
        GoRoute(
          path: '/activity',
          pageBuilder: (c, s) =>
              const NoTransitionPage(child: ActivityScreen()),
        ),
        GoRoute(
          path: '/savings',
          pageBuilder: (c, s) => const NoTransitionPage(child: SavingsScreen()),
        ),
        GoRoute(
          path: '/bills',
          pageBuilder: (c, s) => const NoTransitionPage(child: BillsScreen()),
        ),
      ],
    ),
    GoRoute(
      path: '/expenses',
      pageBuilder: (c, s) => const NoTransitionPage(child: ExpenseScreen()),
    ),
    GoRoute(
      path: '/transactions',
      pageBuilder: (c, s) =>
          const NoTransitionPage(child: TransactionsScreen()),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (c, s) => const NoTransitionPage(child: SettingsScreen()),
    ),
  ],
);
