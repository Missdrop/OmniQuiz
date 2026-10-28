// Runs the connection editor on a real native engine with isolated fixture storage.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/connection_ui_test.dart' show connectionFlow;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native connection selection, independent saves and localized phone editing',
    (tester) => connectionFlow(tester, native: true),
  );
}
