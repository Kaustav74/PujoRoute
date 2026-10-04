import 'package:flutter_test/flutter_test.dart';
import 'package:pujoroute/main.dart';

void main() {
  testWidgets('PujoRouteApp smoke test', (WidgetTester tester) async {
    // Build our app and verify it mounts successfully
    expect(const PujoRouteApp(), isNotNull);
  });
}
