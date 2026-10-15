import 'package:flutter_test/flutter_test.dart';
import 'package:campusease/main.dart';

void main() {
  testWidgets('Campus Ease app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const CampusEaseApp());

    expect(find.text('CAMPUS EASE'), findsOneWidget);
  });
}
