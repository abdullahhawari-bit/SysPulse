import 'config/flavor_config.dart';
import 'main.dart';

/// Entrypoint for Standalone APK / Aptoide / Web (`--flavor standalone -t lib/main_standalone.dart`)
Future<void> main() async {
  await bootstrapSysPulseApp(FlavorConfig.standalone());
}
