// ============================================================================
// SysPulse — Android System Monitoring & Analytics Mobile App (Dark Mode)
// ============================================================================
//
// REQUIRED ANDROID PERMISSIONS (`android/app/src/main/AndroidManifest.xml`):
// ----------------------------------------------------------------------------
// Declare inside `<manifest xmlns:android="..." xmlns:tools="http://schemas.android.com/tools">`:
//
// <!-- 1. App Usage Tracker (Android UsageStatsManager) -->
// <!-- Special permission: also launch Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS) -->
// <uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"
//     tools:ignore="ProtectedPermissions" />
//
// <!-- Package visibility on Android 11+ (API 30+) for Usage & Security Scanner -->
// <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES"
//     tools:ignore="QueryAllPackagesPermission" />
//
// <!-- 2. Network Stats (TrafficStats, ConnectivityManager, NetworkStatsManager) -->
// <uses-permission android:name="android.permission.INTERNET" />
// <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
// <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
//
// <!-- 3. Call Stats & Subscriber State (Runtime Dangerous Permissions) -->
// <!-- Request at runtime via `permission_handler` or ActivityCompat -->
// <uses-permission android:name="android.permission.READ_CALL_LOG" />
// <uses-permission android:name="android.permission.READ_PHONE_STATE" />
//
// <!-- 4. Battery Monitor & Alert/Fix System Process Termination -->
// <uses-permission android:name="android.permission.KILL_BACKGROUND_PROCESSES" />
// <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
//
// <!-- 5. Optional: Persistent Real-Time Telemetry Foreground Service -->
// <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
// <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
//
// SUGGESTED FLUTTER PACKAGES (`pubspec.yaml`):
// - `app_usage` / `usage_stats` : Query UsageStatsManager daily foreground time
// - `battery_plus`              : Read battery percentage, charging & health state
// - `call_log`                  : Query Android CallLog.Calls content provider
// - `connectivity_plus`         : Track active Wi-Fi / Cellular / VPN transport
// - `network_info_plus`         : Inspect Wi-Fi SSID & local IP interface
// - `permission_handler`        : Request READ_CALL_LOG & READ_PHONE_STATE at runtime
// - `safe_device` / `freerasp`  : Root, SELinux, emulator & ADB tamper checks
// - `fl_chart`                  : Optional charts (zero-dependency CustomPainters below)
// ============================================================================

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/flavor_config.dart';
import 'services/monetization_service.dart';
import 'ui/storage_vault_screen.dart';

Future<void> main() async {
  await bootstrapSysPulseApp(FlavorConfig.standalone());
}

/// Shared multi-store entrypoint invoked by `main_google.dart`, `main_huawei.dart`,
/// `main_samsung.dart`, and `main_standalone.dart`.
Future<void> bootstrapSysPulseApp(FlavorConfig flavorConfig) async {
  WidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.initialize(flavorConfig);
  await MonetizationService.instance.initializeForCurrentFlavor();

  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppPalette.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const SysPulseApp());
}

// ============================================================================
// 1. DARK MODE PALETTE & TYPOGRAPHY
// ============================================================================

class AppPalette {
  static const Color bg = Color(0xFF090D16);
  static const Color card = Color(0xFF111827);
  static const Color cardAlt = Color(0xFF192234);
  static const Color border = Color(0xFF1F2A40);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static const Color cyan = Color(0xFF06B6D4);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color emerald = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color coral = Color(0xFFEF4444);
  static const Color blue = Color(0xFF3B82F6);
}

extension _ColorAlpha on Color {
  Color alphaPct(double pct) => withAlpha((pct.clamp(0.0, 1.0) * 255).round());
}

class AppStyles {
  static const cardTitle = TextStyle(
      fontSize: 15.5, fontWeight: FontWeight.w700, color: AppPalette.textPrimary);
  static const cardSub =
      TextStyle(fontSize: 11.5, color: AppPalette.textSecondary);
  static const itemTitle = TextStyle(
      fontSize: 13.5, fontWeight: FontWeight.w600, color: AppPalette.textPrimary);
  static const caption = TextStyle(fontSize: 11, color: AppPalette.textMuted);
  static const metricLg = TextStyle(
      fontSize: 22, fontWeight: FontWeight.w800, color: AppPalette.textPrimary);
}

class SysPulseApp extends StatelessWidget {
  const SysPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SysPulse Monitor',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppPalette.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppPalette.cyan,
          secondary: AppPalette.violet,
          tertiary: AppPalette.emerald,
          surface: AppPalette.card,
          error: AppPalette.coral,
        ),
        appBarTheme: const AppBarTheme(
            backgroundColor: AppPalette.bg, elevation: 0, scrolledUnderElevation: 0),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppPalette.cardAlt,
          contentTextStyle: const TextStyle(color: AppPalette.textPrimary),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppPalette.border)),
        ),
      ),
      home: const MainDashboardScreen(),
    );
  }
}

// ============================================================================
// 2. DOMAIN MODELS (INCLUDING THE "ALERT & FIX SYSTEM" MODEL)
// ============================================================================

enum AlertSeverity { critical, warning, info }

/// Dart Model for the "Alert & Fix System" suggesting performance optimization
/// steps to the user (e.g., "Kill background processes").
class OptimizationAlert {
  final String id;
  final String title;
  final String description;
  final String actionLabel;
  final String estimatedImpact;
  final String nativeMethod;
  final List<String> targetPackages;
  final List<Map<String, String>> targetApps;
  final AlertSeverity severity;
  final bool isResolved;

  const OptimizationAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.estimatedImpact,
    required this.nativeMethod,
    this.targetPackages = const [],
    this.targetApps = const [],
    this.severity = AlertSeverity.warning,
    this.isResolved = false,
  });

  OptimizationAlert copyWith({bool? isResolved}) => OptimizationAlert(
        id: id,
        title: title,
        description: description,
        actionLabel: actionLabel,
        estimatedImpact: estimatedImpact,
        nativeMethod: nativeMethod,
        targetPackages: targetPackages,
        targetApps: targetApps,
        severity: severity,
        isResolved: isResolved ?? this.isResolved,
      );

  List<Map<String, String>> get effectiveTargetApps {
    if (targetApps.isNotEmpty) return targetApps;
    if (targetPackages.isNotEmpty) {
      return targetPackages.map((pkg) => {
        'package': pkg,
        'name': _formatPackageToHumanName(pkg),
      }).toList();
    }
    return const [];
  }

  static String _formatPackageToHumanName(String pkg) {
    if (pkg.contains('musically') || pkg.contains('tiktok')) return 'TikTok';
    if (pkg.contains('instagram')) return 'Instagram';
    if (pkg.contains('chrome')) return 'Google Chrome';
    if (pkg.contains('whatsapp')) return 'WhatsApp';
    if (pkg.contains('telegram')) return 'Telegram';
    if (pkg.contains('youtube')) return 'YouTube';
    if (pkg.contains('twitter') || pkg.contains('com.twitter')) return 'X / Twitter';
    if (pkg.contains('snapchat')) return 'Snapchat';
    if (pkg.contains('facebook')) return 'Facebook';
    if (pkg.contains('spotify')) return 'Spotify';
    final parts = pkg.split('.');
    if (parts.isNotEmpty) {
      final last = parts.last;
      if (last.isNotEmpty) {
        return last[0].toUpperCase() + last.substring(1);
      }
    }
    return pkg;
  }

  Color get color {
    switch (severity) {
      case AlertSeverity.critical:
        return AppPalette.coral;
      case AlertSeverity.warning:
        return AppPalette.amber;
      case AlertSeverity.info:
        return AppPalette.cyan;
    }
  }

  IconData get icon {
    switch (severity) {
      case AlertSeverity.critical:
        return Icons.memory_rounded;
      case AlertSeverity.warning:
        return Icons.battery_alert_rounded;
      case AlertSeverity.info:
        return Icons.network_check_rounded;
    }
  }
}

