import 'config/flavor_config.dart';
import 'main.dart';

/// Entrypoint for Samsung Galaxy Store (`--flavor samsung -t lib/main_samsung.dart`)
Future<void> main() async {
  await bootstrapSysPulseApp(FlavorConfig.samsung());
}
