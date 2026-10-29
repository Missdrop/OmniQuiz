// Exercises deletion confirmations and session disposal on a native engine using temporary libraries.
import 'package:integration_test/integration_test.dart';

import '../test/library_host_test.dart' as host;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  host.main(deletionOnly: true);
}