class AppUsageRecord {
  final String appName, packageName, category;
  final Duration screenTime;
  final int launches;
  final IconData icon;
  final Color color;

  const AppUsageRecord({
    required this.appName,
    required this.packageName,
    required this.category,
    required this.screenTime,
    required this.launches,
    required this.icon,
    required this.color,
  });
}

class NetworkTelemetry {
  final double dataInGb, dataOutGb, wifiGb, cellularGb, liveDownMbps, liveUpMbps;
  final String transportLabel;
  final List<double> rxSeriesMbps, txSeriesMbps;

  const NetworkTelemetry({
    required this.dataInGb,
    required this.dataOutGb,
    required this.wifiGb,
    required this.cellularGb,
    required this.liveDownMbps,
    required this.liveUpMbps,
    required this.transportLabel,
    required this.rxSeriesMbps,
    required this.txSeriesMbps,
  });
}

/// Lightweight live sample pushed by the native EventChannel (no full rebuild needed).
class LiveNetSample {
  final double downMbps, upMbps;
  final List<double> rxSeries, txSeries;

  const LiveNetSample({
    required this.downMbps,
    required this.upMbps,
    required this.rxSeries,
    required this.txSeries,
  });
}

class BatteryDrainItem {
  final String appName, packageName;
  final double drainPercent;
  final int mahConsumed, wakelockMins;
  final bool isBackgroundDrainer;
  final IconData icon;

  const BatteryDrainItem({
    required this.appName,
    required this.packageName,
    required this.drainPercent,
    required this.mahConsumed,
    required this.wakelockMins,
    required this.isBackgroundDrainer,
    required this.icon,
  });
}

class BatteryTelemetry {
  final int percentage;
  final bool isCharging;
  final double temperatureC, voltageV;
  final String health;
  final Duration estimatedLeft;
  final List<BatteryDrainItem> drainers;

  const BatteryTelemetry({
    required this.percentage,
    required this.isCharging,
    required this.temperatureC,
    required this.voltageV,
    required this.health,
    required this.estimatedLeft,
    required this.drainers,
  });

  BatteryTelemetry copyWith(
          {Duration? estimatedLeft, List<BatteryDrainItem>? drainers}) =>
      BatteryTelemetry(
        percentage: percentage,
        isCharging: isCharging,
        temperatureC: temperatureC,
        voltageV: voltageV,
        health: health,
        estimatedLeft: estimatedLeft ?? this.estimatedLeft,
        drainers: drainers ?? this.drainers,
      );
}

class SecurityCheckItem {
  final String label, detail;
  final bool passed;
  const SecurityCheckItem(this.label, this.detail, this.passed);
}

class SecurityAuditData {
  final String statusHeadline, patchLevel;
  final int securityScore, packagesScanned;
  final List<SecurityCheckItem> checks;

  const SecurityAuditData({
    required this.statusHeadline,
    required this.securityScore,
    required this.packagesScanned,
    required this.patchLevel,
    required this.checks,
  });
}

class CallAnalyticsData {
  final int incoming, outgoing, missed, rejected;
  final Duration totalTalkTime, avgDuration;
  final String peakWindow;

  const CallAnalyticsData({
    required this.incoming,
    required this.outgoing,
    required this.missed,
    required this.rejected,
    required this.totalTalkTime,
    required this.avgDuration,
    required this.peakWindow,
  });

  int get totalCalls => incoming + outgoing + missed + rejected;
}

class NativePermissionsStatus {
  final bool isNativeConnected;
  final bool usageAccess;
  final bool callLog;
  final bool phoneState;

  const NativePermissionsStatus({
    required this.isNativeConnected,
    required this.usageAccess,
    required this.callLog,
    required this.phoneState,
  });

  bool get allGranted => usageAccess && callLog && phoneState;
}

class DashboardBundle {
  final NativePermissionsStatus permissions;
  final List<OptimizationAlert> alerts;
  final List<AppUsageRecord> appUsage;
  final NetworkTelemetry network;
  final BatteryTelemetry battery;
  final SecurityAuditData security;
  final CallAnalyticsData calls;

  const DashboardBundle({
    required this.permissions,
    required this.alerts,
    required this.appUsage,
    required this.network,
    required this.battery,
    required this.security,
    required this.calls,
  });

  DashboardBundle copyWith({
    NativePermissionsStatus? permissions,
    List<OptimizationAlert>? alerts,
    List<AppUsageRecord>? appUsage,
    NetworkTelemetry? network,
    BatteryTelemetry? battery,
    SecurityAuditData? security,
    CallAnalyticsData? calls,
  }) {
    return DashboardBundle(
      permissions: permissions ?? this.permissions,
      alerts: alerts ?? this.alerts,
      appUsage: appUsage ?? this.appUsage,
      network: network ?? this.network,
      battery: battery ?? this.battery,
      security: security ?? this.security,
      calls: calls ?? this.calls,
    );
  }
}

// ============================================================================
// 3. ANDROID NATIVE METHODCHANNEL BRIDGE & MOCK FALLBACK PROVIDERS
// ============================================================================

class SysPulseNativeBridge {
  /// Connects to `MainActivity.kt` (`configureFlutterEngine`) on Android.
  static const MethodChannel _channel =
      MethodChannel('com.syspulse.mobile/telemetry');

  /// Native push stream: Kotlin sends one sample every 1.5s ONLY while listened to.
  static const EventChannel _networkStream =
      EventChannel('com.syspulse.mobile/network_stream');

  Stream<LiveNetSample> liveNetworkStream() {
    return _networkStream.receiveBroadcastStream().map((dynamic event) {
      final m = Map<String, dynamic>.from(event as Map);
      List<double> toList(dynamic v) => (v as List<dynamic>? ?? const [])
          .map((e) => (e as num).toDouble())
          .toList();
      return LiveNetSample(
        downMbps: (m['liveDownMbps'] as num?)?.toDouble() ?? 0.0,
        upMbps: (m['liveUpMbps'] as num?)?.toDouble() ?? 0.0,
        rxSeries: toList(m['rxSeriesMbps']),
        txSeries: toList(m['txSeriesMbps']),
      );
    });
  }

  static const _accentCycle = <Color>[
    AppPalette.coral,
    AppPalette.emerald,
    AppPalette.cyan,
    AppPalette.violet,
    AppPalette.amber,
    AppPalette.blue,
  ];

  Future<DashboardBundle> fetchAllTelemetry() async {
    final perms = await checkPermissionsStatus();
    final res = await Future.wait([
      fetchOptimizationAlerts(),
      fetchAppUsageToday(),
      fetchNetworkStats(),
      fetchBatteryTelemetry(),
      runDeviceSecurityScan(),
      fetchCallLogStats(),
    ]);
    return DashboardBundle(
      permissions: perms,
      alerts: res[0] as List<OptimizationAlert>,
      appUsage: res[1] as List<AppUsageRecord>,
      network: res[2] as NetworkTelemetry,
      battery: res[3] as BatteryTelemetry,
      security: res[4] as SecurityAuditData,
      calls: res[5] as CallAnalyticsData,
    );
  }

  /// Checks live Android permissions (`PACKAGE_USAGE_STATS`, `READ_CALL_LOG`, `READ_PHONE_STATE`).
  Future<NativePermissionsStatus> checkPermissionsStatus() async {
    try {
      final raw =
          await _channel.invokeMapMethod<String, dynamic>('checkPermissionsStatus');
      if (raw != null) {
        return NativePermissionsStatus(
          isNativeConnected: true,
          usageAccess: raw['usageAccess'] == true,
          callLog: raw['callLog'] == true,
          phoneState: raw['phoneState'] == true,
        );
      }
    } on MissingPluginException {
      // Running in standalone UI preview mode without MainActivity.kt host.
    } catch (_) {}
    return const NativePermissionsStatus(
      isNativeConnected: false,
      usageAccess: true,
      callLog: true,
      phoneState: true,
    );
  }

