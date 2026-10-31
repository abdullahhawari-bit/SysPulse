import 'config/flavor_config.dart';
import 'main.dart';

/// Entrypoint for Google Play Store (`--flavor google -t lib/main_google.dart`)
Future<void> main() async {
  await bootstrapSysPulseApp(FlavorConfig.google());
}
