import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// UNIFIED SYSTEM CONTROL HUB SCREEN (100% ENGLISH • COLLAPSIBLE ACCORDION TREE)
// Main Category Rectangles -> Indented Sub-Rectangles -> Direct & Guided Actions
// ============================================================================

class SystemControlHubScreen extends StatefulWidget {
  const SystemControlHubScreen({super.key});

  @override
  State<SystemControlHubScreen> createState() => _SystemControlHubScreenState();
}

class _SystemControlHubScreenState extends State<SystemControlHubScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _channel =
      MethodChannel('com.syspulse.mobile/telemetry');

  // Palette matching SysPulse Dark Mode & Mockup
  static const Color _bg = Color(0xFF070B14);
  static const Color _card = Color(0xFF111927);
  static const Color _cardAlt = Color(0xFF192338);
  static const Color _subCard = Color(0xFF162032);
  static const Color _border = Color(0xFF24324B);
  static const Color _cyan = Color(0xFF00E5FF);
  static const Color _violet = Color(0xFF8B5CF6);
  static const Color _emerald = Color(0xFF10B981);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _coral = Color(0xFFF43F5E);
  static const Color _blue = Color(0xFF3B82F6);
  static const Color _textPrimary = Color(0xFFF8FAFC);
  static const Color _textSecondary = Color(0xFF94A3B8);

  bool _loading = true;
  String _searchQuery = '';

  // Which Main Category Rectangles are expanded
  final Set<String> _expandedGroups = <String>{
    'direct_controls',
  };

  // Which Sub-Rectangles are expanded to show their step-by-step guide
  final Set<String> _expandedItems = <String>{
    'screen_lock',
    'dev_options',
  };

  // Live hardware & OS state
  bool _isTorchOn = false;
  String _ringerMode = 'normal';
  int _mediaVolumePct = 60;
  int _ringVolumePct = 70;
  int _brightnessPct = 55;
  bool _autoBrightness = true;
  int _screenTimeoutSec = 60;
  bool _adbEnabled = false;
  bool _devOptionsEnabled = false;
  bool _autoTimeEnabled = true;
  bool _autoTimeZoneEnabled = true;
  bool _isDeviceSecure = true;
  bool _wifiEnabled = true;
  bool _bluetoothEnabled = false;
  bool _nfcEnabled = false;
  bool _batterySaverOn = false;
  bool _canWriteSettings = false;
  bool _dndPolicyGranted = false;
  String _deviceBrand = 'Android Device';
  String _androidVersion = 'Android 14';
  int _batteryPct = 78;
  bool _isCharging = false;
  String _batteryHealth = 'Good';
  int _batteryHealthScore = 96;
  double _batteryTempC = 33.0;
  double _batteryWatts = 1.4;
  int _batteryCurrentMa = 320;
  String _chargingSource = 'On Battery';
  String _thermalStatus = 'Cool & Optimal';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshHubState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshHubState();
    }
  }

  Future<void> _refreshHubState() async {
    try {
      final res = await _channel
          .invokeMapMethod<String, dynamic>('getSystemControlHubState');
      if (res != null && mounted) {
        setState(() {
          _isTorchOn = res['isTorchOn'] == true;
          _ringerMode = (res['ringerMode'] as String?) ?? 'normal';
          _mediaVolumePct = (res['mediaVolumePct'] as num?)?.toInt() ?? 60;
          _ringVolumePct = (res['ringVolumePct'] as num?)?.toInt() ?? 70;
          _brightnessPct = (res['brightnessPct'] as num?)?.toInt() ?? 55;
          _autoBrightness = res['autoBrightness'] != false;
          _screenTimeoutSec = (res['screenTimeoutSec'] as num?)?.toInt() ?? 60;
          _adbEnabled = res['adbEnabled'] == true;
          _devOptionsEnabled = res['devOptionsEnabled'] == true;
          _autoTimeEnabled = res['autoTimeEnabled'] != false;
          _autoTimeZoneEnabled = res['autoTimeZoneEnabled'] != false;
          _isDeviceSecure = res['isDeviceSecure'] != false;
          _wifiEnabled = res['wifiEnabled'] != false;
          _bluetoothEnabled = res['bluetoothEnabled'] == true;
          _nfcEnabled = res['nfcEnabled'] == true;
          _batterySaverOn = res['batterySaverOn'] == true;
          _canWriteSettings = res['canWriteSettings'] == true;
          _dndPolicyGranted = res['dndPolicyGranted'] == true;
          _deviceBrand = (res['deviceBrand'] as String?) ?? 'Android Device';
          _androidVersion = (res['androidVersion'] as String?) ?? 'Android';
          _batteryPct = (res['batteryPct'] as num?)?.toInt() ?? 78;
          _isCharging = res['isCharging'] == true;
          _batteryHealth = (res['batteryHealth'] as String?) ?? 'Good';
          _batteryHealthScore =
              (res['batteryHealthScore'] as num?)?.toInt() ?? 96;
          _batteryTempC = (res['batteryTempC'] as num?)?.toDouble() ?? 33.0;
          _batteryWatts =
              (res['batteryPowerWatts'] as num?)?.toDouble() ?? 1.4;
          _batteryCurrentMa =
              (res['batteryCurrentMa'] as num?)?.toInt() ?? 320;
          _chargingSource =
              (res['chargingSource'] as String?) ?? 'On Battery';
          _thermalStatus =
              (res['thermalStatus'] as String?) ?? 'Cool & Optimal';
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _runDirectControl(String action, [dynamic value]) async {
    HapticFeedback.lightImpact();
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'executeDirectSystemControl',
        {'action': action, 'value': value},
      );
      if (res != null && mounted) {
        final msg = (res['message'] as String?) ?? 'Action applied';
        final ok = res['ok'] == true;
        final needsWritePerm = res['requiresWritePermission'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor:
                ok ? const Color(0xFF065F46) : const Color(0xFF92400E),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: needsWritePerm ? 4 : 3),
            action: needsWritePerm
                ? SnackBarAction(
                    label: 'Allow Dimming',
                    textColor: _cyan,
                    onPressed: () => _openSettingTarget(
                        'write_settings_permission', 'Modify System Settings'),
                  )
                : null,
          ),
        );
      }
    } catch (_) {}
    await _refreshHubState();
  }

  Future<void> _openSettingTarget(String targetKey, String title) async {
    HapticFeedback.selectionClick();
    try {
      await _channel.invokeMethod<bool>(
        'openSystemSettingTarget',
        {'targetKey': targetKey},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opened: $title — Follow SysPulse step-by-step guide'),
            backgroundColor: _cardAlt,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  List<_HubGroupMeta> get _groups => const [
        _HubGroupMeta(
          id: 'direct_controls',
          numberTag: '01',
          title: 'Direct In-App Controls',
          badgeSuffix: 'CONTROLS',
          icon: Icons.flash_on_rounded,
          color: _cyan,
        ),
        _HubGroupMeta(
          id: 'security',
          numberTag: '02',
          title: 'Security, Passwords & Biometrics',
          badgeSuffix: 'SETTINGS',
          icon: Icons.security_rounded,
          color: _coral,
        ),
        _HubGroupMeta(
          id: 'audio',
          numberTag: '03',
          title: 'Audio, Ringer & Notifications',
          badgeSuffix: 'SETTINGS',
          icon: Icons.volume_up_rounded,
          color: _emerald,
        ),
        _HubGroupMeta(
          id: 'display',
          numberTag: '04',
          title: 'Display, Wallpaper & Eye Comfort',
          badgeSuffix: 'SETTINGS',
          icon: Icons.wb_sunny_rounded,
          color: _amber,
        ),
        _HubGroupMeta(
          id: 'network',
          numberTag: '05',
          title: 'Network, Wi-Fi, Hotspot & NFC',
          badgeSuffix: 'SETTINGS',
          icon: Icons.wifi_rounded,
          color: _blue,
        ),
        _HubGroupMeta(
          id: 'battery',
          numberTag: '06',
          title: 'Battery Saver & Honor App Launch',
          badgeSuffix: 'SETTINGS',
          icon: Icons.bolt_rounded,
          color: _emerald,
        ),
        _HubGroupMeta(
          id: 'developer',
          numberTag: '07',
          title: 'Developer Options & USB Debugging',
          badgeSuffix: 'SETTINGS',
          icon: Icons.terminal_rounded,
          color: _violet,
        ),
        _HubGroupMeta(
          id: 'regional',
          numberTag: '08',
          title: 'Date, Time, Language & Keyboard',
          badgeSuffix: 'SETTINGS',
          icon: Icons.schedule_rounded,
          color: _cyan,
        ),
        _HubGroupMeta(
          id: 'apps',
          numberTag: '09',
          title: 'Installed Apps, Cache & Default Apps',
          badgeSuffix: 'SETTINGS',
          icon: Icons.admin_panel_settings_rounded,
          color: _amber,
        ),
        _HubGroupMeta(
          id: 'accessibility',
          numberTag: '10',
          title: 'Accessibility & System Storage',
          badgeSuffix: 'SETTINGS',
          icon: Icons.accessibility_new_rounded,
          color: _blue,
        ),
      ];

  List<_SystemControlItem> _buildAllControlItems() {
    final timeoutLabel = _screenTimeoutSec >= 60
        ? '${_screenTimeoutSec ~/ 60}m'
        : '${_screenTimeoutSec}s';
    final ringerLabel = _ringerMode == 'silent'
        ? 'Silent'
        : (_ringerMode == 'vibrate' ? 'Vibrate' : 'Normal');

    return [
      // ==================== 02. SECURITY & PASSWORDS ====================
      _SystemControlItem(
        id: 'screen_lock',
        category: 'security',
        title: 'Screen Lock Password, PIN & Pattern',
        categoryTag: 'Device Lock',
        subtitle:
            'Set or update your device passcode, 6-digit PIN, or pattern lock.',
        icon: Icons.lock_rounded,
        color: _isDeviceSecure ? _emerald : _coral,
        statusLabel: _isDeviceSecure ? 'SECURED' : 'UNSECURED',
        isStatusHealthy: _isDeviceSecure,
        supportsDirectAction: false,
        targetKey: 'screen_lock',
        recommendation:
            'Use a 6-digit PIN or alphanumeric password; an active screen lock enables hardware file encryption.',
        steps: const [
          'Tap "Open Setting Screen" below to jump directly to the Screen Lock setup screen.',
          'Enter your current PIN/Pattern (if set), then select PIN, Password, or Pattern.',
          'Enter your new passcode twice to confirm and tap "Done".',
        ],
      ),
      _SystemControlItem(
        id: 'biometrics_fingerprint',
        category: 'security',
        title: 'Fingerprint & Face Unlock Biometrics',
        categoryTag: 'Biometric Auth',
        subtitle:
            'Enroll fingerprints or face recognition for fast unlocking and banking apps.',
        icon: Icons.fingerprint_rounded,
        color: _cyan,
        statusLabel: _isDeviceSecure ? 'Ready' : 'Needs PIN',
        isStatusHealthy: _isDeviceSecure,
        supportsDirectAction: false,
        targetKey: 'biometric_enroll',
        recommendation:
            'Register both thumbs and index fingers for effortless unlocking in any hand position.',
        steps: const [
          'Tap "Open Setting Screen" below to open Biometrics & Fingerprint enrollment.',
          'Select "Fingerprint Management" and verify your screen lock PIN.',
          'Tap "New Fingerprint" and place your finger on the sensor repeatedly until 100% scanned.',
        ],
      ),
      _SystemControlItem(
        id: 'privacy_location',
        category: 'security',
        title: 'Privacy Dashboard & GPS Location',
        categoryTag: 'Location & Sensors',
        subtitle:
            'Audit apps accessing GPS location, camera, and microphone in the background.',
        icon: Icons.location_on_rounded,
        color: _amber,
        statusLabel: 'Active',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'location_settings',
        recommendation:
            'Set location permission to "Allow only while using the app" to block background tracking.',
        steps: const [
          'Tap "Open Setting Screen" below to open Location Services.',
          'Review the "Recent location requests" list.',
          'Tap any unfamiliar app -> "Permissions" -> "Location" -> select "While using the app" or "Don\'t allow".',
        ],
      ),
      _SystemControlItem(
        id: 'security_center',
        category: 'security',
        title: 'System Security, Play Protect & Find Device',
        categoryTag: 'OS Integrity',
        subtitle:
            'Verify Google Play Protect malware scan, SIM PIN lock, and remote Find My Device.',
        icon: Icons.shield_rounded,
        color: _emerald,
        statusLabel: 'Protected',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'security_settings',
        recommendation:
            'Ensure "Find My Device" is ON so you can locate, lock, or wipe your phone remotely if lost.',
        steps: const [
          'Tap "Open Setting Screen" below to open the Android Security Center.',
          'Tap "Google Play Protect" and verify app scanning is active.',
          'Tap "Find My Device" and confirm remote location tracking is enabled.',
        ],
      ),

      // ==================== 03. AUDIO & SOUND ====================
      _SystemControlItem(
        id: 'ringer_volume',
        category: 'audio',
        title: 'Ringer Mode, Ringtones & Volume',
        categoryTag: 'Audio & Haptics',
        subtitle:
            'Switch between Normal, Vibrate, and Silent modes or customize phone ringtones.',
        icon: Icons.notifications_active_rounded,
        color: _emerald,
        statusLabel: '$ringerLabel • $_mediaVolumePct%',
        isStatusHealthy: true,
        supportsDirectAction: true,
        targetKey: 'sound_settings',
        recommendation:
            'Use Vibrate mode during meetings and keep media volume between 50%-75% to protect hearing and save battery.',
        steps: const [
          'Use the 1-click buttons right inside this sub-rectangle to switch Ringer Mode or Volume immediately.',
          'To customize ringtones or notification sounds, tap "Open Setting Screen" below.',
          'Select "Phone Ringtone (SIM 1 / SIM 2)" and pick your preferred tone.',
        ],
      ),
      _SystemControlItem(
        id: 'dnd_mode',
        category: 'audio',
        title: 'Do Not Disturb (DND) & Sleep Schedule',
        categoryTag: 'Focus & Sleep',
        subtitle:
            'Silence unwanted interruptions at night while allowing calls from starred contacts.',
        icon: Icons.do_not_disturb_on_rounded,
        color: _violet,
        statusLabel: _dndPolicyGranted ? 'Granted' : 'Standard',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'dnd_settings',
        recommendation:
            'Schedule automatic Do Not Disturb from 11:00 PM to 6:00 AM and allow Favorite Contacts only.',
        steps: const [
          'Tap "Open Setting Screen" below to jump directly to Do Not Disturb configuration.',
          'Tap "Schedules" and enable a Sleeping schedule (e.g., 23:00 to 06:00).',
          'Tap "Calls & Messages" and choose "Favorite contacts only".',
        ],
      ),
      _SystemControlItem(
        id: 'app_notifications',
        category: 'audio',
        title: 'App Notifications & Status Bar Banners',
        categoryTag: 'Notification Control',
        subtitle:
            'Block spammy promotional notifications from games and shopping apps.',
        icon: Icons.mark_chat_unread_rounded,
        color: _cyan,
        statusLabel: 'Manager',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'notification_settings',
        recommendation:
            'Muting non-essential app notifications prevents screen wake-ups and saves up to 8% battery daily.',
        steps: const [
          'Tap "Open Setting Screen" below to view all apps notification permissions.',
          'Sort the list by "Most Recent" or "Most Frequent" to spot noisy apps.',
          'Toggle off the switch next to any app you do not need alerts from.',
        ],
      ),

      // ==================== 04. DISPLAY & WALLPAPER ====================
      _SystemControlItem(
        id: 'brightness_timeout',
        category: 'display',
        title: 'Screen Brightness & Auto-Lock Timeout',
        categoryTag: 'Display & Power',
        subtitle:
            'Directly adjust screen brightness level and sleep timeout to prevent battery drain.',
        icon: Icons.wb_sunny_rounded,
        color: _amber,
        statusLabel:
            '${_autoBrightness ? "Auto" : "$_brightnessPct%"} • $timeoutLabel',
        isStatusHealthy: _screenTimeoutSec <= 120,
        supportsDirectAction: true,
        targetKey: 'display_settings',
        recommendation:
            'Adaptive brightness and a 30s–1m screen timeout prevent OLED burn-in and save up to 20% battery.',
        steps: const [
          'Use the 1-click preset chips inside this sub-rectangle to set Screen Timeout immediately.',
          'If prompted on first use, toggle ON "Allow modify system settings" for SysPulse and return.',
          'Or tap "Open Setting Screen" to adjust Font Size and Screen Refresh Rate (120Hz / Dynamic).',
        ],
      ),
      _SystemControlItem(
        id: 'wallpaper',
        category: 'display',
        title: 'Wallpaper, Lock Screen & Themes',
        categoryTag: 'Personalization',
        subtitle:
            'Change your Home screen and Lock screen wallpaper in one tap.',
        icon: Icons.wallpaper_rounded,
        color: _violet,
        statusLabel: 'Personalize',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'wallpaper_settings',
        recommendation:
            'Using dark AMOLED wallpapers turns off black pixels completely and reduces display power usage.',
        steps: const [
          'Tap "Open Setting Screen" below to launch the system Wallpaper chooser.',
          'Pick an image from your Gallery or System Wallpapers.',
          'Tap "Apply / Set Wallpaper" and choose Home Screen, Lock Screen, or Both.',
        ],
      ),
      _SystemControlItem(
        id: 'eye_comfort_night',
        category: 'display',
        title: 'Eye Comfort Shield & Dark Mode',
        categoryTag: 'Visual Health',
        subtitle:
            'Filter blue light at night to reduce eye strain and configure system Dark Mode.',
        icon: Icons.nightlight_round,
        color: _blue,
        statusLabel: 'Eye Shield',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'night_display_settings',
        recommendation:
            'Schedule Eye Comfort from Sunset to Sunrise to protect melatonin and improve sleep quality.',
        steps: const [
          'Tap "Open Setting Screen" below to open Eye Comfort / Night Display settings.',
          'Enable "Eye Comfort / Blue Light Filter" or set schedule to "Sunset to Sunrise".',
          'Adjust the color temperature slider toward Warm for comfortable night reading.',
        ],
      ),
      _SystemControlItem(
        id: 'torch_flashlight',
        category: 'display',
        title: 'Instant Hardware Flashlight (Torch)',
        categoryTag: 'Hardware Utility',
        subtitle:
            'Toggle the rear camera LED flashlight directly without opening the Camera app.',
        icon: Icons.flashlight_on_rounded,
        color: _isTorchOn ? _amber : _cyan,
        statusLabel: _isTorchOn ? 'ON' : 'OFF',
        isStatusHealthy: true,
        supportsDirectAction: true,
        targetKey: 'display_settings',
        recommendation:
            'Direct hardware torch control uses minimal power by bypassing the camera sensor pipeline.',
        steps: const [
          'Tap the "Toggle Flashlight" button inside this sub-rectangle or in Group 01 for instant lighting.',
        ],
      ),

      // ==================== 05. CONNECTIVITY & NETWORK ====================
      _SystemControlItem(
        id: 'wifi_networks',
        category: 'network',
        title: 'Wi-Fi Networks & QR Password Share',
        categoryTag: 'Wireless LAN',
        subtitle:
            'Connect to Wi-Fi networks, share Wi-Fi via QR code, or configure static IP/DNS.',
        icon: Icons.wifi_rounded,
        color: _wifiEnabled ? _emerald : _textSecondary,
        statusLabel: _wifiEnabled ? 'Wi-Fi ON' : 'Wi-Fi OFF',
        isStatusHealthy: _wifiEnabled,
        supportsDirectAction: false,
        targetKey: 'wifi_settings',
        recommendation:
            'Disable "Notify for public networks" to prevent auto-connecting to insecure open Wi-Fi hotspots.',
        steps: const [
          'Tap "Open Setting Screen" below to open Wi-Fi networks.',
          'To share your current Wi-Fi password, tap the connected network name to display its QR code.',
          'To remove an old network, long-press its name and select "Forget network".',
        ],
      ),
      _SystemControlItem(
        id: 'bluetooth_devices',
        category: 'network',
        title: 'Bluetooth Audio, Watch & Paired Devices',
        categoryTag: 'Short-Range Radio',
        subtitle:
            'Pair wireless earbuds, smartwatches, and car audio systems.',
        icon: Icons.bluetooth_rounded,
        color: _bluetoothEnabled ? _blue : _textSecondary,
        statusLabel: _bluetoothEnabled ? 'Active' : 'OFF',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'bluetooth_settings',
        recommendation:
            'Turn off Bluetooth when not using wireless accessories to save battery and prevent BlueBorne probes.',
        steps: const [
          'Tap "Open Setting Screen" below to open Bluetooth settings.',
          'Toggle Bluetooth ON and wait for your accessory to appear under "Available devices".',
          'Tap the device name and confirm the "Pair" prompt.',
        ],
      ),
      _SystemControlItem(
        id: 'hotspot_tethering',
        category: 'network',
        title: 'Personal Wi-Fi Hotspot & Tethering',
        categoryTag: 'Internet Sharing',
        subtitle:
            'Share your mobile data connection with laptops or other phones and set hotspot password.',
        icon: Icons.wifi_tethering_rounded,
        color: _cyan,
        statusLabel: 'Hotspot',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'hotspot_settings',
        recommendation:
            'Set a "One-time data limit" (e.g., 500 MB) and enable "Turn off hotspot automatically" when idle.',
        steps: const [
          'Tap "Open Setting Screen" below to open Tethering & Personal Hotspot.',
          'Tap "Personal Hotspot" and select "Configure Hotspot" to set a strong WPA2/WPA3 password.',
          'Toggle the Hotspot switch ON when you need to share internet.',
        ],
      ),
      _SystemControlItem(
        id: 'sim_mobile_data',
        category: 'network',
        title: 'SIM Cards, 5G/4G Network & Data Roaming',
        categoryTag: 'Cellular Radio',
        subtitle:
            'Choose default SIM for calls/data, toggle 5G/LTE mode, and enable Wi-Fi Calling.',
        icon: Icons.sim_card_rounded,
        color: _violet,
        statusLabel: 'SIM Config',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'data_roaming_sim',
        recommendation:
            'If 5G signal is weak in your area and drains battery, switch Preferred Network Mode to 4G/LTE Auto.',
        steps: const [
          'Tap "Open Setting Screen" below to open SIM & Mobile Network settings.',
          'Select your preferred SIM card for Mobile Data and Default Calling.',
          'Tap "Preferred network type" or "Wi-Fi Calling" to optimize voice and data reception.',
        ],
      ),
      _SystemControlItem(
        id: 'nfc_vpn_dns',
        category: 'network',
        title: 'NFC Contactless Pay, VPN & Private DNS',
        categoryTag: 'Payment & DNS',
        subtitle:
            'Enable NFC tap-to-pay (Google Pay / Bank cards) and configure Private Ad-Blocker DNS.',
        icon: Icons.contactless_rounded,
        color: _nfcEnabled ? _emerald : _amber,
        statusLabel: _nfcEnabled ? 'NFC ON' : 'NFC OFF',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'nfc_settings',
        recommendation:
            'To block ads and malware system-wide for free, set Private DNS to: dns.adguard-dns.com.',
        steps: const [
          'Tap "Open Setting Screen" below to open NFC & More Connections.',
          'Toggle NFC ON to pay at contactless terminals with your phone.',
          'For Private DNS: go to "More connections" -> "Private DNS" -> enter dns.adguard-dns.com.',
        ],
      ),

      // ==================== 06. BATTERY & PERFORMANCE ====================
      _SystemControlItem(
        id: 'battery_health_booster',
        category: 'battery',
        title: 'Battery Health & Safe Charge Booster',
        categoryTag: 'Health & Fast Charge',
        subtitle:
            'Inspect live battery cell health ($_batteryHealth • $_batteryHealthScore%), wattage (${_batteryWatts.toStringAsFixed(1)}W), and boost charging speed safely without overheating.',
        icon: Icons.bolt_rounded,
        color: _batteryTempC >= 40.5 ? _coral : _emerald,
        statusLabel:
            '$_batteryHealthScore% • ${_batteryWatts.toStringAsFixed(1)}W',
        isStatusHealthy: _batteryHealthScore >= 75 && _batteryTempC < 41.0,
        supportsDirectAction: true,
        targetKey: 'power_usage_summary',
        recommendation:
            'Fast chargers throttle wattage by up to 50% above 40°C. Safe Charge Booster cools the CPU & dims the screen so your charger delivers peak native speed with zero battery wear.',
        steps: const [
          'Plug in an official AC fast charger (avoid slow laptop USB ports).',
          'Tap "Activate Safe Charge Booster" right inside this sub-rectangle to trim background CPU load, mute loud ringer spikes, and dim display to 15% / 30s sleep.',
          'Tap "Open Setting Screen" below to inspect native OS Power Usage details.',
        ],
      ),
      _SystemControlItem(
        id: 'honor_launch',
        category: 'battery',
        title: 'Honor App Launch & Background Freeze',
        categoryTag: 'OEM Power Control',
        subtitle:
            'Prevent stubborn apps from auto-restarting in the background (Android Recent Apps square button only shows OS task history snapshots, not live RAM).',
        icon: Icons.rocket_launch_rounded,
        color: _coral,
        statusLabel: 'OEM Rules',
        isStatusHealthy: true,
        supportsDirectAction: true,
        targetKey: 'honor_app_launch',
        recommendation:
            'On Honor / MagicOS, disabling "Manage Automatically" for heavy social apps stops auto-restarts permanently.',
        steps: const [
          'Tap "Trim Cached System RAM" inside this sub-rectangle to release cached memory safely.',
          'Then tap "Open Setting Screen" below to launch Honor App Launch / Battery Optimization.',
          'Turn OFF "Manage Automatically" for draining apps, and uncheck "Auto-launch" and "Run in background".',
        ],
      ),
      _SystemControlItem(
        id: 'battery_saver_health',
        category: 'battery',
        title: 'Battery Saver, Smart Charge & Capacity',
        categoryTag: 'Battery Longevity',
        subtitle:
            'Enable Power Saving mode and Smart Battery Capacity to extend battery lifespan.',
        icon: Icons.battery_charging_full_rounded,
        color: _batterySaverOn ? _amber : _emerald,
        statusLabel: _batterySaverOn ? 'Saver ON' : 'Balanced',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'battery_saver',
        recommendation:
            'Enable "Smart Charge" and "Smart Battery Capacity" to pause trickle charging at 80%-90% overnight.',
        steps: const [
          'Tap "Open Setting Screen" below to open Battery & Power Saving settings.',
          'Toggle ON "Power Saving Mode" when battery drops below 30%.',
          'Tap "More battery settings" and enable "Smart Charge" & "Smart Battery Capacity".',
        ],
      ),

      // ==================== 07. DEVELOPER OPTIONS & SYSTEM ====================
      _SystemControlItem(
        id: 'dev_options',
        category: 'developer',
        title: 'Developer Options & USB Debugging',
        categoryTag: 'Advanced System',
        subtitle:
            'Access hidden programmer settings, speed up UI animations, and secure USB Debugging.',
        icon: Icons.developer_mode_rounded,
        color: _adbEnabled ? _coral : _violet,
        statusLabel: !_devOptionsEnabled
            ? 'Hidden'
            : (_adbEnabled ? 'USB Debug ON' : 'Safe'),
        isStatusHealthy: !_adbEnabled,
        supportsDirectAction: false,
        targetKey:
            _devOptionsEnabled ? 'developer_options' : 'device_info_build',
        recommendation: _adbEnabled
            ? '⚠️ SECURITY ALERT: USB Debugging is currently ON! Turn it OFF when not actively coding to prevent juice-jacking via public chargers.'
            : '💡 SPEED TIP: Inside Developer Options, set Window, Transition, and Animator scales from 1x to 0.5x to make your phone feel twice as fast!',
        steps: _devOptionsEnabled
            ? const [
                'Tap "Open Setting Screen" below to jump straight into Developer Options.',
                'For Security: scroll to "USB Debugging" and toggle it OFF if you are not connected to a PC.',
                'For Speed: scroll to the "Drawing" section and set all 3 Animation Scale options to "0.5x".',
              ]
            : const [
                'Developer Options are currently hidden on your phone. Tap "Open Setting Screen" below to open "About Phone".',
                'Find "Build Number" and tap it rapidly 7 times in a row.',
                'Enter your lock screen PIN when prompted — you will see "You are now a developer!". Return here to open it directly.',
              ],
      ),
      _SystemControlItem(
        id: 'about_device_update',
        category: 'developer',
        title: 'About Phone, Hardware Specs & Build Info',
        categoryTag: 'Device Identity',
        subtitle:
            'Inspect CPU model, RAM capacity, MagicOS / Android version, and security patch level.',
        icon: Icons.phone_android_rounded,
        color: _cyan,
        statusLabel: _androidVersion,
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'device_info_build',
        recommendation:
            'Keep your Android Security Patch level up to date to protect against kernel vulnerabilities.',
        steps: const [
          'Tap "Open Setting Screen" below to view full device specifications.',
          'Review Model Number, RAM, Processor, Android Version, and IMEI details.',
        ],
      ),

      // ==================== 08. DATE, TIME, LANGUAGE & INPUT ====================
      _SystemControlItem(
        id: 'date_time',
        category: 'regional',
        title: 'Date, Time & Time Zone Configuration',
        categoryTag: 'Clock & Sync',
        subtitle:
            'Configure automatic network time synchronization and 12-hour / 24-hour clock format.',
        icon: Icons.schedule_rounded,
        color: (_autoTimeEnabled && _autoTimeZoneEnabled) ? _emerald : _amber,
        statusLabel: (_autoTimeEnabled && _autoTimeZoneEnabled)
            ? 'Auto Sync'
            : 'Manual',
        isStatusHealthy: _autoTimeEnabled && _autoTimeZoneEnabled,
        supportsDirectAction: false,
        targetKey: 'date_time_settings',
        recommendation:
            'Keep "Set time automatically" ON so banking apps, HTTPS SSL certificates, and WhatsApp never fail.',
        steps: const [
          'Tap "Open Setting Screen" below to open Date & Time settings.',
          'Enable "Set time automatically" and "Set time zone automatically".',
          'Toggle "Use 24-hour format" on or off according to your preference.',
        ],
      ),
      _SystemControlItem(
        id: 'language_region',
        category: 'regional',
        title: 'System Language & Regional Format',
        categoryTag: 'Localization',
        subtitle:
            'Add languages, switch system language, and configure region/number formatting.',
        icon: Icons.translate_rounded,
        color: _blue,
        statusLabel: 'Languages',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'locale_language',
        recommendation:
            'You can keep multiple languages in your list and drag your preferred language to position #1 anytime.',
        steps: const [
          'Tap "Open Setting Screen" below to open System Language & Region.',
          'Tap "Add a language" if your target language is not listed.',
          'Drag your preferred language to the top of the list to apply it immediately.',
        ],
      ),
      _SystemControlItem(
        id: 'keyboard_input',
        category: 'regional',
        title: 'On-Screen Keyboard, Clipboard & Auto-Correct',
        categoryTag: 'Text Input',
        subtitle:
            'Customize keyboard height, number row, clipboard history, and spell check.',
        icon: Icons.keyboard_alt_rounded,
        color: _violet,
        statusLabel: 'Keyboard',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'keyboard_input',
        recommendation:
            'Enable the dedicated "Number Row" and "Clipboard History" in Gboard / SwiftKey preferences for faster typing.',
        steps: const [
          'Tap "Open Setting Screen" below to open Keyboard & Input Method settings.',
          'Select your active keyboard (e.g., Gboard or Microsoft SwiftKey).',
          'Open "Preferences" to enable the top Number Row or adjust vibration on keypress.',
        ],
      ),

      // ==================== 09. APPS & PERMISSIONS ====================
      _SystemControlItem(
        id: 'manage_all_apps',
        category: 'apps',
        title: 'Installed Apps Manager & Cache Cleaner',
        categoryTag: 'App Management',
        subtitle:
            'Browse all installed apps, clear bloated app caches, or Force Stop misbehaving apps.',
        icon: Icons.apps_outage_rounded,
        color: _amber,
        statusLabel: 'All Apps',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'manage_all_apps',
        recommendation:
            'If an app freezes or lags, open its Storage page and tap "Clear Cache" (safe, keeps your login data).',
        steps: const [
          'Tap "Open Setting Screen" below to open the full Installed Applications list.',
          'Search for the target app and tap its name.',
          'Tap "Storage" -> "Clear Cache" to free space, or tap "Force Stop" to terminate it.',
        ],
      ),
      _SystemControlItem(
        id: 'default_apps',
        category: 'apps',
        title: 'Default Browser, Phone Dialer & SMS Apps',
        categoryTag: 'Default Handlers',
        subtitle:
            'Choose which app opens web links, phone calls, SMS messages, and PDFs by default.',
        icon: Icons.verified_user_rounded,
        color: _cyan,
        statusLabel: 'Defaults',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'default_apps',
        recommendation:
            'If a newly installed app hijacked your browser or dialer, reset your default apps here in seconds.',
        steps: const [
          'Tap "Open Setting Screen" below to open Default Apps configuration.',
          'Tap the category you want to change (Browser app, Phone app, SMS app, or Home app).',
          'Select your preferred trusted application.',
        ],
      ),
      _SystemControlItem(
        id: 'special_overlay_permissions',
        category: 'apps',
        title: 'Display Over Other Apps & Floating Popups',
        categoryTag: 'Special Access',
        subtitle:
            'Stop intrusive apps from drawing floating windows or popup ads over your screen.',
        icon: Icons.layers_rounded,
        color: _coral,
        statusLabel: 'Overlay Guard',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'overlay_permission',
        recommendation:
            'Revoke "Display over other apps" permission from any unknown utility or game to block full-screen ad popups.',
        steps: const [
          'Tap "Open Setting Screen" below to list apps with "Display over other apps" access.',
          'Review apps marked as "Allowed".',
          'Tap any suspicious or non-essential app and toggle "Allow display over other apps" OFF.',
        ],
      ),

      // ==================== 10. ACCESSIBILITY & STORAGE ====================
      _SystemControlItem(
        id: 'accessibility_tools',
        category: 'accessibility',
        title: 'Accessibility, Screen Magnification & Shortcuts',
        categoryTag: 'Ease of Use',
        subtitle:
            'Configure screen zoom, high-contrast text, one-handed mode, and installed accessibility services.',
        icon: Icons.accessibility_new_rounded,
        color: _blue,
        statusLabel: 'Ease of Use',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'accessibility_settings',
        recommendation:
            'Never grant Accessibility permission to untrusted APK apps, as it allows reading screen content.',
        steps: const [
          'Tap "Open Setting Screen" below to open Accessibility settings.',
          'Check "Downloaded / Installed Services" and ensure only trusted apps are enabled.',
          'Enable "Magnification" or "One-Handed Mode" for easier navigation.',
        ],
      ),
      _SystemControlItem(
        id: 'internal_storage_system',
        category: 'accessibility',
        title: 'System Storage Breakdown & OS Cleaner',
        categoryTag: 'Storage Health',
        subtitle:
            'Inspect storage usage across System, Apps, Videos, Images, and temporary trash.',
        icon: Icons.storage_rounded,
        color: _emerald,
        statusLabel: 'Storage',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'internal_storage',
        recommendation:
            'Keeping at least 15% of internal storage free maintains peak UFS flash read/write speeds.',
        steps: const [
          'Tap "Open Setting Screen" below to open native Storage settings.',
          'Wait a moment for category sizes to calculate.',
          'Tap "Clean Up" to purge residual cache files and empty the trash bin.',
        ],
      ),
    ];
  }

  bool _matchesDirectControls(String q) {
    if (q.isEmpty) return true;
    const keywords =
        'direct in-app controls flashlight torch ringer audio silent vibrate normal brightness timeout sleep ram memory boost clean safe charge booster fast charging battery watt thermal cool';
    return keywords.contains(q);
  }

  bool _itemMatchesSearch(_SystemControlItem item, String q) {
    if (q.isEmpty) return true;
    return item.title.toLowerCase().contains(q) ||
        item.categoryTag.toLowerCase().contains(q) ||
        item.subtitle.toLowerCase().contains(q) ||
        item.recommendation.toLowerCase().contains(q) ||
        item.statusLabel.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final allItems = _buildAllControlItems();
    final q = _searchQuery.toLowerCase();
    final media = MediaQuery.of(context);
    final clampedMedia = media.copyWith(
      textScaler: media.textScaler.clamp(
        minScaleFactor: 0.85,
        maxScaleFactor: 1.05,
      ),
    );

    return MediaQuery(
      data: clampedMedia,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          titleSpacing: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_cyan, _violet]),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.tune_rounded,
                    color: Colors.white, size: 17),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'System Control Hub',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      _deviceBrand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh Live States',
              onPressed: _refreshHubState,
              icon: const Icon(Icons.refresh_rounded, color: _cyan, size: 20),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _cyan))
            : RefreshIndicator(
                color: _cyan,
                backgroundColor: _cardAlt,
                onRefresh: _refreshHubState,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(13, 6, 13, 36),
                  children: [
                    // Search Bar + Expand/Collapse All Row
                    Row(
                      children: [
                        Expanded(child: _buildSearchBar()),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(11),
                          onTap: () {
                            setState(() {
                              if (_expandedGroups.length >= _groups.length) {
                                _expandedGroups.clear();
                              } else {
                                for (final g in _groups) {
                                  _expandedGroups.add(g.id);
                                }
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                  color: _cyan.withOpacity(0.45)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _expandedGroups.length >= _groups.length
                                      ? Icons.unfold_less_rounded
                                      : Icons.unfold_more_rounded,
                                  size: 15,
                                  color: _cyan,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _expandedGroups.length >= _groups.length
                                      ? 'Collapse'
                                      : 'Expand All',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: _cyan,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 10 Collapsible Main Category Rectangles
                    ..._groups.map((grp) {
                      if (grp.id == 'direct_controls') {
                        if (!_matchesDirectControls(q)) {
                          return const SizedBox.shrink();
                        }
                        final isExpanded =
                            q.isNotEmpty || _expandedGroups.contains(grp.id);
                        return _buildDirectControlsAccordionGroup(
                          grp,
                          isExpanded: isExpanded,
                        );
                      } else {
                        final grpItems = allItems
                            .where((i) =>
                                i.category == grp.id && _itemMatchesSearch(i, q))
                            .toList();
                        if (grpItems.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final isExpanded =
                            q.isNotEmpty || _expandedGroups.contains(grp.id);
                        return _buildCategoryAccordionGroup(
                          grp,
                          grpItems,
                          isExpanded: isExpanded,
                          forceExpandSubItems: q.isNotEmpty,
                        );
                      }
                    }),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      style: const TextStyle(fontSize: 12, color: _textPrimary),
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        hintText: 'Search settings (Password, Developer, Honor)...',
        hintStyle: const TextStyle(fontSize: 11, color: _textSecondary),
        prefixIcon:
            const Icon(Icons.search_rounded, size: 18, color: _cyan),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 34, minHeight: 34),
        filled: true,
        fillColor: _card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: _cyan, width: 1.4),
        ),
      ),
      onChanged: (val) => setState(() => _searchQuery = val.trim()),
    );
  }

  // ==========================================================================
  // MAIN RECTANGLE HEADER BUILDER (Used by all 10 Accordion Groups)
  // ==========================================================================
  Widget _buildMainGroupHeaderRectangle({
    required _HubGroupMeta group,
    required int itemCount,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
        decoration: BoxDecoration(
          color: isExpanded ? group.color.withOpacity(0.14) : _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isExpanded ? group.color : _border,
            width: isExpanded ? 1.7 : 1.2,
          ),
        ),
        child: Row(
          children: [
            // Number Box
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: group.color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: group.color.withOpacity(0.5)),
              ),
              child: Text(
                group.numberTag,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: group.color,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                group.title,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  height: 1.22,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _cardAlt,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: group.color.withOpacity(0.35)),
              ),
              child: Text(
                '$itemCount items',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: group.color,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.chevron_right_rounded,
              color: isExpanded ? group.color : _textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // GROUP 01: DIRECT IN-APP CONTROLS (2-Tier Sub-Rectangles: Full Title + Pills)
  // ==========================================================================
  Widget _buildDirectControlsAccordionGroup(
    _HubGroupMeta group, {
    required bool isExpanded,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMainGroupHeaderRectangle(
            group: group,
            itemCount: 5,
            isExpanded: isExpanded,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (_expandedGroups.contains(group.id)) {
                  _expandedGroups.remove(group.id);
                } else {
                  _expandedGroups.add(group.id);
                }
              });
            },
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 8),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: group.color, width: 2.5),
                  ),
                ),
                padding: const EdgeInsets.only(left: 10),
                child: Column(
                  children: [
                    // Sub-Rectangle 1: Flashlight (Hardware Torch)
                    _buildDirectSubRectangle(
                      title: 'Flashlight (Hardware Torch)',
                      statusBadge: _isTorchOn ? 'ACTIVE' : 'OFF',
                      icon: _isTorchOn
                          ? Icons.flashlight_on_rounded
                          : Icons.flashlight_off_rounded,
                      accentColor: _isTorchOn ? _amber : _coral,
                      controlsRow: Row(
                        children: [
                          Expanded(
                            child: _buildActionPill(
                              label: 'Turn OFF',
                              selected: !_isTorchOn,
                              color: _coral,
                              onTap: () =>
                                  _runDirectControl('toggleTorch', false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildActionPill(
                              label: 'Turn ON',
                              selected: _isTorchOn,
                              color: _amber,
                              onTap: () =>
                                  _runDirectControl('toggleTorch', true),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Sub-Rectangle 2: Ringer Audio Mode
                    _buildDirectSubRectangle(
                      title: 'Ringer Audio Mode',
                      statusBadge: _ringerMode.toUpperCase(),
                      icon: Icons.volume_up_rounded,
                      accentColor: _emerald,
                      controlsRow: Row(
                        children: [
                          Expanded(
                            child: _buildActionPill(
                              label: 'Normal',
                              selected: _ringerMode == 'normal',
                              color: _emerald,
                              onTap: () =>
                                  _runDirectControl('setRingerMode', 'normal'),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildActionPill(
                              label: 'Vibrate',
                              selected: _ringerMode == 'vibrate',
                              color: _amber,
                              onTap: () =>
                                  _runDirectControl('setRingerMode', 'vibrate'),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildActionPill(
                              label: 'Silent',
                              selected: _ringerMode == 'silent',
                              color: _coral,
                              onTap: () =>
                                  _runDirectControl('setRingerMode', 'silent'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Sub-Rectangle 3: Screen Brightness Level
                    _buildDirectSubRectangle(
                      title: 'Screen Brightness Level',
                      statusBadge:
                          _autoBrightness ? 'AUTO' : '$_brightnessPct%',
                      icon: Icons.brightness_6_rounded,
                      accentColor: _amber,
                      subtitleWidget: !_canWriteSettings
                          ? GestureDetector(
                              onTap: () => _openSettingTarget(
                                  'write_settings_permission',
                                  'Modify System Settings'),
                              child: const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Tap here to grant Modify System Settings permission',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: _amber,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            )
                          : null,
                      controlsRow: Row(
                        children: [
                          Expanded(
                            child: _buildActionPill(
                              label: 'Auto',
                              selected: _autoBrightness,
                              color: _amber,
                              onTap: () =>
                                  _runDirectControl('setAutoBrightness', true),
                            ),
                          ),
                          for (final pct in [25, 50, 100]) ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildActionPill(
                                label: '$pct%',
                                selected: !_autoBrightness &&
                                    (_brightnessPct - pct).abs() <= 14,
                                color: _amber,
                                onTap: () =>
                                    _runDirectControl('setBrightness', pct),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Sub-Rectangle 4: System RAM & Cache Trim
                    _buildDirectSubRectangle(
                      title: 'System RAM & Cache Trim',
                      statusBadge: 'MEMORY',
                      icon: Icons.cleaning_services_rounded,
                      accentColor: _violet,
                      subtitleWidget: const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Text(
                          'Frees cached memory safely (Recent Apps cards = OS history)',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: _textSecondary,
                          ),
                        ),
                      ),
                      controlsRow: SizedBox(
                        width: double.infinity,
                        child: _buildActionPill(
                          label: 'Trim Cached System RAM  ->',
                          selected: true,
                          color: _violet,
                          onTap: () => _runDirectControl('boostSystemMemory'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Sub-Rectangle 5: Safe Charge Booster (Cool & Fast)
                    _buildDirectSubRectangle(
                      title: 'Safe Charge Booster (Cool & Fast)',
                      statusBadge: '${_batteryWatts.toStringAsFixed(1)}W',
                      icon: Icons.bolt_rounded,
                      accentColor: _emerald,
                      subtitleWidget: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          '${_isCharging ? _chargingSource : "Ready"} • ${_batteryTempC.toStringAsFixed(1)}°C • Health $_batteryHealth ($_batteryHealthScore%)',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: _emerald,
                          ),
                        ),
                      ),
                      controlsRow: SizedBox(
                        width: double.infinity,
                        child: _buildActionPill(
                          label: 'Activate Safe Charge Booster  ->',
                          selected: true,
                          color: _emerald,
                          onTap: () => _runDirectControl('safeChargeBooster'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDirectSubRectangle({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Widget controlsRow,
    String? statusBadge,
    Widget? subtitleWidget,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: _subCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    height: 1.2,
                  ),
                ),
              ),
              if (statusBadge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: accentColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    statusBadge,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (subtitleWidget != null) subtitleWidget,
          const SizedBox(height: 8),
          controlsRow,
        ],
      ),
    );
  }

  Widget _buildActionPill({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6.5),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.22) : _bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : _border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: selected ? color : _textSecondary,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // GROUPS 02–10: CATEGORY ACCORDION -> INDENTED SUB-RECTANGLES
  // ==========================================================================
  Widget _buildCategoryAccordionGroup(
    _HubGroupMeta group,
    List<_SystemControlItem> items, {
    required bool isExpanded,
    required bool forceExpandSubItems,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMainGroupHeaderRectangle(
            group: group,
            itemCount: items.length,
            isExpanded: isExpanded,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (_expandedGroups.contains(group.id)) {
                  _expandedGroups.remove(group.id);
                } else {
                  _expandedGroups.add(group.id);
                }
              });
            },
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 8),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: group.color, width: 2.5),
                  ),
                ),
                padding: const EdgeInsets.only(left: 10),
                child: Column(
                  children: items.map((item) {
                    final subExpanded = forceExpandSubItems ||
                        _expandedItems.contains(item.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildSubItemRectangle(
                        item,
                        isSubExpanded: subExpanded,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SUB-RECTANGLE (Collapsed Bar -> Taps to Unfold Step-by-Step Guide & Button)
  // ==========================================================================
  Widget _buildSubItemRectangle(
    _SystemControlItem item, {
    required bool isSubExpanded,
  }) {
    final statusColor = item.isStatusHealthy ? item.color : _coral;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: _subCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSubExpanded
              ? statusColor.withOpacity(0.75)
              : (item.isStatusHealthy ? _border : _coral.withOpacity(0.5)),
          width: isSubExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Clickable Sub-Rectangle Header Bar
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (_expandedItems.contains(item.id)) {
                  _expandedItems.remove(item.id);
                } else {
                  _expandedItems.add(item.id);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              child: Row(
                children: [
                  Icon(item.icon, size: 16, color: item.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      item.statusLabel,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isSubExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.chevron_right_rounded,
                    size: 17,
                    color: isSubExpanded ? statusColor : _textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Unfolded Body when Sub-Rectangle is Tapped
          if (isSubExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(color: _border, height: 10),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: _textSecondary,
                      height: 1.35,
                    ),
                  ),

                  // Inline direct controls if supported
                  if (item.supportsDirectAction) ...[
                    const SizedBox(height: 10),
                    _buildInlineDirectWidget(item),
                  ],

                  const SizedBox(height: 8),

                  // SysPulse Recommendation Tip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _cardAlt.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: item.color.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.tips_and_updates_rounded,
                            size: 14, color: item.color),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'SysPulse Tip: ${item.recommendation}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFE2E8F0),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Step-by-Step Setup Guide Box
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Step-by-Step Setup Guide:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _cyan,
                          ),
                        ),
                        const SizedBox(height: 5),
                        ...item.steps.asMap().entries.map((entry) {
                          final stepNum = entry.key + 1;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              '$stepNum. ${entry.value}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _textPrimary,
                                height: 1.35,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Full-Width Launch Setting Screen Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () =>
                          _openSettingTarget(item.targetKey, item.title),
                      style: FilledButton.styleFrom(
                        backgroundColor: statusColor.withOpacity(0.22),
                        foregroundColor: statusColor,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                          side: BorderSide(color: statusColor.withOpacity(0.6)),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 15),
                      label: const Text(
                        'Open Setting Screen  ->',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInlineDirectWidget(_SystemControlItem item) {
    if (item.id == 'ringer_volume') {
      return Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Direct Media Volume Presets:',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _textSecondary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final v in [0, 25, 50, 75, 100]) ...[
                  Expanded(
                    child: _buildActionPill(
                      label: '$v%',
                      selected: (_mediaVolumePct - v).abs() <= 12,
                      color: _cyan,
                      onTap: () => _runDirectControl('setMediaVolume', v),
                    ),
                  ),
                  if (v != 100) const SizedBox(width: 5),
                ],
              ],
            ),
          ],
        ),
      );
    }

    if (item.id == 'brightness_timeout') {
      return Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Direct Screen Sleep Timeout Presets:',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _textSecondary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final sec in [30, 60, 120, 300]) ...[
                  Expanded(
                    child: _buildActionPill(
                      label: sec < 60 ? '${sec}s' : '${sec ~/ 60}m',
                      selected: (_screenTimeoutSec - sec).abs() <= 10,
                      color: _amber,
                      onTap: () => _runDirectControl('setScreenTimeout', sec),
                    ),
                  ),
                  if (sec != 300) const SizedBox(width: 6),
                ],
              ],
            ),
          ],
        ),
      );
    }

    if (item.id == 'torch_flashlight') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          onPressed: () => _runDirectControl('toggleTorch', !_isTorchOn),
          style: FilledButton.styleFrom(
            backgroundColor: (_isTorchOn ? _amber : _cyan).withOpacity(0.18),
            foregroundColor: _isTorchOn ? _amber : _cyan,
          ),
          icon: Icon(_isTorchOn
              ? Icons.flashlight_off_rounded
              : Icons.flashlight_on_rounded),
          label: Text(
            _isTorchOn ? 'Turn Flashlight OFF' : 'Turn Flashlight ON',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    if (item.id == 'battery_health_booster') {
      final flowSign = _isCharging ? '+' : '-';
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _emerald.withOpacity(0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Health: $_batteryHealth ($_batteryHealthScore%) • $_chargingSource',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'Live Flow: $flowSign${_batteryWatts.toStringAsFixed(1)}W ($flowSign${_batteryCurrentMa}mA) • Thermal: ${_batteryTempC.toStringAsFixed(1)}°C ($_thermalStatus)',
              style: const TextStyle(
                fontSize: 10.5,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _runDirectControl('safeChargeBooster'),
                style: FilledButton.styleFrom(
                  backgroundColor: _emerald,
                  foregroundColor: const Color(0xFF04130D),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.bolt_rounded, size: 17),
                label: const Text(
                  'Activate Safe Charge Booster (100% Safe)',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (item.id == 'honor_launch') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          onPressed: () => _runDirectControl('boostSystemMemory'),
          style: FilledButton.styleFrom(
            backgroundColor: _emerald.withOpacity(0.18),
            foregroundColor: _emerald,
          ),
          icon: const Icon(Icons.cleaning_services_rounded, size: 17),
          label: const Text(
            'Trim Cached System RAM',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _HubGroupMeta {
  final String id;
  final String numberTag;
  final String title;
  final String badgeSuffix;
  final IconData icon;
  final Color color;

  const _HubGroupMeta({
    required this.id,
    required this.numberTag,
    required this.title,
    required this.badgeSuffix,
    required this.icon,
    required this.color,
  });
}

class _SystemControlItem {
  final String id;
  final String category;
  final String title;
  final String categoryTag;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String statusLabel;
  final bool isStatusHealthy;
  final bool supportsDirectAction;
  final String targetKey;
  final String recommendation;
  final List<String> steps;

  const _SystemControlItem({
    required this.id,
    required this.category,
    required this.title,
    required this.categoryTag,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.statusLabel,
    required this.isStatusHealthy,
    required this.supportsDirectAction,
    required this.targetKey,
    required this.recommendation,
    required this.steps,
  });
}