  /// Launches Android `Settings.ACTION_USAGE_ACCESS_SETTINGS` for this package.
  Future<void> openUsageAccessSettings() async {
    try {
      await _channel.invokeMethod<bool>('requestUsageAccessSettings');
    } catch (_) {}
  }

  /// Prompts the user for `READ_CALL_LOG` and `READ_PHONE_STATE` at runtime.
  Future<void> requestRuntimePermissions() async {
    try {
      await _channel.invokeMapMethod<String, dynamic>('requestRuntimePermissions');
    } catch (_) {}
  }

  /// Alert & Fix System live native inspection + mock fallback.
  Future<List<OptimizationAlert>> fetchOptimizationAlerts() async {
    try {
      final rawList =
          await _channel.invokeMethod<List<dynamic>>('getOptimizationAlerts');
      if (rawList != null && rawList.isNotEmpty) {
        return rawList.map((entry) {
          final m = Map<String, dynamic>.from(entry as Map);
          final sevStr = (m['severity'] as String?) ?? 'warning';
          final sev = sevStr == 'critical'
              ? AlertSeverity.critical
              : (sevStr == 'info' ? AlertSeverity.info : AlertSeverity.warning);
          final pkgs = (m['targetPackages'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList();
          final rawApps = (m['targetApps'] as List<dynamic>? ?? const []);
          final apps = rawApps.map((e) {
            final appMap = Map<String, dynamic>.from(e as Map);
            return {
              'package': (appMap['package'] ?? '').toString(),
              'name': (appMap['name'] ?? '').toString(),
            };
          }).toList();
          return OptimizationAlert(
            id: (m['id'] as String?) ?? 'opt',
            title: (m['title'] as String?) ?? 'System Optimization',
            description: (m['description'] as String?) ?? '',
            actionLabel: (m['actionLabel'] as String?) ?? 'Optimize',
            estimatedImpact: (m['estimatedImpact'] as String?) ?? '',
            nativeMethod:
                (m['nativeMethod'] as String?) ?? 'killBackgroundProcesses',
            targetPackages: pkgs,
            targetApps: apps,
            severity: sev,
          );
        }).toList();
      }
    } catch (_) {}

    return const [
      OptimizationAlert(
        id: 'kill_bg',
        title: 'Kill background processes',
        description:
            '3 idle social services are holding partial CPU wakelocks.',
        actionLabel: 'Kill Now',
        estimatedImpact: '+42m Battery • 410 MB RAM freed',
        nativeMethod: 'killBackgroundProcesses',
        targetPackages: [
          'com.zhiliaoapp.musically',
          'com.instagram.android',
          'com.facebook.katana',
        ],
        targetApps: [
          {'name': 'TikTok', 'package': 'com.zhiliaoapp.musically'},
          {'name': 'Instagram', 'package': 'com.instagram.android'},
          {'name': 'Facebook', 'package': 'com.facebook.katana'},
        ],
        severity: AlertSeverity.critical,
      ),
      OptimizationAlert(
        id: 'restrict_sync',
        title: 'Throttle rogue background sync',
        description: 'Cloud media indexer triggered 28 wakeups in the last hour.',
        actionLabel: 'Restrict',
        estimatedImpact: '-18% Standby Drain',
        nativeMethod: 'setAppStandbyRestricted',
        targetPackages: ['com.cloud.media.sync'],
        severity: AlertSeverity.warning,
      ),
      OptimizationAlert(
        id: 'flush_sockets',
        title: 'Flush stale 5G radio sockets',
        description: 'Release idle TCP keep-alive sockets holding modem active.',
        actionLabel: 'Optimize',
        estimatedImpact: '-9% Modem Power',
        nativeMethod: 'flushIdleSockets',
        severity: AlertSeverity.info,
      ),
    ];
  }

  Future<bool> executeFix(OptimizationAlert alert) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
          alert.nativeMethod, {'packages': alert.targetPackages});
      return ok ?? true;
    } on MissingPluginException {
      await Future<void>.delayed(const Duration(milliseconds: 280));
      return true;
    } on PlatformException {
      return false;
    }
  }

  /// App Usage Tracker via Android `UsageStatsManager` (with mock fallback).
  Future<List<AppUsageRecord>> fetchAppUsageToday() async {
    try {
      final raw =
          await _channel.invokeMapMethod<String, dynamic>('getDailyAppUsage');
      if (raw != null && raw['permissionGranted'] == true) {
        final items = raw['items'] as List<dynamic>? ?? const [];
        if (items.isNotEmpty) {
          return List<AppUsageRecord>.generate(items.length, (idx) {
            final m = Map<String, dynamic>.from(items[idx] as Map);
            final category = (m['category'] as String?) ?? 'Application';
            return AppUsageRecord(
              appName: (m['appName'] as String?) ?? 'App',
              packageName: (m['packageName'] as String?) ?? '',
              category: category,
              screenTime:
                  Duration(minutes: (m['minutes'] as num?)?.toInt() ?? 1),
              launches: (m['launches'] as num?)?.toInt() ?? 1,
              icon: _iconForCategory(category),
              color: _accentCycle[idx % _accentCycle.length],
            );
          });
        }
      }
    } catch (_) {}

    return const [
      AppUsageRecord(
          appName: 'YouTube',
          packageName: 'com.google.android.youtube',
          category: 'Video & Media',
          screenTime: Duration(hours: 2, minutes: 18),
          launches: 19,
          icon: Icons.play_circle_fill_rounded,
          color: AppPalette.coral),
      AppUsageRecord(
          appName: 'WhatsApp',
          packageName: 'com.whatsapp',
          category: 'Messaging',
          screenTime: Duration(hours: 1, minutes: 34),
          launches: 46,
          icon: Icons.chat_bubble_rounded,
          color: AppPalette.emerald),
      AppUsageRecord(
          appName: 'Chrome',
          packageName: 'com.android.chrome',
          category: 'Browser',
          screenTime: Duration(hours: 1, minutes: 5),
          launches: 24,
          icon: Icons.public_rounded,
          color: AppPalette.cyan),
      AppUsageRecord(
          appName: 'Instagram',
          packageName: 'com.instagram.android',
          category: 'Social',
          screenTime: Duration(minutes: 49),
          launches: 31,
          icon: Icons.camera_alt_rounded,
          color: AppPalette.violet),
      AppUsageRecord(
          appName: 'Call of Duty Mobile',
          packageName: 'com.activision.callofduty.shooter',
          category: 'Gaming',
          screenTime: Duration(minutes: 32),
          launches: 3,
          icon: Icons.sports_esports_rounded,
          color: AppPalette.amber),
    ];
  }

  /// Network Stats via Android `NetworkStatsManager` & `TrafficStats`.
  Future<NetworkTelemetry> fetchNetworkStats() async {
    try {
      final m =
          await _channel.invokeMapMethod<String, dynamic>('getNetworkStats');
      if (m != null) {
        final rxList = (m['rxSeriesMbps'] as List<dynamic>? ?? const [])
            .map((e) => (e as num).toDouble())
            .toList();
        final txList = (m['txSeriesMbps'] as List<dynamic>? ?? const [])
            .map((e) => (e as num).toDouble())
            .toList();
        return NetworkTelemetry(
          dataInGb: (m['dataInGb'] as num?)?.toDouble() ?? 0.0,
          dataOutGb: (m['dataOutGb'] as num?)?.toDouble() ?? 0.0,
          wifiGb: (m['wifiGb'] as num?)?.toDouble() ?? 0.0,
          cellularGb: (m['cellularGb'] as num?)?.toDouble() ?? 0.0,
          liveDownMbps: (m['liveDownMbps'] as num?)?.toDouble() ?? 0.0,
          liveUpMbps: (m['liveUpMbps'] as num?)?.toDouble() ?? 0.0,
          transportLabel: (m['transportLabel'] as String?) ?? 'Connected',
          rxSeriesMbps: rxList.length >= 2 ? rxList : const [0.4, 0.8],
          txSeriesMbps: txList.length >= 2 ? txList : const [0.1, 0.3],
        );
      }
    } catch (_) {}

    return const NetworkTelemetry(
      dataInGb: 3.84,
      dataOutGb: 0.92,
      wifiGb: 3.12,
      cellularGb: 0.72,
      liveDownMbps: 48.6,
      liveUpMbps: 14.2,
      transportLabel: 'Wi-Fi 6 (5 GHz) • 5G Ready',
      rxSeriesMbps: [12, 19, 15, 34, 42, 29, 56, 61, 38, 44, 52, 48.6],
      txSeriesMbps: [4, 7, 6, 11, 16, 9, 18, 21, 13, 15, 17, 14.2],
    );
  }

  /// Battery Monitor via Android `BatteryManager` & `PowerManager`.
  Future<BatteryTelemetry> fetchBatteryTelemetry() async {
    try {
      final m =
          await _channel.invokeMapMethod<String, dynamic>('getBatteryStats');
      if (m != null) {
        final rawDrainers = m['drainers'] as List<dynamic>? ?? const [];
        final parsedDrainers = rawDrainers.map((d) {
          final dm = Map<String, dynamic>.from(d as Map);
          final isBg = dm['isBackgroundDrainer'] == true;
          return BatteryDrainItem(
            appName: (dm['appName'] as String?) ?? 'Process',
            packageName: (dm['packageName'] as String?) ?? '',
            drainPercent: (dm['drainPercent'] as num?)?.toDouble() ?? 1.5,
            mahConsumed: (dm['mahConsumed'] as num?)?.toInt() ?? 25,
            wakelockMins: (dm['wakelockMins'] as num?)?.toInt() ?? 5,
            isBackgroundDrainer: isBg,
            icon: isBg ? Icons.bolt_rounded : Icons.apps_rounded,
          );
        }).toList();

        return BatteryTelemetry(
          percentage: (m['percentage'] as num?)?.toInt() ?? 78,
          isCharging: m['isCharging'] == true,
          temperatureC: (m['temperatureC'] as num?)?.toDouble() ?? 32.0,
          voltageV: (m['voltageV'] as num?)?.toDouble() ?? 4.0,
          health: (m['health'] as String?) ?? 'Good',
          estimatedLeft: Duration(
              minutes: (m['estimatedMinutesLeft'] as num?)?.toInt() ?? 300),
          drainers: parsedDrainers,
        );
      }
    } catch (_) {}

    return const BatteryTelemetry(
      percentage: 78,
      isCharging: false,
      temperatureC: 33.4,
      voltageV: 4.12,
      health: 'Good',
      estimatedLeft: Duration(hours: 6, minutes: 45),
      drainers: [
        BatteryDrainItem(
            appName: 'TikTok Push Service',
            packageName: 'com.zhiliaoapp.musically',
            drainPercent: 14.8,
            mahConsumed: 412,
            wakelockMins: 54,
            isBackgroundDrainer: true,
            icon: Icons.bolt_rounded),
        BatteryDrainItem(
            appName: 'Instagram Background Sync',
            packageName: 'com.instagram.android',
            drainPercent: 9.6,
            mahConsumed: 268,
            wakelockMins: 39,
            isBackgroundDrainer: true,
            icon: Icons.sync_problem_rounded),
        BatteryDrainItem(
            appName: 'YouTube (Active Screen)',
            packageName: 'com.google.android.youtube',
            drainPercent: 18.2,
            mahConsumed: 510,
            wakelockMins: 12,
            isBackgroundDrainer: false,
            icon: Icons.play_circle_outline_rounded),
        BatteryDrainItem(
            appName: 'Meta App Manager',
            packageName: 'com.facebook.katana',
            drainPercent: 6.4,
            mahConsumed: 175,
            wakelockMins: 27,
            isBackgroundDrainer: true,
            icon: Icons.notifications_active_rounded),
      ],
    );
  }

  /// Security Scanner via Android `PackageManager`, `Build.TAGS`, and `ADB` check.
  Future<SecurityAuditData> runDeviceSecurityScan() async {
    try {
      final m =
          await _channel.invokeMapMethod<String, dynamic>('runSecurityScan');
      if (m != null) {
        final rawChecks = m['checks'] as List<dynamic>? ?? const [];
        final parsedChecks = rawChecks.map((c) {
          final cm = Map<String, dynamic>.from(c as Map);
          return SecurityCheckItem(
            (cm['label'] as String?) ?? 'Check',
            (cm['detail'] as String?) ?? '',
            cm['passed'] == true,
          );
        }).toList();
        return SecurityAuditData(
          statusHeadline:
              (m['statusHeadline'] as String?) ?? 'No Threats Found',
          securityScore: (m['securityScore'] as num?)?.toInt() ?? 98,
          packagesScanned: (m['packagesScanned'] as num?)?.toInt() ?? 0,
          patchLevel: (m['patchLevel'] as String?) ?? 'Latest',
          checks: parsedChecks,
        );
      }
    } catch (_) {}

    await Future<void>.delayed(const Duration(milliseconds: 220));
    return const SecurityAuditData(
      statusHeadline: 'No Threats Found',
      securityScore: 98,
      packagesScanned: 142,
      patchLevel: '2026-10-05',
      checks: [
        SecurityCheckItem(
            'Root & Bootloader Integrity', 'Verified Boot • SELinux Enforcing', true),
        SecurityCheckItem(
            'Installed APK Signature Audit', '142 packages verified clean', true),
        SecurityCheckItem(
            'Play Protect & Sideload Guard', 'Real-time protection enabled', true),
        SecurityCheckItem(
            'USB Debugging (ADB) Exposure', 'ADB interface locked', true),
      ],
    );
  }

  /// Call Stats via Android `CallLog.Calls` ContentResolver.
  Future<CallAnalyticsData> fetchCallLogStats() async {
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('getCallStats');
      if (m != null && m['permissionGranted'] == true) {
        return CallAnalyticsData(
          incoming: (m['incoming'] as num?)?.toInt() ?? 0,
          outgoing: (m['outgoing'] as num?)?.toInt() ?? 0,
          missed: (m['missed'] as num?)?.toInt() ?? 0,
          rejected: (m['rejected'] as num?)?.toInt() ?? 0,
          totalTalkTime: Duration(
              seconds: (m['totalTalkSeconds'] as num?)?.toInt() ?? 0),
          avgDuration: Duration(
              seconds: (m['avgDurationSeconds'] as num?)?.toInt() ?? 0),
          peakWindow: (m['peakWindow'] as String?) ?? 'N/A',
        );
      }
    } catch (_) {}

    return const CallAnalyticsData(
      incoming: 18,
      outgoing: 14,
      missed: 3,
      rejected: 2,
      totalTalkTime: Duration(hours: 1, minutes: 48),
      avgDuration: Duration(minutes: 3, seconds: 22),
      peakWindow: '14:00 – 17:00',
    );
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Gaming':
        return Icons.sports_esports_rounded;
      case 'Video & Media':
      case 'Music & Audio':
        return Icons.play_circle_fill_rounded;
      case 'Social':
        return Icons.chat_bubble_rounded;
      case 'Photography':
        return Icons.camera_alt_rounded;
      case 'Productivity':
      case 'News & Reading':
        return Icons.public_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  Future<bool> uninstallApp(String packageName) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
        'uninstallApp',
        {'packageName': packageName},
      );
      return ok ?? true;
    } catch (_) {
      return false;
    }
  }
}

