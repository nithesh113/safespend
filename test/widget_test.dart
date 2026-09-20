import 'package:flutter_test/flutter_test.dart';
import 'package:safespend/core/security/app_lock_gate.dart';
import 'package:safespend/main.dart';
import 'package:safespend/features/dashboard/screens/dashboard_screen.dart';

void main() {
  testWidgets('App starts and shows SafeSpend', (WidgetTester tester) async {
    await tester.pumpWidget(const SafeSpendApp());
    await tester.pump();

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(AppLockGate), findsOneWidget);
  });
}
