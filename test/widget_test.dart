import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mojiren/main.dart';

void main() {
  test('app widget can be created', () {
    const app = KakijunLabApp();

    expect(app, isA<Widget>());
  });
}