// ============================================================================
// 4. MOBILE-RESPONSIVE MAIN DASHBOARD SCREEN
// ============================================================================

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen>
    with WidgetsBindingObserver {
  final SysPulseNativeBridge _bridge = SysPulseNativeBridge();
  DashboardBundle? _data;
  bool _loading = true;
  bool _rescanningSecurity = false;
  String? _busyAlertId;
  int _navIndex = 0;

  /// Live network sample pushed from Kotlin; only the widgets listening to this
  /// notifier rebuild every tick (not the whole dashboard).
  final ValueNotifier<LiveNetSample?> _liveNet = ValueNotifier<LiveNetSample?>(null);
  StreamSubscription<LiveNetSample>? _liveNetSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboard();
    _syncLiveStream();
  }

  bool get _liveStreamWanted => _navIndex == 0 || _navIndex == 2;

  /// Start the native push stream only while Home/Network is visible; stop it otherwise
  /// (zero CPU / battery cost on other tabs or when the app is in background).
  void _syncLiveStream() {
    if (_liveStreamWanted) {
      if (_liveNetSub != null) return;
      _liveNetSub = _bridge.liveNetworkStream().listen(
        (sample) => _liveNet.value = sample,
        onError: (_) {},
        cancelOnError: false,
      );
    } else {
      _liveNetSub?.cancel();
      _liveNetSub = null;
    }
  }

  void _stopLiveStream() {
    _liveNetSub?.cancel();
    _liveNetSub = null;
  }

  @override
  void dispose() {
    _stopLiveStream();
    _liveNet.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDashboard();
      _syncLiveStream();
    } else if (state == AppLifecycleState.paused) {
      _stopLiveStream();
    }
  }

  Future<void> _loadDashboard() async {
    if (_data == null) setState(() => _loading = true);
    final bundle = await _bridge.fetchAllTelemetry();
    if (!mounted) return;
    setState(() {
      _data = bundle;
      _loading = false;
    });
  }

  Future<void> _handleGrantUsageAccess() async {
    await _bridge.openUsageAccessSettings();
  }

  Future<void> _handleRequestRuntimePermissions() async {
    await _bridge.requestRuntimePermissions();
    await _loadDashboard();
  }

  Future<void> _applyOptimization(OptimizationAlert alert) async {
    if (_data == null || alert.isResolved) return;
    setState(() => _busyAlertId = alert.id);
    final ok = await _bridge.executeFix(alert);
    if (!mounted) return;

    if (ok) {
      final cur = _data!;
      final updatedAlerts = cur.alerts
          .map((a) => a.id == alert.id ? a.copyWith(isResolved: true) : a)
          .toList();
      var updatedBattery = cur.battery;
      if (alert.id == 'kill_bg') {
        updatedBattery = cur.battery.copyWith(
          estimatedLeft: cur.battery.estimatedLeft + const Duration(minutes: 42),
          drainers: cur.battery.drainers
              .where((d) => !alert.targetPackages.contains(d.packageName))
              .toList(),
        );
      }
      setState(() {
        _busyAlertId = null;
        _data = DashboardBundle(
          permissions: cur.permissions,
          alerts: updatedAlerts,
          appUsage: cur.appUsage,
          network: cur.network,
          battery: updatedBattery,
          security: cur.security,
          calls: cur.calls,
        );
      });
      final appCount = alert.effectiveTargetApps.length;
      final msg = alert.id == 'kill_bg' && appCount > 0
          ? 'Terminated background processes for $appCount application(s).'
          : 'Optimized: ${alert.title} (${alert.estimatedImpact})';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppPalette.emerald,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
    } else {
      setState(() => _busyAlertId = null);
    }
  }

  Future<void> _rescanSecurity() async {
    if (_data == null || _rescanningSecurity) return;
    setState(() => _rescanningSecurity = true);
    final updated = await _bridge.runDeviceSecurityScan();
    if (!mounted) return;
    setState(() {
      _rescanningSecurity = false;
      _data = DashboardBundle(
        permissions: _data!.permissions,
        alerts: _data!.alerts,
        appUsage: _data!.appUsage,
        network: _data!.network,
        battery: _data!.battery,
        security: updated,
        calls: _data!.calls,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: _loading || _data == null
            ? const Center(
                child: CircularProgressIndicator(color: AppPalette.cyan))
            : RefreshIndicator(
                color: AppPalette.cyan,
                backgroundColor: AppPalette.cardAlt,
                onRefresh: _loadDashboard,
                child: LayoutBuilder(
                  builder: (_, constraints) => _buildBody(_data!,
                      isFoldableWidth: constraints.maxWidth >= 620),
                ),
              ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isNative = _data?.permissions.isNativeConnected == true;
    return AppBar(
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppPalette.cyan, AppPalette.violet]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.speed_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SysPulse', style: AppStyles.cardTitle),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Direct APK • ${MonetizationService.instance.activeBillingStatus}',
                      style: AppStyles.caption,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        _StatusBadge(
          text: isNative ? '● NATIVE' : '● PREVIEW',
          color: isNative ? AppPalette.emerald : AppPalette.cyan,
        ),
        IconButton(
          tooltip: 'Refresh Telemetry',
          onPressed: _loadDashboard,
          icon: const Icon(Icons.refresh_rounded, color: AppPalette.textSecondary),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppPalette.border))),
      child: NavigationBar(
        height: 65,
        backgroundColor: AppPalette.bg,
        indicatorColor: AppPalette.cyan.alphaPct(0.18),
        selectedIndex: _navIndex,
        onDestinationSelected: (i) {
          setState(() => _navIndex = i);
          _syncLiveStream();
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded, color: AppPalette.cyan),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.apps_outlined),
              selectedIcon: Icon(Icons.apps_rounded, color: AppPalette.cyan),
              label: 'Usage'),
          NavigationDestination(
              icon: Icon(Icons.swap_vert_circle_outlined),
              selectedIcon: Icon(Icons.swap_vert_circle, color: AppPalette.cyan),
              label: 'Network'),
          NavigationDestination(
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield_rounded, color: AppPalette.cyan),
              label: 'Security'),
          NavigationDestination(
              icon: Icon(Icons.folder_zip_outlined),
              selectedIcon: Icon(Icons.folder_zip_rounded, color: AppPalette.cyan),
              label: 'Vault'),
        ],
      ),
    );
  }

  Widget _buildBody(DashboardBundle d, {required bool isFoldableWidth}) {
    if (_navIndex == 4) {
      return const StorageVaultScreen();
    }

    final showAll = _navIndex == 0;
    final showPermBanner =
        d.permissions.isNativeConnected && !d.permissions.allGranted;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        if (showPermBanner) ...[
          _buildPermissionsSetupCard(d.permissions),
          const SizedBox(height: 16),
        ],
        _buildTopSummaryStrip(d),
        const SizedBox(height: 16),
        if (showAll) ...[
          _buildStorageVaultQuickBanner(),
          const SizedBox(height: 16),
        ],
        if (showAll || _navIndex == 3) ...[
          _buildAlertFixCard(d.alerts),
          const SizedBox(height: 16),
        ],
        if (isFoldableWidth && showAll) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _buildAppUsageCard(d.appUsage)),
            const SizedBox(width: 16),
            Expanded(child: _buildNetworkStatsCard(d.network)),
          ]),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _buildBatteryMonitorCard(d.battery)),
            const SizedBox(width: 16),
            Expanded(child: _buildSecurityScannerCard(d.security)),
          ]),
          const SizedBox(height: 16),
          _buildCallStatsCard(d.calls),
        ] else ...[
          if (showAll || _navIndex == 1) ...[
            _buildAppUsageCard(d.appUsage),
            const SizedBox(height: 16),
          ],
          if (showAll || _navIndex == 2) ...[
            _buildNetworkStatsCard(d.network),
            const SizedBox(height: 16),
          ],
          if (showAll || _navIndex == 1) ...[
            _buildBatteryMonitorCard(d.battery),
            const SizedBox(height: 16),
          ],
          if (showAll || _navIndex == 3) ...[
            _buildSecurityScannerCard(d.security),
            const SizedBox(height: 16),
          ],
          if (showAll || _navIndex == 1) _buildCallStatsCard(d.calls),
        ],
      ],
    );
  }

  Widget _buildStorageVaultQuickBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppPalette.cyan.withOpacity(0.12),
            AppPalette.violet.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.cyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppPalette.cyan.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.folder_zip_rounded,
                    color: AppPalette.cyan, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Storage Vault & Cloud Archiver',
                        style: AppStyles.cardTitle),
                    Text(
                        'Analyze duplicates, cold storage & offload to Drive / OneDrive',
                        style: AppStyles.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildFeatureBadge('👥 Duplicates'),
              _buildFeatureBadge('❄️ Dormant Files'),
              _buildFeatureBadge('☁️ Cloud Backup'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() => _navIndex = 4);
                _syncLiveStream();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.cyan,
                foregroundColor: AppPalette.bg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text(
                'Open Storage Vault ➔',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppPalette.cardAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppPalette.border),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 10, color: AppPalette.textPrimary)),
    );
  }

  Widget _buildPermissionsSetupCard(NativePermissionsStatus perms) {
    return _DashboardCard(
      title: 'Android Telemetry Permissions',
      subtitle: 'Grant sensor permissions to replace preview data with live OS stats',
      icon: Icons.admin_panel_settings_rounded,
      iconColor: AppPalette.cyan,
      child: Column(
        children: [
          const SizedBox(height: 12),
          if (!perms.usageAccess)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Usage Access (App Screen Time & Wakelocks)',
                      style: AppStyles.cardSub,
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _handleGrantUsageAccess,
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            ),
          if (!perms.callLog || !perms.phoneState)
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Call Log & Cellular Telemetry Access',
                    style: AppStyles.cardSub,
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _handleRequestRuntimePermissions,
                  child: const Text('Allow Access'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTopSummaryStrip(DashboardBundle d) {
    final mins =
        d.appUsage.fold<int>(0, (s, item) => s + item.screenTime.inMinutes);
    final pending = d.alerts.where((a) => !a.isResolved).length;
    return Row(
      children: [
        Expanded(
            child: _QuickStatPill(
                label: 'Screen Time',
                value: _fmtDuration(Duration(minutes: mins)),
                icon: Icons.timelapse_rounded,
                accent: AppPalette.violet)),
        const SizedBox(width: 10),
        Expanded(
            child: _QuickStatPill(
                label: 'Battery',
                value: '${d.battery.percentage}%',
                icon: Icons.battery_charging_full_rounded,
                accent: AppPalette.emerald)),
        const SizedBox(width: 10),
        Expanded(
            child: _QuickStatPill(
                label: 'Optimizer',
                value: pending == 0 ? 'Optimal' : '$pending Alerts',
                icon: pending == 0
                    ? Icons.check_circle_rounded
                    : Icons.auto_fix_high_rounded,
                accent: pending == 0 ? AppPalette.emerald : AppPalette.amber)),
      ],
    );
  }

  // --- ALERT & FIX SYSTEM WIDGET ---
  Widget _buildAlertFixCard(List<OptimizationAlert> alerts) {
    final unresolved = alerts.where((a) => !a.isResolved).length;
    final badgeColor = unresolved == 0 ? AppPalette.emerald : AppPalette.amber;

    return _DashboardCard(
      title: 'Alert & Optimizer',
      subtitle: unresolved == 0
          ? 'All optimizations applied'
          : '$unresolved actions recommended',
      icon: Icons.auto_fix_high_rounded,
      iconColor: badgeColor,
      trailing: _StatusBadge(
          text: unresolved == 0 ? 'OPTIMAL' : '$unresolved ISSUES',
          color: badgeColor),
      child: Column(
        children: alerts.map((alert) {
          final isBusy = _busyAlertId == alert.id;
          final c = alert.isResolved ? AppPalette.emerald : alert.color;
          return Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppPalette.cardAlt.alphaPct(0.75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.alphaPct(0.32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: c.alphaPct(0.15),
                          borderRadius: BorderRadius.circular(9)),
                      child: Icon(alert.isResolved ? Icons.check_rounded : alert.icon,
                          size: 18, color: c),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(alert.title,
                              maxLines: 2,
                              style: AppStyles.itemTitle.copyWith(
                                  fontSize: 13,
                                  color: alert.isResolved
                                      ? AppPalette.textSecondary
                                      : AppPalette.textPrimary,
                                  decoration: alert.isResolved
                                      ? TextDecoration.lineThrough
                                      : null)),
                          const SizedBox(height: 3),
                          Text(alert.description,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: AppStyles.cardSub.copyWith(fontSize: 11)),
                          const SizedBox(height: 5),
                          Text(alert.estimatedImpact,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: c)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 34,
                      child: FilledButton.tonal(
                        onPressed: alert.isResolved || isBusy
                            ? null
                            : () => _applyOptimization(alert),
                        style: FilledButton.styleFrom(
                          backgroundColor: c.alphaPct(0.18),
                          foregroundColor: c,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
                        ),
                        child: isBusy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(alert.isResolved ? 'Done' : alert.actionLabel,
                                style: const TextStyle(
                                    fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
                if (alert.effectiveTargetApps.isNotEmpty && !alert.isResolved) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppPalette.bg.alphaPct(0.65),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppPalette.border.alphaPct(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.layers_clear_rounded, size: 12, color: c),
                            const SizedBox(width: 5),
                            Text(
                              'Target Applications (${alert.effectiveTargetApps.length}):',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppPalette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: alert.effectiveTargetApps.map((app) {
                            final name = (app['name'] != null && app['name']!.isNotEmpty)
                                ? app['name']!
                                : (app['package'] ?? 'App');
                            return Tooltip(
                              message: app['package'] ?? '',
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: AppPalette.cardAlt,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: c.alphaPct(0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.apps_rounded, size: 11, color: c),
                                    const SizedBox(width: 4),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 130),
                                      child: Text(
                                        name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                          color: AppPalette.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- 1. APP USAGE TRACKER ---
  Widget _buildAppUsageCard(List<AppUsageRecord> apps) {
    final totalMins =
        math.max(1, apps.fold<int>(0, (s, a) => s + a.screenTime.inMinutes));
    return _DashboardCard(
      title: 'App Usage Tracker',
      subtitle: 'Most used apps today • UsageStatsManager',
      icon: Icons.apps_rounded,
      iconColor: AppPalette.violet,
      trailing: Text(_fmtDuration(Duration(minutes: totalMins)),
          style: AppStyles.itemTitle.copyWith(fontWeight: FontWeight.w800)),
      child: Column(
        children: [
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: apps
                    .map((a) => Expanded(
                          flex: math.max(1, a.screenTime.inMinutes),
                          child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              color: a.color),
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 15),
          ...apps.map((app) {
            final ratio =
                (app.screenTime.inMinutes / totalMins).clamp(0.0, 1.0);
            final pct = (ratio * 100).round();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: app.color.alphaPct(0.15),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(app.icon, color: app.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(app.appName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppStyles.itemTitle)),
                          Text('${_fmtDuration(app.screenTime)} ($pct%)',
                              style: AppStyles.cardSub
                                  .copyWith(fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 2),
                        Text('${app.category} • ${app.launches} launches',
                            style: AppStyles.caption),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 5,
                            backgroundColor: AppPalette.cardAlt,
                            valueColor: AlwaysStoppedAnimation<Color>(app.color),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Uninstall ${app.appName}',
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 19, color: AppPalette.coral),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    onPressed: () => _showUninstallAppDialog(app),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showUninstallAppDialog(AppUsageRecord app) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppPalette.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: AppPalette.coral, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Uninstall ${app.appName}?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          'SysPulse will launch the Android package uninstaller for:\n"${app.packageName}".\n\nThis will remove the application and free up system storage & RAM.',
          style: const TextStyle(fontSize: 13, color: AppPalette.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppPalette.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.coral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _bridge.uninstallApp(app.packageName);
            },
            child: const Text('Open Uninstaller'),
          ),
        ],
      ),
    );
  }

  static String _formatThroughput(double mbps) {
    if (mbps <= 0.0001) return '0.0 Kbps';
    if (mbps < 0.1) {
      return '${(mbps * 1000).toStringAsFixed(1)} Kbps';
    }
    if (mbps < 1.0) {
      return '${(mbps * 1000).toStringAsFixed(0)} Kbps';
    }
    return '${mbps.toStringAsFixed(2)} Mbps';
  }

  // --- 2. NETWORK STATS ---
  Widget _buildNetworkStatsCard(NetworkTelemetry net) {
    return _DashboardCard(
      title: 'Network Stats',
      subtitle: net.transportLabel,
      icon: Icons.swap_vert_rounded,
      iconColor: AppPalette.cyan,
      trailing: _StatusBadge(
          text: '${(net.dataInGb + net.dataOutGb).toStringAsFixed(2)} GB',
          color: AppPalette.cyan),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Only this Row rebuilds on each live tick (not the whole dashboard)
          ValueListenableBuilder<LiveNetSample?>(
            valueListenable: _liveNet,
            builder: (_, live, __) => Row(children: [
              Expanded(
                  child: _TrafficStatBox(
                      title: 'DATA IN (RX)',
                      total: '${net.dataInGb.toStringAsFixed(2)} GB',
                      rate: _formatThroughput(live?.downMbps ?? net.liveDownMbps),
                      icon: Icons.arrow_downward_rounded,
                      color: AppPalette.cyan)),
              const SizedBox(width: 10),
              Expanded(
                  child: _TrafficStatBox(
                      title: 'DATA OUT (TX)',
                      total: '${net.dataOutGb.toStringAsFixed(2)} GB',
                      rate: _formatThroughput(live?.upMbps ?? net.liveUpMbps),
                      icon: Icons.arrow_upward_rounded,
                      color: AppPalette.violet)),
            ]),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppPalette.emerald,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('Live Throughput (Real-Time)', style: AppStyles.cardSub),
                ],
              ),
              const Row(children: [
                _LegendDot(color: AppPalette.cyan, label: 'Data In'),
                SizedBox(width: 12),
                _LegendDot(color: AppPalette.violet, label: 'Data Out'),
              ]),
            ],
          ),
          const SizedBox(height: 10),
          // RepaintBoundary isolates the animated chart's GPU layer from the rest of the screen
          RepaintBoundary(
            child: SizedBox(
              height: 132,
              width: double.infinity,
              child: ValueListenableBuilder<LiveNetSample?>(
                valueListenable: _liveNet,
                builder: (_, live, __) => CustomPaint(
                    painter: NetworkAreaChartPainter(
                        inbound: live?.rxSeries ?? net.rxSeriesMbps,
                        outbound: live?.txSeries ?? net.txSeriesMbps)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Wi-Fi: ${net.wifiGb.toStringAsFixed(2)} GB',
                  style: AppStyles.caption),
              Text('Cellular: ${net.cellularGb.toStringAsFixed(2)} GB',
                  style: AppStyles.caption),
            ],
          ),
        ],
      ),
    );
  }

  // --- 3. BATTERY MONITOR ---
  Widget _buildBatteryMonitorCard(BatteryTelemetry bat) {
    final bgDrainers = bat.drainers.where((d) => d.isBackgroundDrainer).length;
    return _DashboardCard(
      title: 'Battery Monitor',
      subtitle: '${bat.health} • ~${_fmtDuration(bat.estimatedLeft)} remaining',
      icon: Icons.battery_charging_full_rounded,
      iconColor: AppPalette.emerald,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Row(children: [
            RepaintBoundary(
              child: SizedBox(
                width: 110,
                height: 110,
                child: CustomPaint(
                  painter: BatteryArcGaugePainter(percentage: bat.percentage),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${bat.percentage}%', style: AppStyles.metricLg),
                      Text(bat.isCharging ? 'Charging' : 'Discharging',
                          style: AppStyles.caption),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(children: [
                _KeyValueChip(
                    label: 'Thermal',
                    value: '${bat.temperatureC.toStringAsFixed(1)} °C'),
                const SizedBox(height: 8),
                _KeyValueChip(
                    label: 'Voltage',
                    value: '${bat.voltageV.toStringAsFixed(2)} V'),
                const SizedBox(height: 8),
                _KeyValueChip(
                  label: 'BG Drainers',
                  value: bgDrainers == 0 ? 'Clean' : '$bgDrainers Apps',
                  valueColor:
                      bgDrainers == 0 ? AppPalette.emerald : AppPalette.coral,
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          const Divider(color: AppPalette.border, height: 1),
          const SizedBox(height: 12),
          const Text('Background Apps Draining Battery',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.textSecondary)),
          const SizedBox(height: 9),
          if (bat.drainers.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.emerald.alphaPct(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppPalette.emerald.alphaPct(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.check_circle_rounded,
                    size: 18, color: AppPalette.emerald),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'No abnormal background battery drainers active',
                    style: AppStyles.cardSub,
                  ),
                ),
              ]),
            ),
          ...bat.drainers.map((item) {
            final isBg = item.isBackgroundDrainer;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: isBg
                    ? AppPalette.coral.alphaPct(0.09)
                    : AppPalette.cardAlt.alphaPct(0.55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isBg
                        ? AppPalette.coral.alphaPct(0.35)
                        : AppPalette.border),
              ),
              child: Row(children: [
                Icon(item.icon,
                    size: 18,
                    color: isBg ? AppPalette.coral : AppPalette.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                              child: Text(item.appName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      AppStyles.itemTitle.copyWith(fontSize: 13))),
                          if (isBg) ...[
                            const SizedBox(width: 6),
                            const _StatusBadge(
                                text: 'BG DRAIN', color: AppPalette.coral),
                          ],
                        ]),
                        const SizedBox(height: 2),
                        Text(
                            '${item.mahConsumed} mAh • Wakelock ${item.wakelockMins}m',
                            style: AppStyles.caption),
                      ]),
                ),
                Text('-${item.drainPercent.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color:
                            isBg ? AppPalette.coral : AppPalette.textSecondary)),
              ]),
            );
          }),
        ],
      ),
    );
  }

  // --- 4. SECURITY SCANNER ---
  Widget _buildSecurityScannerCard(SecurityAuditData sec) {
    return _DashboardCard(
      title: 'Security Scanner',
      subtitle: 'Patch ${sec.patchLevel} • ${sec.packagesScanned} APKs scanned',
      icon: Icons.verified_user_rounded,
      iconColor: AppPalette.emerald,
      trailing: OutlinedButton.icon(
        onPressed: _rescanningSecurity ? null : _rescanSecurity,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.emerald,
          side: BorderSide(color: AppPalette.emerald.alphaPct(0.45)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: const Size(0, 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        icon: _rescanningSecurity
            ? const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppPalette.emerald))
            : const Icon(Icons.radar_rounded, size: 15),
        label: Text(_rescanningSecurity ? 'Scanning' : 'Rescan',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppPalette.emerald.alphaPct(0.18),
                AppPalette.cyan.alphaPct(0.06)
              ]),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppPalette.emerald.alphaPct(0.35)),
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: AppPalette.emerald.alphaPct(0.2),
                    shape: BoxShape.circle),
                child: const Icon(Icons.gpp_good_rounded,
                    color: AppPalette.emerald, size: 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sec.statusHeadline,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.emerald)),
                      const SizedBox(height: 2),
                      const Text('Play Integrity & SELinux verified • Zero threats',
                          style: AppStyles.cardSub),
                    ]),
              ),
              Text('${sec.securityScore}/100', style: AppStyles.metricLg),
            ]),
          ),
          const SizedBox(height: 12),
          ...sec.checks.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Icon(
                      c.passed
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      size: 17,
                      color: c.passed ? AppPalette.emerald : AppPalette.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.label,
                              style: AppStyles.itemTitle.copyWith(fontSize: 12.5)),
                          Text(c.detail, style: AppStyles.caption),
                        ]),
                  ),
                ]),
              )),
        ],
      ),
    );
  }

  // --- 5. CALL STATS ---
  Widget _buildCallStatsCard(CallAnalyticsData calls) {
    return _DashboardCard(
      title: 'Call Stats',
      subtitle: 'Recent CallLog.Calls analytics • Last 24h',
      icon: Icons.call_rounded,
      iconColor: AppPalette.blue,
      trailing: Text('${calls.totalCalls} Calls', style: AppStyles.itemTitle),
      child: Column(
        children: [
          const SizedBox(height: 14),
          Row(children: [
            SizedBox(
              width: 102,
              height: 102,
              child: CustomPaint(
                painter: CallBreakdownDonutPainter(
                  incoming: calls.incoming,
                  outgoing: calls.outgoing,
                  missed: calls.missed + calls.rejected,
                ),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_fmtDuration(calls.totalTalkTime),
                        style: AppStyles.itemTitle),
                    const Text('Talk Time', style: AppStyles.caption),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(children: [
                _CallLegendRow(
                    icon: Icons.call_received_rounded,
                    label: 'Incoming',
                    count: calls.incoming,
                    color: AppPalette.emerald),
                const SizedBox(height: 8),
                _CallLegendRow(
                    icon: Icons.call_made_rounded,
                    label: 'Outgoing',
                    count: calls.outgoing,
                    color: AppPalette.cyan),
                const SizedBox(height: 8),
                _CallLegendRow(
                    icon: Icons.call_missed_rounded,
                    label: 'Missed / Declined',
                    count: calls.missed + calls.rejected,
                    color: AppPalette.coral),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
                color: AppPalette.cardAlt.alphaPct(0.6),
                borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    'Avg Call: ${calls.avgDuration.inMinutes}m ${calls.avgDuration.inSeconds % 60}s',
                    style: AppStyles.cardSub),
                Text('Peak: ${calls.peakWindow}',
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.cyan)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDuration(Duration d) => d.inHours > 0
      ? '${d.inHours}h ${d.inMinutes.remainder(60)}m'
      : '${d.inMinutes}m';
}

// ============================================================================
// 5. REUSABLE DARK-MODE UI WIDGETS
// ============================================================================

class _DashboardCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget? trailing;
  final Widget child;

  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.alphaPct(0.28),
              blurRadius: 14,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: iconColor.alphaPct(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 19),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(title, style: AppStyles.cardTitle),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppStyles.cardSub),
                  ]),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ]),
          child,
        ],
      ),
    );
  }
}

