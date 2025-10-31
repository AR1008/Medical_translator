import 'package:flutter_test/flutter_test.dart';
import 'package:medical_translator_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Medical Translation System'), findsOneWidget);
  });
}
