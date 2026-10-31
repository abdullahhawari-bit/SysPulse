// ============================================================================
// Multi-Store Flavor Configuration (`lib/config/flavor_config.dart`)
// Supports: Google Play, Huawei AppGallery, Samsung Galaxy Store, Standalone APK
// ============================================================================

enum StoreFlavor { google, huawei, samsung, standalone }

enum MobileServicesBackend { gms, hms, independent }

enum BillingProvider { googlePlay, huaweiIap, samsungCheckout, stripeWeb }

class FlavorConfig {
  final StoreFlavor flavor;
  final String storeDisplayName;
  final MobileServicesBackend servicesBackend;
  final BillingProvider billingProvider;
  final String revenueCatApiKey;
  final String entitlementId;
  final bool allowCallLogPermission;
  final String storeMarketUri;

  const FlavorConfig._({
    required this.flavor,
    required this.storeDisplayName,
    required this.servicesBackend,
    required this.billingProvider,
    required this.revenueCatApiKey,
    this.entitlementId = 'syspulse_pro',
    required this.allowCallLogPermission,
    required this.storeMarketUri,
  });

  static FlavorConfig _instance = FlavorConfig.standalone();

  static FlavorConfig get instance => _instance;

  static void initialize(FlavorConfig config) {
    _instance = config;
  }

  bool get isGmsAllowed => servicesBackend == MobileServicesBackend.gms;
  bool get isHmsOnly => servicesBackend == MobileServicesBackend.hms;

  /// 1. Google Play Store Flavor (GMS + Google Play Billing, Play Policy Compliant)
  factory FlavorConfig.google() {
    return const FlavorConfig._(
      flavor: StoreFlavor.google,
      storeDisplayName: 'Google Play',
      servicesBackend: MobileServicesBackend.gms,
      billingProvider: BillingProvider.googlePlay,
      revenueCatApiKey: String.fromEnvironment(
        'RC_GOOGLE_API_KEY',
        defaultValue: 'goog_placeholder_rc_key',
      ),
      allowCallLogPermission: false, // Stripped for Google Play policy compliance
      storeMarketUri: 'market://details?id=com.syspulse.mobile',
    );
  }

  /// 2. Huawei AppGallery Flavor (Pure HMS + Huawei IAP, Zero GMS calls)
  factory FlavorConfig.huawei() {
    return const FlavorConfig._(
      flavor: StoreFlavor.huawei,
      storeDisplayName: 'Huawei AppGallery',
      servicesBackend: MobileServicesBackend.hms,
      billingProvider: BillingProvider.huaweiIap,
      revenueCatApiKey: String.fromEnvironment(
        'RC_HUAWEI_API_KEY',
        defaultValue: 'hms_placeholder_rc_key',
      ),
      allowCallLogPermission: true,
      storeMarketUri: 'appmarket://details?id=com.syspulse.mobile.huawei',
    );
  }

  /// 3. Samsung Galaxy Store Flavor (GMS + Samsung Checkout / RevenueCat)
  factory FlavorConfig.samsung() {
    return const FlavorConfig._(
      flavor: StoreFlavor.samsung,
      storeDisplayName: 'Samsung Galaxy Store',
      servicesBackend: MobileServicesBackend.gms,
      billingProvider: BillingProvider.samsungCheckout,
      revenueCatApiKey: String.fromEnvironment(
        'RC_SAMSUNG_API_KEY',
        defaultValue: 'sams_placeholder_rc_key',
      ),
      allowCallLogPermission: true,
      storeMarketUri: 'samsungapps://ProductDetail/com.syspulse.mobile',
    );
  }

  /// 4. Standalone APK Flavor (Aptoide / Direct Web Download, OS-Independent)
  factory FlavorConfig.standalone() {
    return const FlavorConfig._(
      flavor: StoreFlavor.standalone,
      storeDisplayName: 'Standalone Direct APK',
      servicesBackend: MobileServicesBackend.independent,
      billingProvider: BillingProvider.stripeWeb,
      revenueCatApiKey: String.fromEnvironment(
        'RC_STANDALONE_API_KEY',
        defaultValue: 'rcb_placeholder_web_billing_key',
      ),
      allowCallLogPermission: true,
      storeMarketUri: 'https://syspulse.io/download',
    );
  }
}