class _QuickStatPill extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color accent;

  const _QuickStatPill(
      {required this.label,
      required this.value,
      required this.icon,
      required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
          color: AppPalette.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppPalette.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 17, color: accent),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: AppStyles.itemTitle.copyWith(fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(label, style: AppStyles.caption),
          ),
        ),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.alphaPct(0.16), borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style:
              TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _TrafficStatBox extends StatelessWidget {
  final String title, total, rate;
  final IconData icon;
  final Color color;

  const _TrafficStatBox({
    required this.title,
    required this.total,
    required this.rate,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.cardAlt.alphaPct(0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.alphaPct(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: color))),
        ]),
        const SizedBox(height: 6),
        Text(total,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppPalette.textPrimary)),
        Text('Live: $rate', style: AppStyles.caption),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: AppStyles.caption),
    ]);
  }
}

class _KeyValueChip extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _KeyValueChip(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: AppPalette.cardAlt.alphaPct(0.6),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.cardSub)),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppPalette.textPrimary)),
      ]),
    );
  }
}

class _CallLegendRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _CallLegendRow(
      {required this.icon,
      required this.label,
      required this.count,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
            color: color.alphaPct(0.15),
            borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 15, color: color),
      ),
      const SizedBox(width: 9),
      Expanded(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppStyles.cardSub)),
      Text('$count', style: AppStyles.itemTitle),
    ]);
  }
}

