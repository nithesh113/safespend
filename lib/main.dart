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

void main() {
  FlutterError.onError = (FlutterErrorDetails details) => FlutterError.presentError(details);
  runZonedGuarded<Future<void>>(() async => runApp(const SafeSpendApp()),
      (Object error, StackTrace stack) => debugPrint('UNHANDLED ASYNC ERROR: $error\n$stack'));
}

class SafeSpendApp extends StatelessWidget {
  const SafeSpendApp({super.key});
  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (_) => const SizedBox.shrink();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => SavingsProvider()),
      ],
      child: MaterialApp.router(
        title: 'SafeSpend', debugShowCheckedModeBanner: false,
        theme: _buildTheme(), routerConfig: _router,
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: const Color(0xFF2E7D32),
      scaffoldBackgroundColor: const Color(0xFFF8FAF9),
      appBarTheme: const AppBarTheme(scrolledUnderElevation: 1, backgroundColor: Color(0xFFF8FAF9)),
      cardTheme: CardThemeData(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6), color: Colors.white),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    );
  }
}

final _router = GoRouter(
  initialLocation: '/dashboard',
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Page not found', style: Theme.of(context).textTheme.bodyLarge)),
  ),
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        final hideNav = state.uri.path == '/settings';
        return Scaffold(
          body: child,
          bottomNavigationBar: hideNav ? null : _BottomNavBar(currentLocation: state.uri.path),
        );
      },
      routes: [
        GoRoute(path: '/dashboard', pageBuilder: (c, s) => const NoTransitionPage(child: DashboardScreen())),
        GoRoute(path: '/expenses', pageBuilder: (c, s) => const NoTransitionPage(child: ExpenseScreen())),
        GoRoute(path: '/savings', pageBuilder: (c, s) => const NoTransitionPage(child: SavingsScreen())),
        GoRoute(path: '/settings', pageBuilder: (c, s) => const NoTransitionPage(child: SettingsScreen())),
      ],
    ),
  ],
);

class _BottomNavBar extends StatelessWidget {
  final String currentLocation;
  const _BottomNavBar({required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentLocation == '/dashboard' ? 0 : currentLocation == '/expenses' ? 1 : 2,
      onDestinationSelected: (i) => context.go(['/dashboard', '/expenses', '/savings'][i]),
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      indicatorColor: Theme.of(context).colorScheme.primaryContainer,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Add'),
        NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings), label: 'Save'),
      ],
    );
  }
}