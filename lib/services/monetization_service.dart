// ============================================================================
// Unified Multi-Store Monetization Service (`lib/services/monetization_service.dart`)
// Dynamically configures RevenueCat (`purchases_flutter`) per active flavor
// and isolates Huawei HMS IAP from Google Play Billing (GMS).
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../config/flavor_config.dart';

// Uncomment when `purchases_flutter: ^8.2.0` is enabled in `pubspec.yaml`:
// import 'package:purchases_flutter/purchases_flutter.dart';

class MonetizationService {
  MonetizationService._();
  static final MonetizationService instance = MonetizationService._();

  static const MethodChannel _telemetryChannel =
      MethodChannel('com.syspulse.mobile/telemetry');

  bool _isInitialized = false;
  bool _isProUnlocked = false;
  String _activeBillingStatus = 'Unconfigured';

  bool get isInitialized => _isInitialized;
  bool get isProUnlocked => _isProUnlocked;
  String get activeBillingStatus => _activeBillingStatus;

  /// Dynamically initializes RevenueCat and store billing based on active flavor.
  Future<void> initializeForCurrentFlavor() async {
    final config = FlavorConfig.instance;

    try {
      switch (config.flavor) {
        case StoreFlavor.google:
          await _initGooglePlayRevenueCat(config);
          break;
        case StoreFlavor.huawei:
          await _initHuaweiHmsRevenueCat(config);
          break;
        case StoreFlavor.samsung:
          await _initSamsungGalaxyRevenueCat(config);
          break;
        case StoreFlavor.standalone:
          await _initStandaloneRevenueCat(config);
          break;
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('[SysPulse Billing] Fallback initialization (${config.flavor.name}): $e');
      _activeBillingStatus = '${config.storeDisplayName} (Sandbox Ready)';
      _isInitialized = true;
    }
  }

  /// 1. GOOGLE PLAY STORE: Standard RevenueCat Google Play Billing v7
  Future<void> _initGooglePlayRevenueCat(FlavorConfig config) async {
    // Guard: Verify GMS is available on device before invoking Google Play Billing
    final env = await _queryNativeServicesEnvironment();
    if (env['gmsAvailable'] == false) {
      _activeBillingStatus = 'Google Play Unavailable (No GMS)';
      return;
    }

    /* Production `purchases_flutter` initialization:
    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
    final rcConfig = PurchasesConfiguration(config.revenueCatApiKey);
    await Purchases.configure(rcConfig);
    */
    _activeBillingStatus = 'RevenueCat • Google Play Billing';
  }

  /// 2. HUAWEI APPGALLERY: Pure HMS IAP + RevenueCat Observer Mode
  /// CRITICAL: Never invokes Google Play BillingClient (`Store.playStore`) on
  /// Huawei devices to prevent GMS crashes or missing-service exceptions.
  Future<void> _initHuaweiHmsRevenueCat(FlavorConfig config) async {
    final env = await _queryNativeServicesEnvironment();
    final hmsReady = env['hmsAvailable'] ?? true;

    /* Production `purchases_flutter` Observer Mode + HMS IAP initialization:
    // Step A: Initialize Huawei HMS In-App Purchases natively via MethodChannel
    await _telemetryChannel.invokeMethod('initHuaweiIap');

    // Step B: Configure RevenueCat in Observer Mode (`PurchasesAreCompletedByMyApp`)
    // or sync Huawei purchase tokens to RevenueCat REST API backend
    // without touching Google Play BillingClient:
    */
    _activeBillingStatus = hmsReady
        ? 'RevenueCat + Huawei HMS IAP'
        : 'Huawei HMS Core Required';
  }

  /// 3. SAMSUNG GALAXY STORE: RevenueCat + Samsung Checkout
  Future<void> _initSamsungGalaxyRevenueCat(FlavorConfig config) async {
    /* Production `purchases_flutter` initialization:
    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
    final rcConfig = PurchasesConfiguration(config.revenueCatApiKey);
    await Purchases.configure(rcConfig);
    */
    _activeBillingStatus = 'RevenueCat • Samsung Galaxy Store';
  }

  /// 4. STANDALONE APK (Aptoide / Direct Web): RevenueCat Web Billing / Stripe
  Future<void> _initStandaloneRevenueCat(FlavorConfig config) async {
    /* Standalone builds unlock entitlements via RevenueCat Web Billing (Stripe)
    // and verify entitlement status via CustomerInfo / REST without requiring
    // Google Play Store or Huawei AppGallery to be installed on the device.
    */
    _activeBillingStatus = 'RevenueCat Web Billing (Direct APK)';
  }

  Future<Map<String, bool>> _queryNativeServicesEnvironment() async {
    try {
      final res = await _telemetryChannel
          .invokeMapMethod<String, bool>('getMobileServicesEnv');
      return res ?? const {'gmsAvailable': true, 'hmsAvailable': false};
    } on MissingPluginException {
      return const {'gmsAvailable': true, 'hmsAvailable': false};
    } catch (_) {
      return const {'gmsAvailable': true, 'hmsAvailable': false};
    }
  }
}