// ============================================================================
// 6. CUSTOM CANVAS DATA CHARTS (ZERO EXTERNAL PACKAGES REQUIRED)
// ============================================================================

class NetworkAreaChartPainter extends CustomPainter {
  final List<double> inbound, outbound;
  NetworkAreaChartPainter({required this.inbound, required this.outbound});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final gridPaint = Paint()
      ..color = AppPalette.border
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final merged = [...inbound, ...outbound];
    if (merged.length < 2) return;
    final peak = merged.isEmpty ? 0.0 : merged.reduce(math.max);
    final maxY = math.max(0.08, peak * 1.25);

    _paintCurve(canvas, size, outbound, maxY, AppPalette.violet);
    _paintCurve(canvas, size, inbound, maxY, AppPalette.cyan);
  }

  void _paintCurve(
      Canvas canvas, Size size, List<double> vals, double maxY, Color color) {
    if (vals.length < 2) return;
    final stepX = size.width / (vals.length - 1);
    final pts = List<Offset>.generate(vals.length, (i) {
      final norm = (vals[i] / maxY).clamp(0.0, 1.0);
      return Offset(i * stepX, size.height - (norm * (size.height - 8)) - 4);
    });

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final midX = (pts[i].dx + pts[i + 1].dx) / 2;
      path.cubicTo(
          midX, pts[i].dy, midX, pts[i + 1].dy, pts[i + 1].dx, pts[i + 1].dy);
    }

    final fill = Path.from(path)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.alphaPct(0.32), color.alphaPct(0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(pts.last, 3.6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant NetworkAreaChartPainter old) =>
      old.inbound != inbound || old.outbound != outbound;
}

