import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  static const _items = [
    (
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      route: '/dashboard',
    ),
    (
      label: 'Reports',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart_rounded,
      route: '/activity',
    ),
    (
      label: 'Goals',
      icon: Icons.savings_outlined,
      selectedIcon: Icons.savings_rounded,
      route: '/savings',
    ),
    (
      label: 'Bills',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      route: '/bills',
    ),
  ];

  int _selectedIndex(String location) {
    final index = _items.indexWhere((item) => location.startsWith(item.route));
    return index < 0 ? 0 : index;
  }

  void _openAddMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What would you like to add?',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              _actionTile(
                sheetContext,
                Icons.shopping_bag_outlined,
                'Expense',
                'Record something you spent',
                '/expenses',
              ),
              _actionTile(
                sheetContext,
                Icons.trending_up_rounded,
                'Income',
                'Update your monthly income',
                '/settings',
              ),
              _actionTile(
                sheetContext,
                Icons.receipt_long_outlined,
                'Recurring bill',
                'Add rent, WiFi, phone, or another bill',
                '/bills',
              ),
              _actionTile(
                sheetContext,
                Icons.savings_outlined,
                'Savings goal',
                'Create a goal for something important',
                '/savings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    String route,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(icon),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex(GoRouterState.of(context).uri.path);
    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddMenu(context),
        tooltip: 'Add',
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 78,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(16),
                blurRadius: 18,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              _navItem(context, _items[0], selectedIndex == 0),
              _navItem(context, _items[1], selectedIndex == 1),
              const SizedBox(width: 72),
              _navItem(context, _items[2], selectedIndex == 2),
              _navItem(context, _items[3], selectedIndex == 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    ({String label, IconData icon, IconData selectedIcon, String route}) item,
    bool selected,
  ) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: Semantics(
        button: true,
        label: item.label,
        selected: selected,
        child: InkWell(
          onTap: () => context.go(item.route),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? item.selectedIcon : item.icon, color: color),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
