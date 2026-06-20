import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:playoncon/app.dart';

void main() {
  testWidgets('App renders bottom navigation', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PlayOnConApp()));
    await tester.pump();

    expect(find.text('Schedule'), findsWidgets);
    expect(find.text('Map'), findsWidgets);
    expect(find.text('Info'), findsWidgets);
  });
}