class BatteryArcGaugePainter extends CustomPainter {
  final int percentage;
  BatteryArcGaugePainter({required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(
        center: center, radius: (math.min(size.width, size.height) / 2) - 8);
    const startRad = 150 * (math.pi / 180);
    const sweepRad = 240 * (math.pi / 180);

    canvas.drawArc(
      rect,
      startRad,
      sweepRad,
      false,
      Paint()
        ..color = AppPalette.cardAlt
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );

    final endColor = percentage <= 20
        ? AppPalette.coral
        : (percentage <= 40 ? AppPalette.amber : AppPalette.emerald);

    canvas.drawArc(
      rect,
      startRad,
      sweepRad * (percentage / 100.0).clamp(0.0, 1.0),
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: 0.0,
          endAngle: 260 * (math.pi / 180),
          colors: [AppPalette.cyan, endColor],
          transform: const GradientRotation(140 * (math.pi / 180)),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant BatteryArcGaugePainter old) =>
      old.percentage != percentage;
}

class CallBreakdownDonutPainter extends CustomPainter {
  final int incoming, outgoing, missed;
  CallBreakdownDonutPainter(
      {required this.incoming, required this.outgoing, required this.missed});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (math.min(size.width, size.height) / 2) - 7,
    );
    final total = math.max(1, incoming + outgoing + missed);
    final ratios = [incoming / total, outgoing / total, missed / total];
    const colors = [AppPalette.emerald, AppPalette.cyan, AppPalette.coral];

    double angle = -math.pi / 2;
    for (int i = 0; i < 3; i++) {
      if (ratios[i] <= 0) continue;
      final sweep = math.max(0.02, (ratios[i] * 2 * math.pi) - 0.07);
      canvas.drawArc(
        rect,
        angle,
        sweep,
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round,
      );
      angle += ratios[i] * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(covariant CallBreakdownDonutPainter old) =>
      old.incoming != incoming ||
      old.outgoing != outgoing ||
      old.missed != missed;
}
