import 'config/flavor_config.dart';
import 'main.dart';

/// Entrypoint for Huawei AppGallery (`--flavor huawei -t lib/main_huawei.dart`)
/// Relies strictly on HMS Core & Huawei IAP (zero GMS invocations).
Future<void> main() async {
  await bootstrapSysPulseApp(FlavorConfig.huawei());
}
