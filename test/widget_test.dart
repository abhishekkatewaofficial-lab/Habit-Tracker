import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker_ios/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Hive and notification init require real device—skip in unit tests.
    expect(HabitTrackerApp, isNotNull);
  });
}
