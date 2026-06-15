import 'package:flutter_test/flutter_test.dart';
import 'package:safespend/main.dart';

void main() {
  testWidgets('App starts and shows SafeSpend', (WidgetTester tester) async {
    await tester.pumpWidget(const SafeSpendApp());
    await tester.pumpAndSettle();

    // Verify the bottom navigation bar is present
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Savings'), findsOneWidget);
  });
}