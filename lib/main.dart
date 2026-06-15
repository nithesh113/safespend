import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:safespend/core/theme/app_theme.dart';
import 'package:safespend/features/dashboard/providers/dashboard_provider.dart';
import 'package:safespend/features/dashboard/providers/app_settings_provider.dart';
import 'package:safespend/features/expenses/providers/expense_provider.dart';
import 'package:safespend/features/savings/providers/savings_provider.dart';
import 'package:safespend/features/dashboard/screens/dashboard_screen.dart';
import 'package:safespend/features/expenses/screens/expense_screen.dart';
import 'package:safespend/features/savings/screens/savings_screen.dart';

// --- App Entry Point ---
void main() {
  // Prevent the "red screen of death" on physical devices.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  // Catch unhandled async errors from unawaited futures.
  runZonedGuarded<Future<void>>(() async {
    runApp(const SafeSpendApp());
  }, (Object error, StackTrace stack) {
    debugPrint('UNHANDLED ASYNC ERROR: $error\n$stack');
  });
}

class SafeSpendApp extends StatefulWidget {
  const SafeSpendApp({super.key});

  @override
  State<SafeSpendApp> createState() => _SafeSpendAppState();
}

class _SafeSpendAppState extends State<SafeSpendApp> {
  @override
  Widget build(BuildContext context) {
    // Replace the red error widget with a clean placeholder.
    ErrorWidget.builder = (FlutterErrorDetails details) {
      debugPrint('Widget build error: ${details.exception}');
      return const SizedBox.shrink();
    };

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => SavingsProvider()),
      ],
      child: MaterialApp.router(
        title: 'SafeSpend',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: _router,
      ),
    );
  }
}

// --- Router with Bottom Navigation ---
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  errorBuilder: (context, state) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Could not load this page.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  },
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return Scaffold(
          body: child,
          bottomNavigationBar: _BottomNavBar(currentLocation: state.uri.path),
        );
      },
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DashboardScreen()),
        ),
        GoRoute(
          path: '/expenses',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ExpenseScreen()),
        ),
        GoRoute(
          path: '/savings',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SavingsScreen()),
        ),
      ],
    ),
  ],
);

/// BottomNavigationBar synced with GoRouter.
class _BottomNavBar extends StatelessWidget {
  final String currentLocation;

  const _BottomNavBar({required this.currentLocation});

  int _getSelectedIndex() {
    switch (currentLocation) {
      case '/dashboard':
        return 0;
      case '/expenses':
        return 1;
      case '/savings':
        return 2;
      default:
        return 0;
    }
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
      case 1:
        context.go('/expenses');
      case 2:
        context.go('/savings');
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: _getSelectedIndex(),
      onDestinationSelected: (index) => _onItemTapped(context, index),
      backgroundColor: Theme.of(context).colorScheme.surface,
      indicatorColor: Theme.of(context).colorScheme.primaryContainer,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_circle_outline),
          selectedIcon: Icon(Icons.add_circle),
          label: 'Expense',
        ),
        NavigationDestination(
          icon: Icon(Icons.savings_outlined),
          selectedIcon: Icon(Icons.savings),
          label: 'Savings',
        ),
      ],
    );
  }
}