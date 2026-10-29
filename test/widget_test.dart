import 'package:flutter_test/flutter_test.dart';

import 'package:catnest/app.dart';

void main() {
  testWidgets('CatNestApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const CatNestApp());
    expect(find.byType(CatNestApp), findsOneWidget);
  });
}
