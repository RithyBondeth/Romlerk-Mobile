import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// [testWidgets] for screens backed by a Drift database.
///
/// Drift closes a cancelled query stream on a zero-length timer. When the
/// test ends, the framework unmounts the tree (cancelling those streams) and
/// then fails the test for the timer it just caused. Unmounting inside the
/// test body and pumping once lets the timer fire in time.

void testDriftWidgets(String description, WidgetTesterCallback body) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
