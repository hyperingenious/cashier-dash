import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_dash/main.dart';

void main() {
  testWidgets('shows cashier login entry point', (WidgetTester tester) async {
    await tester.pumpWidget(const CashierDashApp());

    expect(find.text('Cashier Access'), findsOneWidget);
    expect(find.text('Enter POS'), findsOneWidget);
  });
}
