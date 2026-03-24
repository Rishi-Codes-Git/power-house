import 'package:flutter_test/flutter_test.dart';
import 'package:power_house/main.dart';

void main() {
  testWidgets('App loads login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PowerHouseApp());

    // Verify that the login screen is displayed
    expect(find.text('Power House'), findsOneWidget);
    expect(find.text('Customer Login'), findsOneWidget);
  });
}
