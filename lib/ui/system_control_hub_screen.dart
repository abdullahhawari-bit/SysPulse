import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// UNIFIED SYSTEM CONTROL HUB SCREEN
// Categorized 1-Click Direct Controls + Deep Android Settings Wizard
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

  // Palette matching SysPulse Dark Mode
  static const Color _bg = Color(0xFF070B14);
  static const Color _card = Color(0xFF111927);
  static const Color _cardAlt = Color(0xFF192338);
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
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final Set<String> _expandedGuides = <String>{
    'dev_options',
    'screen_lock',
    'honor_launch',
    'date_time',
    'wallpaper',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: ok ? const Color(0xFF065F46) : const Color(0xFF92400E),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
    await _refreshHubState();
  }

  Future<void> _openSettingTarget(String targetKey, String titleAr) async {
    HapticFeedback.selectionClick();
    try {
      await _channel.invokeMethod<bool>(
        'openSystemSettingTarget',
        {'targetKey': targetKey},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم فتح نافذة: $titleAr — اتبع إرشادات SysPulse للضبط'),
            backgroundColor: _cardAlt,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  List<_HubCategoryMeta> get _categories => const [
        _HubCategoryMeta('all', 'الكل • All', Icons.apps_rounded, _cyan),
        _HubCategoryMeta('audio', 'الصوت والاهتزاز', Icons.volume_up_rounded, _emerald),
        _HubCategoryMeta('display', 'الشاشة والخلفية', Icons.wb_sunny_rounded, _amber),
        _HubCategoryMeta('security', 'الأمان وكلمة المرور', Icons.security_rounded, _coral),
        _HubCategoryMeta('network', 'الشبكات والاتصالات', Icons.wifi_rounded, _blue),
        _HubCategoryMeta('battery', 'البطارية والأداء', Icons.bolt_rounded, _emerald),
        _HubCategoryMeta('developer', 'خيارات المطور والنظام', Icons.terminal_rounded, _violet),
        _HubCategoryMeta('regional', 'الوقت والتاريخ واللغة', Icons.schedule_rounded, _cyan),
        _HubCategoryMeta('apps', 'التطبيقات والأذونات', Icons.admin_panel_settings_rounded, _amber),
        _HubCategoryMeta('accessibility', 'التسهيلات والتخزين', Icons.accessibility_new_rounded, _blue),
      ];

  List<_SystemControlItem> _buildAllControlItems() {
    final timeoutLabel = _screenTimeoutSec >= 60
        ? '${_screenTimeoutSec ~/ 60} دقيقة'
        : '$_screenTimeoutSec ثانية';
    final ringerLabel = _ringerMode == 'silent'
        ? 'صامت (Silent)'
        : (_ringerMode == 'vibrate' ? 'اهتزاز (Vibrate)' : 'عام (Normal)');

    return [
      // ==================== 1. AUDIO & SOUND ====================
      _SystemControlItem(
        id: 'ringer_volume',
        category: 'audio',
        titleAr: 'وضع الرنين ومستوى الصوت المباشر',
        titleEn: 'Ringer Mode & Volume Control',
        subtitleAr: 'تبديل فوري بين (عام / اهتزاز / صامت) وضبط مستوى الصوت بضغطة زر',
        icon: Icons.notifications_active_rounded,
        color: _emerald,
        statusLabel: '$ringerLabel • $_mediaVolumePct%',
        isStatusHealthy: true,
        supportsDirectAction: true,
        targetKey: 'sound_settings',
        recommendationAr:
            'تفعيل وضع الاهتزاز أثناء الاجتماعات وتحديد مستوى الوسائط عند 50%-75% لحماية السمع والبطارية.',
        stepsAr: const [
          'يمكنك التبديل فوراً من الأزرار المباشرة بالأسفل داخل التطبيق دون الخروج.',
          'لتخصيص نغمة الرنين أو نغمة الرسائل، اضغط زر "فتح إعدادات الصوت".',
          'اختر "نغمة رنين الهاتف (SIM 1 / SIM 2)" وحدد النغمة المفضلة لديك.',
        ],
      ),
      _SystemControlItem(
        id: 'dnd_mode',
        category: 'audio',
        titleAr: 'عدم الإزعاج وتصفية المقاطعات',
        titleEn: 'Do Not Disturb (DND) & Priority',
        subtitleAr: 'كتم الإشعارات المزعجة وقت النوم مع السماح للمكالمات الهامة فقط',
        icon: Icons.do_not_disturb_on_rounded,
        color: _violet,
        statusLabel: _dndPolicyGranted ? 'مصرح لـ SysPulse' : 'يتطلب إذن أولوية',
        isStatusHealthy: _dndPolicyGranted,
        supportsDirectAction: false,
        targetKey: 'dnd_settings',
        recommendationAr:
            'اضبط جدولاً تلقائياً لعدم الإزعاج من 11 مساءً حتى 6 صباحاً مع استثناء جهات الاتصال المفضلة.',
        stepsAr: const [
          'اضغط زر "فتح الإعدادات" للانتقال مباشرة إلى شاشة عدم الإزعاج.',
          'اضغط على "جدولة زمنية (Schedule)" لتحديد وقت النوم التلقائي.',
          'ادخل إلى "المكالمات والرسائل المسموح بها" واختر "المفضلة أو جهات الاتصال فقط".',
        ],
      ),
      _SystemControlItem(
        id: 'app_notifications',
        category: 'audio',
        titleAr: 'إدارة إشعارات التطبيقات والبانرات',
        titleEn: 'App Notifications & Status Bar',
        subtitleAr: 'إيقاف الإشعارات الإعلانية المزعجة للتطبيقات غير الضرورية',
        icon: Icons.mark_chat_unread_rounded,
        color: _cyan,
        statusLabel: 'إدارة شاملة',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'notification_settings',
        recommendationAr:
            'إيقاف إشعارات الألعاب وتطبيقات التسوق يقلل من إيقاظ الشاشة ويوفر حتى 8% من البطارية يومياً.',
        stepsAr: const [
          'اضغط زر "فتح الإعدادات" لعرض قائمة إشعارات جميع التطبيقات.',
          'رتّب القائمة حسب "الأحدث إرسالاً (Most Recent)" لمعرفة التطبيقات المزعجة.',
          'أغلق المفتاح المقابل لأي تطبيق لا تحتاج لتنبيهاته.',
        ],
      ),

      // ==================== 2. DISPLAY & WALLPAPER ====================
      _SystemControlItem(
        id: 'brightness_timeout',
        category: 'display',
        titleAr: 'سطوع الشاشة ومهلة الإغلاق التلقائي',
        titleEn: 'Screen Brightness & Auto-Lock Timeout',
        subtitleAr: 'ضبط مباشر لنسبة الإضاءة التلقائية وزمن إغلاق الشاشة لتوفير الطاقة',
        icon: Icons.wb_sunny_rounded,
        color: _amber,
        statusLabel:
            '${_autoBrightness ? "تلقائي" : "$_brightnessPct%"} • مهلة $timeoutLabel',
        isStatusHealthy: _screenTimeoutSec <= 120,
        supportsDirectAction: true,
        targetKey: 'display_settings',
        recommendationAr:
            'السطوع التلقائي ومهلة إغلاق الشاشة عند (30 ثانية أو 1 دقيقة) يحفظان الشاشة من التطبيع ويوفران 20% من البطارية.',
        stepsAr: const [
          'استخدم أزرار الضبط السريع بالأسفل لتحديد السطوع (25% - 100%) أو المهلة (30ث - 5د) فوراً.',
          'إذا طُلب منك إذن "تعديل إعدادات النظام" لأول مرة، فعّل المفتاح أمام SysPulse ثم ارجع.',
          'أو اضغط "فتح إعدادات الشاشة" لضبط حجم الخط ومعدل تحديث الشاشة (120Hz / Dynamic).',
        ],
      ),
      _SystemControlItem(
        id: 'wallpaper_style',
        category: 'display',
        titleAr: 'ضبط خلفية الشاشة والسمات',
        titleEn: 'Wallpaper, Lock Screen & Themes',
        subtitleAr: 'تغيير خلفية الشاشة الرئيسية وشاشة القفل بضغطة واحدة',
        icon: Icons.wallpaper_rounded,
        color: _violet,
        statusLabel: 'تخصيص المظهر',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'wallpaper_settings',
        recommendationAr:
            'استخدام الخلفيات الداكنة (Dark Wallpapers) على شاشات OLED يطفئ البكسلات السوداء ويوفر الطاقة.',
        stepsAr: const [
          'اضغط زر "تغيير خلفية الشاشة" بالأسفل لفتح منتقي الخلفيات والمعرض مباشرة.',
          'اختر الصورة أو الخلفية الداكنة التي ترغب بها من المعرض أو خلفيات النظام.',
          'اضغط "تعيين كخلفية (Set Wallpaper)" وحدد (الشاشة الرئيسية أو شاشة القفل أو كليهما).',
        ],
      ),
      _SystemControlItem(
        id: 'eye_comfort_night',
        category: 'display',
        titleAr: 'حماية العين والوضع الليلي الدافئ',
        titleEn: 'Eye Comfort Shield & Dark Mode',
        subtitleAr: 'تصفية الأشعة الزرقاء المجهدة للعين ليلاً وتفعيل المظهر الداكن',
        icon: Icons.nightlight_round,
        color: _blue,
        statusLabel: 'حماية البصر',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'night_display_settings',
        recommendationAr:
            'تفعيل وضع راحة العين بعد الغروب يساعد على النوم الصحي ويقلل إجهاد الشبكية.',
        stepsAr: const [
          'اضغط زر "فتح إعدادات راحة العين" بالأسفل.',
          'فعّل خيار "حماية العين / Eye Comfort" أو "الجدولة من الغروب للشروق".',
          'اضبط شريط حرارة اللون نحو اللون الدافئ المريح لعينيك.',
        ],
      ),
      _SystemControlItem(
        id: 'torch_flashlight',
        category: 'display',
        titleAr: 'كشاف الإضاءة الخلفي الفوري',
        titleEn: 'Instant Hardware Flashlight (Torch)',
        subtitleAr: 'تشغيل وإيقاف فلاش الكاميرا الخلفي مباشرة بضغطة زر',
        icon: Icons.flashlight_on_rounded,
        color: _isTorchOn ? _amber : _cyan,
        statusLabel: _isTorchOn ? 'يعمل الآن (ON) 🔦' : 'مغلق (OFF)',
        isStatusHealthy: true,
        supportsDirectAction: true,
        targetKey: 'display_settings',
        recommendationAr:
            'يعمل الكشاف مباشرة عبر دائرة الفلاش دون فتح الكاميرا لتوفير الطاقة.',
        stepsAr: const [
          'اضغط زر "تشغيل / إيقاف الكشاف" بالأسفل للتحكم الفوري بالإضاءة.',
        ],
      ),

      // ==================== 3. SECURITY & PASSWORDS ====================
      _SystemControlItem(
        id: 'screen_lock',
        category: 'security',
        titleAr: 'ضبط كلمة المرور وقفل الشاشة',
        titleEn: 'Screen Lock Password, PIN & Pattern',
        subtitleAr: 'تعيين أو تغيير الرقم السري أو النمط لحماية الهاتف من المتطفلين',
        icon: Icons.lock_rounded,
        color: _isDeviceSecure ? _emerald : _coral,
        statusLabel: _isDeviceSecure ? 'محمي بقفل نشط 🔒' : 'غير محمي ⚠️',
        isStatusHealthy: _isDeviceSecure,
        supportsDirectAction: false,
        targetKey: 'screen_lock',
        recommendationAr:
            'استخدم رمز PIN من 6 أرقام أو كلمة مرور قوية؛ فقفل الشاشة يفعل تشفير بيانات الهاتف تلقائياً.',
        stepsAr: const [
          'اضغط زر "ضبط كلمة المرور وقفل الشاشة" بالأسفل للانتقال مباشرة لشاشة التعيين.',
          'أدخل رمز القفل الحالي (إن وجد)، ثم اختر نوع القفل (رقم سري PIN، نمط Pattern، أو كلمة مرور).',
          'أدخل الرمز الجديد مرتين للتأكيد واضغط "تم (Done)".',
        ],
      ),
      _SystemControlItem(
        id: 'biometrics_fingerprint',
        category: 'security',
        titleAr: 'بصمة الإصبع والتعرف على الوجه',
        titleEn: 'Fingerprint & Face Unlock Biometrics',
        subtitleAr: 'إضافة بصمات الأصابع أو بصمة الوجه لفتح الهاتف والتطبيقات البنكية بسرعة',
        icon: Icons.fingerprint_rounded,
        color: _cyan,
        statusLabel: _isDeviceSecure ? 'البصمة متاحة' : 'يتطلب قفل شاشة أولاً',
        isStatusHealthy: _isDeviceSecure,
        supportsDirectAction: false,
        targetKey: 'biometric_enroll',
        recommendationAr:
            'سجّل بصمة الإبهام والسبابة لكلتا اليدين لتسهيل فتح الهاتف في جميع الأوضاع.',
        stepsAr: const [
          'اضغط زر "فتح إعدادات البصمة والوجه" بالأسفل.',
          'اختر "إدارة بصمات الأصابع (Fingerprint Management)" وأدخل رمز القفل.',
          'اضغط "بصمة جديدة" وضع إصبعك على المستشعر عدة مرات من زوايا مختلفة حتى يكتمل التسجيل.',
        ],
      ),
      _SystemControlItem(
        id: 'privacy_location',
        category: 'security',
        titleAr: 'الخصوصية وخدمات الموقع الجغرافي (GPS)',
        titleEn: 'Privacy Dashboard & Location Services',
        subtitleAr: 'مراجعة التطبيقات التي تصل للموقع والكاميرا والمايكروفون',
        icon: Icons.location_on_rounded,
        color: _amber,
        statusLabel: 'تحكم الخصوصية',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'location_settings',
        recommendationAr:
            'اضبط صلاحية الموقع للتطبيقات على "أثناء استخدام التطبيق فقط" لمنع التتبع في الخلفية.',
        stepsAr: const [
          'اضغط زر "فتح إعدادات الموقع والخصوصية" بالأسفل.',
          'راجع قائمة "التطبيقات التي طلبت الموقع مؤخراً".',
          'اضغط على أي تطبيق غير ضروري واختر "السماح أثناء الاستخدام فقط" أو "عدم السماح".',
        ],
      ),
      _SystemControlItem(
        id: 'security_center',
        category: 'security',
        titleAr: 'مركز الأمان وتحديثات الحماية والـ SIM',
        titleEn: 'System Security, Find My Device & SIM Lock',
        subtitleAr: 'فحص Google Play Protect، قفل شريحة SIM، والعثور على الهاتف المفقود',
        icon: Icons.shield_rounded,
        color: _emerald,
        statusLabel: 'فحص شامل',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'security_settings',
        recommendationAr:
            'تأكد من تفعيل ميزة "العثور على جهازي (Find My Device)" لتتمكن من تحديد موقع الهاتف أو مسحه عن بُعد في حال فقدانه.',
        stepsAr: const [
          'اضغط زر "فتح مركز الأمان" بالأسفل.',
          'تحقق من أن "الحماية Play Protect" مفعلة ولا توجد تطبيقات ضارة.',
          'ادخل إلى "العثور على جهازي" وتأكد من أنها في وضع التشغيل (On).',
        ],
      ),

      // ==================== 4. CONNECTIVITY & NETWORK ====================
      _SystemControlItem(
        id: 'wifi_networks',
        category: 'network',
        titleAr: 'شبكات الواي فاي ومشاركة كلمة المرور (QR)',
        titleEn: 'Wi-Fi Networks & QR Share',
        subtitleAr: 'الاتصال بالشبكات اللاسلكية، عرض باركود الشبكة، وضبط IP الثابت',
        icon: Icons.wifi_rounded,
        color: _wifiEnabled ? _emerald : _textSecondary,
        statusLabel: _wifiEnabled ? 'الواي فاي متصل / مفعل' : 'الواي فاي مغلق',
        isStatusHealthy: _wifiEnabled,
        supportsDirectAction: false,
        targetKey: 'wifi_settings',
        recommendationAr:
            'أوقف خيار "البحث التلقائي عن الشبكات المفتوحة" لحماية هاتفك من نقاط الاتصال الوهمية.',
        stepsAr: const [
          'اضغط زر "فتح إعدادات الواي فاي" بالأسفل.',
          'لمشاركة الشبكة الحالية، اضغط على اسم الشبكة المتصلة سيظهر لك رمز QR جاهز للمسح.',
          'لحذف شبكة قديمة، اضغط مطولاً عليها واختر "نسيان الشبكة (Forget)".',
        ],
      ),
      _SystemControlItem(
        id: 'bluetooth_devices',
        category: 'network',
        titleAr: 'البلوتوث والأجهزة المقترنة والسماعات',
        titleEn: 'Bluetooth Audio, Watch & Paired Devices',
        subtitleAr: 'ربط الساعات الذكية، السماعات اللاسلكية، وبلوتوث السيارة',
        icon: Icons.bluetooth_rounded,
        color: _bluetoothEnabled ? _blue : _textSecondary,
        statusLabel: _bluetoothEnabled ? 'البلوتوث نشط 🔵' : 'البلوتوث مغلق',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'bluetooth_settings',
        recommendationAr:
            'أغلق البلوتوث عند عدم استخدام السماعات أو الساعة لتوفير الطاقة وتعزيز الأمان.',
        stepsAr: const [
          'اضغط زر "فتح إعدادات البلوتوث" بالأسفل.',
          'فعّل مفتاح البلوتوث وانتظر ظهور اسم السماعة أو الجهاز في قائمة "الأجهزة المتاحة".',
          'اضغط على اسم الجهاز ثم وافق على طلب الاقتران (Pair).',
        ],
      ),
      _SystemControlItem(
        id: 'hotspot_tethering',
        category: 'network',
        titleAr: 'نقطة الاتصال الشخصية وبث الإنترنت (Hotspot)',
        titleEn: 'Personal Wi-Fi Hotspot & Tethering',
        subtitleAr: 'تحويل الهاتف إلى راوتر واي فاي وضبط كلمة مرور نقطة الاتصال',
        icon: Icons.wifi_tethering_rounded,
        color: _cyan,
        statusLabel: 'مشاركة الإنترنت',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'hotspot_settings',
        recommendationAr:
            'حدد "حد البيانات لمرة واحدة" (مثلاً 500MB) وإغلاق نقطة الاتصال تلقائياً عند عدم اتصال أي جهاز.',
        stepsAr: const [
          'اضغط زر "فتح إعدادات نقطة الاتصال" بالأسفل.',
          'ادخل إلى "نقطة اتصال Wi-Fi الشخصية (Personal Hotspot)".',
          'اضغط على "تهيئة نقطة الاتصال" لتغيير اسم الشبكة وكلمة المرور إلى رمز قوي.',
        ],
      ),
      _SystemControlItem(
        id: 'sim_mobile_data',
        category: 'network',
        titleAr: 'إدارة شرائح SIM وبيانات الهاتف والتجوال',
        titleEn: 'SIM Cards, 5G/4G Preferred Network & Roaming',
        subtitleAr: 'تحديد الشريحة المخصصة للإنترنت والمكالمات وتفعيل 5G أو VoLTE',
        icon: Icons.sim_card_rounded,
        color: _violet,
        statusLabel: 'إعدادات الشريحة',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'data_roaming_sim',
        recommendationAr:
            'إذا كانت إشارة 5G ضعيفة في منطقتك وتستنزف البطارية، اضبط نمط الشبكة المفضل على 4G/LTE تلقائي.',
        stepsAr: const [
          'اضغط زر "فتح إعدادات الشريحة والبيانات" بالأسفل.',
          'حدد الشريحة الافتراضية لبيانات الجوال (Mobile Data) وشريحة المكالمات.',
          'يمكنك من نفس الشاشة تفعيل مكالمات الواي فاي (Wi-Fi Calling) وتحديد نمط الشبكة.',
        ],
      ),
      _SystemControlItem(
        id: 'nfc_vpn_dns',
        category: 'network',
        titleAr: 'الدفع اللاسلكي (NFC) والـ VPN والـ DNS الخاص',
        titleEn: 'NFC Contactless Pay, VPN & Private DNS',
        subtitleAr: 'تشغيل الدفع عبر الهاتف (مدى / Google Pay) وإعداد مانع الإعلانات DNS',
        icon: Icons.contactless_rounded,
        color: _nfcEnabled ? _emerald : _amber,
        statusLabel: _nfcEnabled ? 'NFC مفعل للدفع 💳' : 'NFC مغلق',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'nfc_settings',
        recommendationAr:
            'لتفعيل حجب الإعلانات والمواقع الضارة مجاناً في كل الهاتف، اضبط "DNS الخاص" على dns.adguard-dns.com.',
        stepsAr: const [
          'اضغط زر "فتح إعدادات NFC والاتصالات" بالأسفل.',
          'فعّل مفتاح NFC لاستخدام تطبيقات الدفع البنكي عبر تقريب الهاتف.',
          'للـ DNS الخاص: ادخل "المزيد من الاتصالات" ➔ "DNS الخاص (Private DNS)".',
        ],
      ),

      // ==================== 5. BATTERY & PERFORMANCE ====================
      _SystemControlItem(
        id: 'honor_launch',
        category: 'battery',
        titleAr: 'إدارة بدء تشغيل التطبيقات (Honor App Launch) والذاكرة',
        titleEn: 'Honor Startup Manager & RAM Boost',
        subtitleAr: 'منع التطبيقات العنيدة من إعادة تشغيل نفسها في الخلفية بعد مسحها',
        icon: Icons.rocket_launch_rounded,
        color: _coral,
        statusLabel: 'تحكم مباشر + إعدادات',
        isStatusHealthy: true,
        supportsDirectAction: true,
        targetKey: 'honor_app_launch',
        recommendationAr:
            'في هواتف Honor، إيقاف "الإدارة التلقائية" للتطبيقات غير الهامة يمنع استنزاف البطارية أثناء الليل نهائياً.',
        stepsAr: const [
          'اضغط زر "تنظيف الذاكرة الفوري" بالأسفل لتفريغ الـ Cache الآن.',
          'ثم اضغط "فتح إدارة تشغيل التطبيقات (App Launch)" للانتقال لإعدادات هونر.',
          'أغلق المفتاح التلقائي أمام التطبيقات المستنزفة، وأوقف خيار "التشغيل في الخلفية (Run in background)".',
        ],
      ),
      _SystemControlItem(
        id: 'battery_saver_health',
        category: 'battery',
        titleAr: 'وضع توفير الطاقة وصحة البطارية والشحن الذكي',
        titleEn: 'Battery Saver, Smart Charge & Thermal Mode',
        subtitleAr: 'تفعيل وضع توفير البطارية والشحن الذكي لحماية عمر البطارية',
        icon: Icons.battery_charging_full_rounded,
        color: _batterySaverOn ? _amber : _emerald,
        statusLabel: _batterySaverOn ? 'توفير الطاقة مفعل 🔋' : 'الأداء المتوازن',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'battery_saver',
        recommendationAr:
            'فعّل خيار "الشحن الذكي (Smart Charge)" و"سعة البطارية الذكية" في إعدادات البطارية لإطالة عمر البطارية لسنوات.',
        stepsAr: const [
          'اضغط زر "فتح إعدادات البطارية" بالأسفل.',
          'فعّل "وضع توفير الطاقة (Power Saving Mode)" عند انخفاض الشحن عن 30%.',
          'ادخل إلى "المزيد من إعدادات البطارية" وفعّل "الشحن الذكي".',
        ],
      ),

      // ==================== 6. DEVELOPER OPTIONS & SYSTEM ====================
      _SystemControlItem(
        id: 'dev_options',
        category: 'developer',
        titleAr: 'خيارات المطور المتقدمة (Developer Options)',
        titleEn: 'Android Developer Options & USB Debugging',
        subtitleAr: 'الوصول الفوري لنافذة المبرمجين، تسريع الهاتف، وإغلاق ثغرة تصحيح USB',
        icon: Icons.developer_mode_rounded,
        color: _adbEnabled ? _coral : _violet,
        statusLabel: !_devOptionsEnabled
            ? 'مخفية (اضغط لتفعيلها)'
            : (_adbEnabled ? 'تصحيح USB مفعل ⚠️' : 'مفعلة وآمنة ✅'),
        isStatusHealthy: !_adbEnabled,
        supportsDirectAction: false,
        targetKey: _devOptionsEnabled ? 'developer_options' : 'device_info_build',
        recommendationAr:
            _adbEnabled
                ? '⚠️ تنبيه أمني: خيار "تصحيح أخطاء USB" مفعل حالياً! يُنصح بإيقافه فوراً لحماية بياناتك عند توصيل الهاتف بأي شاحن عام.'
                : '💡 نصيحة سرعة: داخل خيارات المطور، تغيير "حجم الرسوم المتحركة (Animation Scale)" من 1x إلى 0.5x يجعل الهاتف أسرع بمرتين!',
        stepsAr: _devOptionsEnabled
            ? const [
                'اضغط زر "فتح خيارات المطور مباشرة" بالأسفل.',
                'للحماية الأمنية: ابحث عن "تصحيح أخطاء USB (USB Debugging)" وتأكد من إغلاقه.',
                'لتسريع الهاتف: انزل إلى قسم الرسم (Drawing) واجعل مقاييس الرسوم المتحركة الثلاثة على (0.5x).',
              ]
            : const [
                'خيارات المطور مخفية حالياً في هاتفك؛ لتفعيلها اضغط الزر بالأسفل لفتح شاشة "حول الهاتف (About Phone)".',
                'ابحث عن سطر "رقم البناء (Build Number)" واضغط عليه 7 ضغطات متتالية سريعة.',
                'أدخل رمز قفل الشاشة، وستظهر لك رسالة "أنت الآن مطور برامج!" ثم ارجع هنا لفتحها مباشرة.',
              ],
      ),
      _SystemControlItem(
        id: 'about_device_update',
        category: 'developer',
        titleAr: 'معلومات الجهاز الرسمية ورقم الطراز والنظام',
        titleEn: 'About Phone, Model Specs & Build Info',
        subtitleAr: 'استعراض مواصفات المعالج، الرام، إصدار MagicOS/Android، والحالة القانونية',
        icon: Icons.phone_android_rounded,
        color: _cyan,
        statusLabel: _androidVersion,
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'device_info_build',
        recommendationAr:
            'تحقق دورياً من تحديثات النظام والأمان لضمان الحصول على أحدث ترقيعات الحماية.',
        stepsAr: const [
          'اضغط زر "فتح معلومات الهاتف" بالأسفل.',
          'يمكنك مراجعة اسم الجهاز، سعة الرام، إصدار النواة، ورقم الـ IMEI.',
        ],
      ),

      // ==================== 7. DATE, TIME, LANGUAGE & INPUT ====================
      _SystemControlItem(
        id: 'date_time',
        category: 'regional',
        titleAr: 'ضبط الوقت والتاريخ والمنطقة الزمنية',
        titleEn: 'Date, Time & Time Zone Configuration',
        subtitleAr: 'المزامنة التلقائية للوقت عبر الشبكة وتنسيق الساعة (12/24 ساعة)',
        icon: Icons.schedule_rounded,
        color: (_autoTimeEnabled && _autoTimeZoneEnabled) ? _emerald : _amber,
        statusLabel: (_autoTimeEnabled && _autoTimeZoneEnabled)
            ? 'تلقائي عبر الشبكة ✅'
            : 'يدوي (قد يعطل الشهادات) ⚠️',
        isStatusHealthy: _autoTimeEnabled && _autoTimeZoneEnabled,
        supportsDirectAction: false,
        targetKey: 'date_time_settings',
        recommendationAr:
            'إبقاء الوقت والتاريخ على "الضبط التلقائي" ضروري جداً لعمل تطبيقات البنوك، واتساب، ومتجر التطبيقات بدون أخطاء.',
        stepsAr: const [
          'اضغط زر "فتح إعدادات الوقت والتاريخ" بالأسفل.',
          'فعّل مفتاح "الضبط التلقائي للوقت والتاريخ (Set Automatically)".',
          'لتغيير شكل الساعة بين (صباحاً/مساءً) أو (24 ساعة)، بدّل مفتاح "استخدام تنسيق 24 ساعة".',
        ],
      ),
      _SystemControlItem(
        id: 'language_region',
        category: 'regional',
        titleAr: 'لغة الهاتف والمنطقة والأرقام',
        titleEn: 'System Languages & Regional Format',
        subtitleAr: 'إضافة اللغات، تبديل لغة الهاتف بين العربية والإنجليزية، وتنسيق الأرقام',
        icon: Icons.translate_rounded,
        color: _blue,
        statusLabel: 'اللغة والمنطقة',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'locale_language',
        recommendationAr:
            'يمكنك إضافة العربية والإنجليزية معاً والسحب لترتيب اللغة المفضلة في الأعلى.',
        stepsAr: const [
          'اضغط زر "فتح إعدادات اللغة" بالأسفل.',
          'اختر "اللغة والمنطقة (Language and Region)" ثم اضغط "إضافة لغة" إن لم تكن موجودة.',
          'اسحب اللغة التي تريدها إلى المرتبة الأولى (رقم 1) ليتم تطبيقها على النظام فوراً.',
        ],
      ),
      _SystemControlItem(
        id: 'keyboard_input',
        category: 'regional',
        titleAr: 'لوحة المفاتيح والتصحيح التلقائي والكتابة بالصوت',
        titleEn: 'On-Screen Keyboard, Gboard & Autofill',
        subtitleAr: 'تخصيص حجم الكيبورد، اللغات المكتوبة، وإيقاف التصحيح الإملائي المزعج',
        icon: Icons.keyboard_alt_rounded,
        color: _violet,
        statusLabel: 'إعدادات الكيبورد',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'keyboard_input',
        recommendationAr:
            'تفعيل "حافظة النسخ (Clipboard)" في لوحة المفاتيح يسهّل عليك لصق النصوص المنسوخة سابقاً.',
        stepsAr: const [
          'اضغط زر "فتح إعدادات لوحة المفاتيح" بالأسفل.',
          'اضغط على لوحة المفاتيح النشطة (مثل Gboard أو Microsoft SwiftKey).',
          'ادخل إلى "التفضيلات (Preferences)" لإظهار صف الأرقام العلوي أو تعديل ارتفاع اللوحة.',
        ],
      ),

      // ==================== 8. APPS & PERMISSIONS ====================
      _SystemControlItem(
        id: 'manage_all_apps',
        category: 'apps',
        titleAr: 'إدارة جميع التطبيقات ومسح التخزين المؤقت',
        titleEn: 'Installed Apps Manager & Cache Cleaner',
        subtitleAr: 'عرض جميع تطبيقات الهاتف، مسح الـ Cache، أو إيقافها إجبارياً',
        icon: Icons.apps_outage_rounded,
        color: _amber,
        statusLabel: 'مدير التطبيقات',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'manage_all_apps',
        recommendationAr:
            'إذا واجهت بطئاً أو تعليقاً في تطبيق معين، ادخل إلى التخزين الخاص به وامسح "ذاكرة التخزين المؤقت (Clear Cache)" فقط دون مسح البيانات.',
        stepsAr: const [
          'اضغط زر "فتح قائمة التطبيقات" بالأسفل.',
          'ابحث عن التطبيق المطلوب واضغط عليه.',
          'اختر "التخزين (Storage)" ثم اضغط "مسح التخزين المؤقت (Clear Cache)" أو "إيقاف إجباري (Force Stop)".',
        ],
      ),
      _SystemControlItem(
        id: 'default_apps',
        category: 'apps',
        titleAr: 'التطبيقات الافتراضية (المتصفح، الهاتف، الرسائل)',
        titleEn: 'Default Browser, Dialer & SMS Apps',
        subtitleAr: 'تحديد المتصفح الافتراضي لفتح الروابط وتطبيق المكالمات والملفات',
        icon: Icons.verified_user_rounded,
        color: _cyan,
        statusLabel: 'تعيين الافتراضي',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'default_apps',
        recommendationAr:
            'إذا تغير متصفحك أو تطبيق الاتصال فجأة بعد تثبيت برنامج جديد، يمكنك إعادته لوضعه الأصلي من هنا بثوانٍ.',
        stepsAr: const [
          'اضغط زر "فتح التطبيقات الافتراضية" بالأسفل.',
          'اضغط على الفئة التي تريد تعديلها (مثل: تطبيق المتصفح أو تطبيق الهاتف).',
          'اختر تطبيقك المفضل (مثل Chrome أو هاتف النظام الأصلي).',
        ],
      ),
      _SystemControlItem(
        id: 'special_overlay_permissions',
        category: 'apps',
        titleAr: 'أذونات الظهور فوق التطبيقات والنوافذ العائمة',
        titleEn: 'Display Over Other Apps & Special Access',
        subtitleAr: 'منع التطبيقات المشبوهة من رسم إعلانات منبثقة فوق الشاشة',
        icon: Icons.layers_rounded,
        color: _coral,
        statusLabel: 'حماية الشاشة',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'overlay_permission',
        recommendationAr:
            'إذا كانت تظهر لك إعلانات مفاجئة على الشاشة، أوقف إذن "الظهور فوق التطبيقات الأخرى" عن أي تطبيق غير معروف.',
        stepsAr: const [
          'اضغط زر "فتح أذونات الظهور فوق التطبيقات" بالأسفل.',
          'استعرض التطبيقات المسموح لها (Allowed).',
          'أغلق الإذن عن أي تطبيق ألعاب أو أدوات مشبوهة لا تحتاج لنافذة عائمة.',
        ],
      ),

      // ==================== 9. ACCESSIBILITY & STORAGE ====================
      _SystemControlItem(
        id: 'accessibility_tools',
        category: 'accessibility',
        titleAr: 'تسهيلات الاستخدام وتكبير الشاشة والاختصارات',
        titleEn: 'Accessibility, Magnification & One-Handed Mode',
        subtitleAr: 'تكبير النص، قارئ الشاشة، الإيماءات السريعة، ووضع اليد الواحدة',
        icon: Icons.accessibility_new_rounded,
        color: _blue,
        statusLabel: 'تسهيلات النظام',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'accessibility_settings',
        recommendationAr:
            'لا تمنح صلاحية "إمكانية الوصول (Accessibility)" لأي تطبيق مجهول المصدر لأنها تمنحه صلاحية قراءة الشاشة.',
        stepsAr: const [
          'اضغط زر "فتح إعدادات إمكانية الوصول" بالأسفل.',
          'يمكنك تفعيل "التكبير (Magnification)" لتكبير أي جزء من الشاشة بثلاث نقرات.',
          'راجع قسم "الخدمات المثبتة (Installed Services)" وتأكد من وجود التطبيقات الموثوقة فقط.',
        ],
      ),
      _SystemControlItem(
        id: 'internal_storage_system',
        category: 'accessibility',
        titleAr: 'تفاصيل مساحة تخزين النظام والملفات المؤقتة',
        titleEn: 'System Storage Breakdown & OS Cleaner',
        subtitleAr: 'عرض توزيع مساحة التخزين بين النظام، التطبيقات، الصور، والملفات المؤقتة',
        icon: Icons.storage_rounded,
        color: _emerald,
        statusLabel: 'تحليل المساحة',
        isStatusHealthy: true,
        supportsDirectAction: false,
        targetKey: 'internal_storage',
        recommendationAr:
            'إبقاء 15% على الأقل من مساحة الهاتف فارغة يضمن سرعة القراءة والكتابة في الذاكرة الداخلية (UFS).',
        stepsAr: const [
          'اضغط زر "فتح إعدادات تخزين الهاتف" بالأسفل.',
          'انتظر ثوانٍ لحساب المساحة المستخدمة لكل فئة.',
          'اضغط على "تنظيف (Clean Up)" لحذف الملفات المؤقتة وبقايا التطبيقات المحذوفة.',
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final allItems = _buildAllControlItems();
    final filteredItems = allItems.where((item) {
      if (_selectedCategory != 'all' && item.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchAr = item.titleAr.toLowerCase().contains(q) ||
            item.subtitleAr.toLowerCase().contains(q) ||
            item.recommendationAr.toLowerCase().contains(q);
        final matchEn = item.titleEn.toLowerCase().contains(q) ||
            item.statusLabel.toLowerCase().contains(q);
        if (!matchAr && !matchEn) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_cyan, _violet]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'مركز التحكم الشامل • Control Hub',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                  Text(
                    '$_deviceBrand • $_androidVersion',
                    style: const TextStyle(fontSize: 11, color: _textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث حالات النظام',
            onPressed: _refreshHubState,
            icon: const Icon(Icons.refresh_rounded, color: _cyan),
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
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                children: [
                  // 1. DIRECT 1-CLICK QUICK COMMAND COCKPIT
                  _buildQuickCommandCockpit(),
                  const SizedBox(height: 14),

                  // 2. SEARCH BAR
                  _buildSearchBar(),
                  const SizedBox(height: 12),

                  // 3. CATEGORY FILTER PILLS
                  _buildCategoryTabs(allItems),
                  const SizedBox(height: 14),

                  // 4. RESULTS HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الخصائص والإعدادات (${filteredItems.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () {
                          setState(() {
                            if (_expandedGuides.length >= filteredItems.length) {
                              _expandedGuides.clear();
                            } else {
                              for (final i in filteredItems) {
                                _expandedGuides.add(i.id);
                              }
                            }
                          });
                        },
                        icon: Icon(
                          _expandedGuides.length >= filteredItems.length
                              ? Icons.unfold_less_rounded
                              : Icons.unfold_more_rounded,
                          size: 15,
                          color: _cyan,
                        ),
                        label: Text(
                          _expandedGuides.length >= filteredItems.length
                              ? 'طي جميع الإرشادات'
                              : 'عرض جميع الخطوات',
                          style: const TextStyle(fontSize: 11, color: _cyan),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // 5. SETTING CARDS
                  if (filteredItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 38, color: _textSecondary),
                          SizedBox(height: 10),
                          Text(
                            'لا توجد إعدادات مطابقة للبحث الحالي',
                            style: TextStyle(
                                color: _textPrimary,
                                fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'جرّب البحث بكلمات مثل: صوت، شاشة، مطور، بصمة، وقت، خلفية، هونر',
                            style:
                                TextStyle(fontSize: 11.5, color: _textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ...filteredItems.map(_buildControlCard),
                ],
              ),
            ),
    );
  }

  // ==========================================================================
  // TOP COCKPIT: DIRECT 1-CLICK HARDWARE & SYSTEM CONTROLS
  // ==========================================================================
  Widget _buildQuickCommandCockpit() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _cyan.withOpacity(0.12),
            _violet.withOpacity(0.09),
            _card,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cyan.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.flash_on_rounded, color: _cyan, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'لوحة الضبط الفوري بضغطة زر (Direct In-App Controls)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: _emerald.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'LIVE CONTROL',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: _emerald),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 1: Torch, Ringer Mode Cycle, Memory Boost
          Row(
            children: [
              Expanded(
                child: _buildCockpitActionButton(
                  icon: _isTorchOn
                      ? Icons.flashlight_on_rounded
                      : Icons.flashlight_off_rounded,
                  label: 'الكشاف',
                  stateText: _isTorchOn ? 'مفعل ON' : 'مغلق OFF',
                  color: _isTorchOn ? _amber : _cyan,
                  isActive: _isTorchOn,
                  onTap: () => _runDirectControl('toggleTorch', !_isTorchOn),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCockpitActionButton(
                  icon: _ringerMode == 'silent'
                      ? Icons.volume_off_rounded
                      : (_ringerMode == 'vibrate'
                          ? Icons.vibration_rounded
                          : Icons.volume_up_rounded),
                  label: 'وضع الصوت',
                  stateText: _ringerMode == 'silent'
                      ? 'صامت'
                      : (_ringerMode == 'vibrate' ? 'اهتزاز' : 'عام'),
                  color: _ringerMode == 'normal' ? _emerald : _amber,
                  isActive: _ringerMode != 'normal',
                  onTap: () {
                    final next = _ringerMode == 'normal'
                        ? 'vibrate'
                        : (_ringerMode == 'vibrate' ? 'silent' : 'normal');
                    _runDirectControl('setRingerMode', next);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCockpitActionButton(
                  icon: Icons.cleaning_services_rounded,
                  label: 'تنشيط الرام',
                  stateText: 'تفريغ فوري',
                  color: _violet,
                  isActive: false,
                  onTap: () => _runDirectControl('boostSystemMemory'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Instant Brightness Presets
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _cardAlt.withOpacity(0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.brightness_6_rounded,
                        size: 15, color: _amber),
                    const SizedBox(width: 6),
                    Text(
                      'سطوع الشاشة المباشر (${_autoBrightness ? "تلقائي" : "$_brightnessPct%"})',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (!_canWriteSettings)
                      GestureDetector(
                        onTap: () => _openSettingTarget(
                            'write_settings_permission', 'إذن تعديل النظام'),
                        child: const Text(
                          'تفعيل الإذن ⚙️',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: _amber,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    _buildMiniPresetChip(
                      label: 'تلقائي',
                      selected: _autoBrightness,
                      color: _emerald,
                      onTap: () => _runDirectControl('setAutoBrightness', true),
                    ),
                    const SizedBox(width: 6),
                    for (final pct in [25, 50, 75, 100]) ...[
                      Expanded(
                        child: _buildMiniPresetChip(
                          label: '$pct%',
                          selected: !_autoBrightness &&
                              (_brightnessPct - pct).abs() <= 12,
                          color: _amber,
                          onTap: () => _runDirectControl('setBrightness', pct),
                        ),
                      ),
                      if (pct != 100) const SizedBox(width: 6),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCockpitActionButton({
    required IconData icon,
    required String label,
    required String stateText,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.2) : _cardAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : _border,
            width: isActive ? 1.4 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              stateText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPresetChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.22) : _bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : _border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? color : _textSecondary,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // SEARCH BAR & CATEGORY TABS
  // ==========================================================================
  Widget _buildSearchBar() {
    return TextField(
      style: const TextStyle(fontSize: 13, color: _textPrimary),
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintText:
            'ابحث عن أي خاصية (مثال: مطور، وقت، خلفية، كلمة مرور، صوت، هونر)...',
        hintStyle: const TextStyle(fontSize: 12, color: _textSecondary),
        prefixIcon:
            const Icon(Icons.search_rounded, size: 20, color: _cyan),
        filled: true,
        fillColor: _card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _cyan, width: 1.4),
        ),
      ),
      onChanged: (val) => setState(() => _searchQuery = val.trim()),
    );
  }

  Widget _buildCategoryTabs(List<_SystemControlItem> allItems) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat.id;
          final count = cat.id == 'all'
              ? allItems.length
              : allItems.where((i) => i.category == cat.id).length;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedCategory = cat.id),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? cat.color.withOpacity(0.2) : _card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? cat.color : _border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat.icon,
                      size: 15,
                      color: isSelected ? cat.color : _textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? cat.color : _textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: _cardAlt,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? cat.color : _textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==========================================================================
  // INDIVIDUAL SYSTEM CONTROL CARD WITH DIRECT CONTROLS + STEP-BY-STEP GUIDE
  // ==========================================================================
  Widget _buildControlCard(_SystemControlItem item) {
    final isExpanded = _expandedGuides.contains(item.id);
    final statusColor = item.isStatusHealthy ? item.color : _coral;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isStatusHealthy
              ? _border
              : _coral.withOpacity(0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(item.icon, color: item.color, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.titleAr,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.titleEn,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: _cyan,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitleAr,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: _textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  item.statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          // Direct In-Card Action Controls (if supported)
          if (item.supportsDirectAction) ...[
            const SizedBox(height: 12),
            _buildInlineDirectWidget(item),
          ],

          const SizedBox(height: 10),

          // SysPulse Recommendation Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _cardAlt.withOpacity(0.75),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: item.color.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates_rounded,
                    size: 15, color: item.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'توجيه SysPulse: ${item.recommendationAr}',
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

          // Expandable Step-by-Step Guide
          if (isExpanded) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _bg.withOpacity(0.75),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.format_list_numbered_rtl_rounded,
                          size: 15, color: _cyan),
                      SizedBox(width: 6),
                      Text(
                        'خطوات الضبط السهلة خطوة بخطوة:',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _cyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...item.stepsAr.asMap().entries.map((entry) {
                    final stepNum = entry.key + 1;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            margin: const EdgeInsets.only(top: 1, right: 7),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _cyan.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$stepNum',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _cyan,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: _textPrimary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Bottom Action Buttons Row: Toggle Guide + Direct Settings Intent
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedGuides.remove(item.id);
                    } else {
                      _expandedGuides.add(item.id);
                    }
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textSecondary,
                  side: const BorderSide(color: _border),
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.help_outline_rounded,
                  size: 16,
                  color: _cyan,
                ),
                label: Text(
                  isExpanded ? 'إخفاء الخطوات' : 'عرض الخطوات',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      _openSettingTarget(item.targetKey, item.titleAr),
                  style: FilledButton.styleFrom(
                    backgroundColor: item.color.withOpacity(0.22),
                    foregroundColor: item.color,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: item.color.withOpacity(0.5)),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: const Text(
                    'فتح نافذة الإعداد مباشرة ➔',
                    style: TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInlineDirectWidget(_SystemControlItem item) {
    if (item.id == 'ringer_volume') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تحكم مباشر بوضع الصوت ومستوى الوسائط:',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _textSecondary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildMiniPresetChip(
                    label: '🔔 عام',
                    selected: _ringerMode == 'normal',
                    color: _emerald,
                    onTap: () => _runDirectControl('setRingerMode', 'normal'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMiniPresetChip(
                    label: '📳 اهتزاز',
                    selected: _ringerMode == 'vibrate',
                    color: _amber,
                    onTap: () => _runDirectControl('setRingerMode', 'vibrate'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMiniPresetChip(
                    label: '🔕 صامت',
                    selected: _ringerMode == 'silent',
                    color: _coral,
                    onTap: () => _runDirectControl('setRingerMode', 'silent'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('الصوت:',
                    style: TextStyle(fontSize: 10.5, color: _textSecondary)),
                const SizedBox(width: 6),
                for (final v in [0, 25, 50, 75, 100]) ...[
                  Expanded(
                    child: _buildMiniPresetChip(
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ضبط مباشر لمهلة إغلاق الشاشة (Screen Timeout):',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _textSecondary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final sec in [30, 60, 120, 300]) ...[
                  Expanded(
                    child: _buildMiniPresetChip(
                      label: sec < 60 ? '${sec}ث' : '${sec ~/ 60} دقيقة',
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
            backgroundColor:
                (_isTorchOn ? _amber : _cyan).withOpacity(0.18),
            foregroundColor: _isTorchOn ? _amber : _cyan,
          ),
          icon: Icon(_isTorchOn
              ? Icons.flashlight_off_rounded
              : Icons.flashlight_on_rounded),
          label: Text(
            _isTorchOn ? 'إيقاف الكشاف الآن (OFF)' : 'تشغيل الكشاف الآن (ON) 🔦',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
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
            'تنظيف الذاكرة المؤقتة الآن بضغطة زر ⚡',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _HubCategoryMeta {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const _HubCategoryMeta(this.id, this.label, this.icon, this.color);
}

class _SystemControlItem {
  final String id;
  final String category;
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final IconData icon;
  final Color color;
  final String statusLabel;
  final bool isStatusHealthy;
  final bool supportsDirectAction;
  final String targetKey;
  final String recommendationAr;
  final List<String> stepsAr;

  const _SystemControlItem({
    required this.id,
    required this.category,
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.icon,
    required this.color,
    required this.statusLabel,
    required this.isStatusHealthy,
    required this.supportsDirectAction,
    required this.targetKey,
    required this.recommendationAr,
    required this.stepsAr,
  });
}
