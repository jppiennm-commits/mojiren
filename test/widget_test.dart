import 'package:flutter_test/flutter_test.dart';

import 'package:mojiren/main.dart';

void main() {
  testWidgets('shows app name', (WidgetTester tester) async {
    await tester.pumpWidget(const KakijunLabApp());
    await tester.pumpAndSettle();

    expect(find.text('もじれん'), findsOneWidget);
  });
}
