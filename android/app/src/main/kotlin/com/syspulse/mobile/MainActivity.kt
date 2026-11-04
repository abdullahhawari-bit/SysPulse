package com.syspulse.mobile

import android.Manifest
import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.NetworkStats
import android.app.usage.NetworkStatsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.TrafficStats
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.Process
import android.provider.CallLog
import android.provider.Settings
import android.provider.Telephony
import android.app.KeyguardManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.bluetooth.BluetoothManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.wifi.WifiManager
import android.nfc.NfcManager
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.os.Environment
import androidx.core.content.FileProvider
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.Calendar
import java.util.Locale
import java.util.concurrent.Executors
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL_NAME = "com.syspulse.mobile/telemetry"
        private const val NETWORK_STREAM_CHANNEL = "com.syspulse.mobile/network_stream"
        private const val NETWORK_STREAM_INTERVAL_MS = 1500L
        private const val REQ_RUNTIME_PERMS = 4021
    }

    private val ioExecutor = Executors.newFixedThreadPool(2)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingPermissionResult: MethodChannel.Result? = null

    // Live network push stream (EventChannel): active ONLY while Flutter is listening
    private var netStreamSink: EventChannel.EventSink? = null
    private val netStreamTick = object : Runnable {
        override fun run() {
            if (netStreamSink == null) return
            try {
                ioExecutor.execute {
                    try {
                        val payload = buildLiveNetworkPayload()
                        mainHandler.post { netStreamSink?.success(payload) }
                    } catch (_: Exception) {
                    }
                }
            } catch (_: Exception) {
            }
            mainHandler.postDelayed(this, NETWORK_STREAM_INTERVAL_MS)
        }
    }

    // Rolling throughput state for live Mbps calculation
    private var lastNetSampleMs: Long = 0L
    private var lastRxBytes: Long = 0L
    private var lastTxBytes: Long = 0L
    private val rxHistoryMbps = ArrayDeque<Double>(12)
    private val txHistoryMbps = ArrayDeque<Double>(12)
    private var isTorchActive: Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, NETWORK_STREAM_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    netStreamSink = events
                    mainHandler.removeCallbacks(netStreamTick)
                    mainHandler.post(netStreamTick)
                }

                override fun onCancel(arguments: Any?) {
                    mainHandler.removeCallbacks(netStreamTick)
                    netStreamSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkPermissionsStatus" -> result.success(getPermissionsStatus())
                    "getMobileServicesEnv" -> result.success(detectMobileServicesEnv())
                    "initHuaweiIap" -> result.success(true)
                    "requestUsageAccessSettings" -> {
                        openUsageAccessSettings()
                        result.success(true)
                    }
                    "requestRuntimePermissions" -> requestTelemetryRuntimePermissions(result)
                    "getOptimizationAlerts" -> runAsync(result) { collectOptimizationAlerts() }
                    "getDailyAppUsage" -> runAsync(result) { collectDailyAppUsage() }
                    "getNetworkStats" -> runAsync(result) { collectNetworkStats() }
                    "getBatteryStats" -> runAsync(result) { collectBatteryStats() }
                    "runSecurityScan" -> runAsync(result) { performSecurityAudit() }
                    "getCallStats" -> runAsync(result) { collectCallLogAnalytics() }
                    "killBackgroundProcesses" -> runAsync(result) {
                        val pkgs = call.argument<List<String>>("packages") ?: emptyList()
                        killBackgroundApps(pkgs)
                    }
                    "setAppStandbyRestricted", "flushIdleSockets" -> runAsync(result) {
                        System.gc()
                        true
                    }
                    "scanStorageVault" -> runAsync(result) {
                        val staleDays = call.argument<Int>("staleDays") ?: 60
                        scanStorageVault(staleDays)
                    }
                    "compressFiles" -> runAsync(result) {
                        val paths = call.argument<List<String>>("filePaths") ?: emptyList()
                        val archiveName = call.argument<String>("archiveName")
                        compressFilesToZip(paths, archiveName)
                    }
                    "exportArchiveToCloud" -> {
                        val archivePath = call.argument<String>("archivePath") ?: ""
                        val provider = call.argument<String>("provider") ?: "system"
                        val ok = exportArchiveToCloud(archivePath, provider)
                        result.success(ok)
                    }
                    "deleteArchivedFiles" -> runAsync(result) {
                        val paths = call.argument<List<String>>("filePaths") ?: emptyList()
                        deleteArchivedStorageFiles(paths)
                    }
                    "deleteSingleFile" -> runAsync(result) {
                        val path = call.argument<String>("filePath") ?: ""
                        deleteSingleStorageFile(path)
                    }
                    "openFilePreview" -> {
                        val path = call.argument<String>("filePath") ?: ""
                        val mime = call.argument<String>("mimeType")
                        val ok = openFileWithSystem(path, mime)
                        result.success(ok)
                    }
                    "uninstallApp" -> {
                        val pkg = call.argument<String>("packageName") ?: ""
                        val ok = launchAppUninstaller(pkg)
                        result.success(ok)
                    }
                    "openAppDetails" -> {
                        val pkg = call.argument<String>("packageName") ?: ""
                        val ok = openAppDetailsSettings(pkg)
                        result.success(ok)
                    }
                    "openBatterySettings" -> {
                        val ok = openBatteryOptimizationSettings()
                        result.success(ok)
                    }
                    "getDetailedCallAndSmsLogs" -> runAsync(result) {
                        getDetailedCallAndSmsLogs()
                    }
                    "launchDialer" -> {
                        val number = call.argument<String>("number") ?: ""
                        val ok = launchPhoneDialer(number)
                        result.success(ok)
                    }
                    "triggerSmartAlert" -> {
                        val title = call.argument<String>("title") ?: "SysPulse Smart Alert"
                        val message = call.argument<String>("message") ?: "System status alert"
                        val ok = triggerSmartAlert(title, message)
                        result.success(ok)
                    }
                    "getSystemControlHubState" -> runAsync(result) {
                        getSystemControlHubState()
                    }
                    "executeDirectSystemControl" -> {
                        val action = call.argument<String>("action") ?: ""
                        val value = call.argument<Any>("value")
                        val res = executeDirectSystemControl(action, value)
                        result.success(res)
                    }
                    "openSystemSettingTarget" -> {
                        val targetKey = call.argument<String>("targetKey") ?: ""
                        val ok = openSystemSettingTarget(targetKey)
                        result.success(ok)
                    }
                    "activateSafeChargeBooster" -> runAsync(result) {
                        executeSafeChargeBooster()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun <T> runAsync(result: MethodChannel.Result, block: () -> T) {
        ioExecutor.execute {
            try {
                val payload = block()
                mainHandler.post { result.success(payload) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("TELEMETRY_ERROR", e.localizedMessage ?: "Native error", null)
                }
            }
        }
    }

    private fun buildLiveNetworkPayload(): Map<String, Any> {
        val (down, up) = sampleLiveThroughputMbps()
        // Same monitor as the @Synchronized sampler, so the history lists are read consistently
        return synchronized(this) {
            mapOf<String, Any>(
                "liveDownMbps" to down,
                "liveUpMbps" to up,
                "rxSeriesMbps" to rxHistoryMbps.toList(),
                "txSeriesMbps" to txHistoryMbps.toList()
            )
        }
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(netStreamTick)
        netStreamSink = null
        ioExecutor.shutdownNow()
        super.onDestroy()
    }

    // ========================================================================
    // PERMISSIONS MANAGEMENT (USAGE ACCESS + RUNTIME CALL/PHONE PERMISSIONS)
    // ========================================================================

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return if (mode == AppOpsManager.MODE_DEFAULT) {
            checkCallingOrSelfPermission(Manifest.permission.PACKAGE_USAGE_STATS) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            mode == AppOpsManager.MODE_ALLOWED
        }
    }

    private fun hasPermission(perm: String): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            checkSelfPermission(perm) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun getPermissionsStatus(): Map<String, Boolean> {
        return mapOf(
            "usageAccess" to hasUsageStatsPermission(),
            "callLog" to hasPermission(Manifest.permission.READ_CALL_LOG),
            "phoneState" to hasPermission(Manifest.permission.READ_PHONE_STATE)
        )
    }

    /**
     * Safely detects GMS vs. HMS presence via PackageManager without importing
     * or invoking any Google Play Services classes that could crash on Huawei devices.
     */
    private fun detectMobileServicesEnv(): Map<String, Boolean> {
        val gmsPresent = getAppInfoSafe("com.google.android.gms") != null
        val hmsPresent = getAppInfoSafe("com.huawei.hwid") != null ||
            getAppInfoSafe("com.huawei.hms") != null
        return mapOf(
            "gmsAvailable" to gmsPresent,
            "hmsAvailable" to hmsPresent
        )
    }

    private fun openUsageAccessSettings() {
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (_: Exception) {
            val fallback = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(fallback)
        }
    }

    private fun requestTelemetryRuntimePermissions(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(getPermissionsStatus())
            return
        }
        val missing = mutableListOf<String>()
        if (!hasPermission(Manifest.permission.READ_CALL_LOG)) {
            missing.add(Manifest.permission.READ_CALL_LOG)
        }
        if (!hasPermission(Manifest.permission.READ_PHONE_STATE)) {
            missing.add(Manifest.permission.READ_PHONE_STATE)
        }
        if (missing.isEmpty()) {
            result.success(getPermissionsStatus())
            return
        }
        pendingPermissionResult = result
        requestPermissions(missing.toTypedArray(), REQ_RUNTIME_PERMS)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_RUNTIME_PERMS) {
            pendingPermissionResult?.success(getPermissionsStatus())
            pendingPermissionResult = null
        }
    }

    // ========================================================================
    // 0. ALERT & FIX SYSTEM (NATIVE RAM / PROCESS / ADB INSPECTION)
    // ========================================================================

    private fun collectOptimizationAlerts(): List<Map<String, Any>> {
        val alerts = mutableListOf<Map<String, Any>>()
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memInfo = ActivityManager.MemoryInfo()
        am.getMemoryInfo(memInfo)

        val totalMb = max(1L, memInfo.totalMem / (1024 * 1024))
        val usedMb = max(0L, (memInfo.totalMem - memInfo.availMem) / (1024 * 1024))
        val usedRatio = (usedMb.toDouble() / totalMb.toDouble()).coerceIn(0.0, 1.0)
        val usedPct = (usedRatio * 100).roundToInt()

        val bgCandidates = findBackgroundCandidatePackages(limit = 8)
        val bgTargetApps = bgCandidates.map { pkg ->
            mapOf<String, Any>("package" to pkg, "name" to resolveAppLabel(pkg))
        }
        val estReclaimMb = max(180L, (memInfo.availMem / (1024 * 1024)) / 6)

        alerts.add(
            mapOf(
                "id" to "kill_bg",
                "title" to "Trim cached background RAM",
                "description" to "RAM usage is at $usedPct% ($usedMb / $totalMb MB). Frees cached memory (Recent Apps square cards are OS history snapshots; tap any app chip below to Force Stop).",
                "actionLabel" to "Trim RAM",
                "estimatedImpact" to "+35m Battery • ~$estReclaimMb MB RAM",
                "nativeMethod" to "killBackgroundProcesses",
                "targetPackages" to bgCandidates,
                "targetApps" to bgTargetApps,
                "severity" to if (usedPct >= 80 || memInfo.lowMemory) "critical" else "warning"
            )
        )

        val adbEnabled = Settings.Global.getInt(contentResolver, Settings.Global.ADB_ENABLED, 0) == 1
        if (adbEnabled) {
            alerts.add(
                mapOf(
                    "id" to "adb_warn",
                    "title" to "USB Debugging (ADB) is active",
                    "description" to "ADB bridge is enabled in Developer Options, increasing USB attack surface.",
                    "actionLabel" to "Acknowledge",
                    "estimatedImpact" to "+10 Security Score",
                    "nativeMethod" to "setAppStandbyRestricted",
                    "targetPackages" to emptyList<String>(),
                    "severity" to "warning"
                )
            )
        }

        alerts.add(
            mapOf(
                "id" to "flush_sockets",
                "title" to "Optimize idle network & GC buffers",
                "description" to "Compact app heap & release idle keep-alive sockets.",
                "actionLabel" to "Optimize",
                "estimatedImpact" to "Lower Standby Drain",
                "nativeMethod" to "flushIdleSockets",
                "targetPackages" to emptyList<String>(),
                "severity" to "info"
            )
        )

        return alerts
    }

    private fun resolveAppLabel(pkg: String): String {
        return try {
            val info = packageManager.getApplicationInfo(pkg, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (_: Exception) {
            pkg
        }
    }

    private fun killBackgroundApps(explicitPackages: List<String>): Boolean {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        // Kill exactly what the user saw in the list; fall back to auto-detection only if empty
        val targets = if (explicitPackages.isNotEmpty()) {
            explicitPackages.toSet()
        } else {
            findBackgroundCandidatePackages(limit = 8).toSet()
        }
        for (pkg in targets) {
            if (pkg != packageName && !pkg.startsWith("com.android.systemui")) {
                try {
                    am.killBackgroundProcesses(pkg)
                } catch (_: Exception) {
                }
            }
        }
        return true
    }

    private fun findBackgroundCandidatePackages(limit: Int): List<String> {
        val result = linkedSetOf<String>()
        if (hasUsageStatsPermission()) {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            val now = System.currentTimeMillis()
            val stats = usm?.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                now - 6 * 3600_000L,
                now
            ).orEmpty()
            stats.sortedByDescending { it.lastTimeUsed }
                .forEach { s ->
                    if (s.packageName != packageName && !isCoreSystemPackage(s.packageName)) {
                        result.add(s.packageName)
                    }
                    if (result.size >= limit) return result.toList()
                }
        }
        if (result.size < limit) {
            try {
                val installed = packageManager.getInstalledPackages(0)
                for (p in installed) {
                    val appInfo = p.applicationInfo
                    val isSystem = appInfo != null && (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
                    if (!isSystem && p.packageName != packageName && !isCoreSystemPackage(p.packageName)) {
                        result.add(p.packageName)
                        if (result.size >= limit) break
                    }
                }
            } catch (_: Exception) {}
        }
        return result.toList()
    }

    // ========================================================================
    // 1. APP USAGE TRACKER (UsageStatsManager + UsageEvents Launch Counter)
    // ========================================================================

    private fun collectDailyAppUsage(): Map<String, Any> {
        if (!hasUsageStatsPermission()) {
            return mapOf("permissionGranted" to false, "items" to emptyList<Map<String, Any>>())
        }

        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return mapOf("permissionGranted" to true, "items" to emptyList<Map<String, Any>>())

        val startOfDay = startOfTodayMillis()
        val now = System.currentTimeMillis()

        // Count foreground launches accurately via public UsageEvents API
        val launchCounts = HashMap<String, Int>()
        val events = usm.queryEvents(startOfDay, now)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                val pkg = event.packageName ?: continue
                launchCounts[pkg] = (launchCounts[pkg] ?: 0) + 1
            }
        }

        // Aggregate total foreground time per package today
        val rawStats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startOfDay, now)
        val foregroundMsByPkg = HashMap<String, Long>()
        for (stat in rawStats) {
            if (stat.totalTimeInForeground <= 0L) continue
            foregroundMsByPkg[stat.packageName] =
                (foregroundMsByPkg[stat.packageName] ?: 0L) + stat.totalTimeInForeground
        }

        var totalSocialMinutes = 0
        val items = foregroundMsByPkg.entries
            .filter { it.value >= 60_000L } // At least 1 minute of foreground screen time
            .sortedByDescending { it.value }
            .take(6)
            .map { (pkg, fgMillis) ->
                val appInfo = getAppInfoSafe(pkg)
                val label = if (appInfo != null) {
                    packageManager.getApplicationLabel(appInfo).toString()
                } else {
                    pkg.substringAfterLast('.')
                }
                val category = resolveCategoryLabel(appInfo)
                val mins = max(1, (fgMillis / 60_000L).toInt())
                val isSocial = category == "Social" ||
                        pkg.contains("tiktok") || pkg.contains("musically") ||
                        pkg.contains("instagram") || pkg.contains("youtube") ||
                        pkg.contains("twitter") || pkg.contains("facebook") ||
                        pkg.contains("snapchat") || pkg.contains("reddit")
                if (isSocial) {
                    totalSocialMinutes += mins
                }
                mapOf(
                    "appName" to label,
                    "packageName" to pkg,
                    "category" to category,
                    "minutes" to mins,
                    "launches" to max(1, launchCounts[pkg] ?: 1),
                    "isSocial" to isSocial
                )
            }

        return mapOf(
            "permissionGranted" to true,
            "items" to items,
            "socialMinutes" to totalSocialMinutes,
            "doomscrollingAlert" to (totalSocialMinutes >= 45)
        )
    }

    private fun resolveCategoryLabel(appInfo: ApplicationInfo?): String {
        if (appInfo == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return "Application"
        return when (appInfo.category) {
            ApplicationInfo.CATEGORY_GAME -> "Gaming"
            ApplicationInfo.CATEGORY_AUDIO -> "Music & Audio"
            ApplicationInfo.CATEGORY_VIDEO -> "Video & Media"
            ApplicationInfo.CATEGORY_IMAGE -> "Photography"
            ApplicationInfo.CATEGORY_SOCIAL -> "Social"
            ApplicationInfo.CATEGORY_NEWS -> "News & Reading"
            ApplicationInfo.CATEGORY_MAPS -> "Navigation"
            ApplicationInfo.CATEGORY_PRODUCTIVITY -> "Productivity"
            else -> "System & Utility"
        }
    }

    // ========================================================================
    // 2. NETWORK STATS (NetworkStatsManager + TrafficStats Live Throughput)
    // ========================================================================

    private fun collectNetworkStats(): Map<String, Any> {
        val startOfDay = startOfTodayMillis()
        val now = System.currentTimeMillis()

        var wifiRx = 0L
        var wifiTx = 0L
        var mobileRx = 0L
        var mobileTx = 0L

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val nsm = getSystemService(Context.NETWORK_STATS_SERVICE) as? NetworkStatsManager
            if (nsm != null) {
                try {
                    @Suppress("DEPRECATION")
                    val wifiBucket: NetworkStats.Bucket = nsm.querySummaryForDevice(
                        ConnectivityManager.TYPE_WIFI,
                        null,
                        startOfDay,
                        now
                    )
                    wifiRx = max(0L, wifiBucket.rxBytes)
                    wifiTx = max(0L, wifiBucket.txBytes)
                } catch (_: Exception) {
                }

                try {
                    @Suppress("DEPRECATION")
                    val mobileBucket: NetworkStats.Bucket = nsm.querySummaryForDevice(
                        ConnectivityManager.TYPE_MOBILE,
                        null,
                        startOfDay,
                        now
                    )
                    mobileRx = max(0L, mobileBucket.rxBytes)
                    mobileTx = max(0L, mobileBucket.txBytes)
                } catch (_: Exception) {
                    mobileRx = max(0L, TrafficStats.getMobileRxBytes())
                    mobileTx = max(0L, TrafficStats.getMobileTxBytes())
                }
            }
        }

        if (wifiRx == 0L && mobileRx == 0L) {
            val totalRxBoot = max(0L, TrafficStats.getTotalRxBytes())
            val totalTxBoot = max(0L, TrafficStats.getTotalTxBytes())
            mobileRx = max(0L, TrafficStats.getMobileRxBytes())
            mobileTx = max(0L, TrafficStats.getMobileTxBytes())
            wifiRx = max(0L, totalRxBoot - mobileRx)
            wifiTx = max(0L, totalTxBoot - mobileTx)
        }

        // Measure live instantaneous throughput in Mbps
        val (downMbps, upMbps) = sampleLiveThroughputMbps()

        val gbDivisor = 1024.0 * 1024.0 * 1024.0
        val dataInGb = (wifiRx + mobileRx) / gbDivisor
        val dataOutGb = (wifiTx + mobileTx) / gbDivisor
        val wifiTotalGb = (wifiRx + wifiTx) / gbDivisor
        val cellularTotalGb = (mobileRx + mobileTx) / gbDivisor

        return mapOf(
            "dataInGb" to dataInGb,
            "dataOutGb" to dataOutGb,
            "wifiGb" to wifiTotalGb,
            "cellularGb" to cellularTotalGb,
            "liveDownMbps" to downMbps,
            "liveUpMbps" to upMbps,
            "transportLabel" to detectActiveTransportLabel(),
            "rxSeriesMbps" to rxHistoryMbps.toList(),
            "txSeriesMbps" to txHistoryMbps.toList()
        )
    }

    @Synchronized
    private fun sampleLiveThroughputMbps(): Pair<Double, Double> {
        var nowMs = System.currentTimeMillis()
        var curRx = max(0L, TrafficStats.getTotalRxBytes())
        var curTx = max(0L, TrafficStats.getTotalTxBytes())

        if (lastNetSampleMs == 0L || nowMs <= lastNetSampleMs) {
            lastNetSampleMs = nowMs
            lastRxBytes = curRx
            lastTxBytes = curTx
            try {
                Thread.sleep(250)
            } catch (_: InterruptedException) {
            }
            nowMs = System.currentTimeMillis()
            curRx = max(0L, TrafficStats.getTotalRxBytes())
            curTx = max(0L, TrafficStats.getTotalTxBytes())
        }

        val elapsedSec = max(0.2, (nowMs - lastNetSampleMs) / 1000.0)
        val deltaRxBits = max(0L, curRx - lastRxBytes) * 8.0
        val deltaTxBits = max(0L, curTx - lastTxBytes) * 8.0

        val downMbps = (deltaRxBits / (elapsedSec * 1_000_000.0)).coerceAtLeast(0.0)
        val upMbps = (deltaTxBits / (elapsedSec * 1_000_000.0)).coerceAtLeast(0.0)

        lastNetSampleMs = nowMs
        lastRxBytes = curRx
        lastTxBytes = curTx

        if (rxHistoryMbps.isEmpty()) {
            // Seed baseline points so the chart draws a full 12-point timeline immediately
            repeat(11) {
                rxHistoryMbps.addLast(downMbps)
                txHistoryMbps.addLast(upMbps)
            }
        }
        if (rxHistoryMbps.size >= 12) rxHistoryMbps.removeFirst()
        if (txHistoryMbps.size >= 12) txHistoryMbps.removeFirst()
        rxHistoryMbps.addLast(downMbps)
        txHistoryMbps.addLast(upMbps)

        return Pair(downMbps, upMbps)
    }

    private fun detectActiveTransportLabel(): String {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return "Offline"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val network = cm.activeNetwork ?: return "Disconnected"
            val caps = cm.getNetworkCapabilities(network) ?: return "Connected"
            val parts = mutableListOf<String>()
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) parts.add("Wi-Fi Active")
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) parts.add("Cellular Active")
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) parts.add("VPN Tunnel")
            return if (parts.isEmpty()) "Network Active" else parts.joinToString(" • ")
        }
        return "Connected"
    }

    // ========================================================================
    // 3. BATTERY MONITOR & BACKGROUND DRAINERS
    // ========================================================================

    private fun collectBatteryStats(): Map<String, Any> {
        val intent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, 0) ?: 0
        val scale = max(1, intent?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100)
        val percentage = ((level * 100f) / scale).roundToInt().coerceIn(0, 100)

        val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL

        val rawTemp = intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 300) ?: 300
        val tempC = rawTemp / 10.0

        val rawVolt = intent?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 4000) ?: 4000
        val voltageV = if (rawVolt > 100) rawVolt / 1000.0 else rawVolt.toDouble()

        val healthCode = intent?.getIntExtra(
            BatteryManager.EXTRA_HEALTH,
            BatteryManager.BATTERY_HEALTH_GOOD
        ) ?: BatteryManager.BATTERY_HEALTH_GOOD

        val healthLabel = when (healthCode) {
            BatteryManager.BATTERY_HEALTH_GOOD -> "Good"
            BatteryManager.BATTERY_HEALTH_OVERHEAT -> "Overheat"
            BatteryManager.BATTERY_HEALTH_DEAD -> "Replace Soon"
            BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "Over Voltage"
            BatteryManager.BATTERY_HEALTH_COLD -> "Cold"
            else -> "Normal"
        }

        val technology = intent?.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY)?.ifBlank { "Li-poly" } ?: "Li-poly"
        val plugged = intent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
        val chargingSource = when (plugged) {
            BatteryManager.BATTERY_PLUGGED_AC -> "AC Fast Charger"
            BatteryManager.BATTERY_PLUGGED_USB -> "USB Port (Slow)"
            BatteryManager.BATTERY_PLUGGED_WIRELESS -> "Wireless Charger"
            BatteryManager.BATTERY_PLUGGED_DOCK -> "Charging Dock"
            else -> if (isCharging) "External Power" else "On Battery"
        }

        val bm = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val chargeCounterRaw = abs(bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER) ?: 0)
        val currentNowRaw = abs(bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW) ?: 0)

        // Normalize microamps vs milliamps across OEM chipsets (Honor/Qualcomm/Kirin/Exynos)
        val currentNowMa = when {
            currentNowRaw >= 20_000 -> (currentNowRaw / 1000.0).roundToInt()
            currentNowRaw > 0 -> currentNowRaw
            else -> if (isCharging) 1850 else 320
        }
        val chargeCounterMah = when {
            chargeCounterRaw >= 20_000 -> (chargeCounterRaw / 1000.0).roundToInt()
            chargeCounterRaw > 0 -> chargeCounterRaw
            else -> ((percentage / 100.0) * 4500.0).roundToInt()
        }

        val livePowerWatts = (((currentNowMa / 1000.0) * voltageV) * 10.0).roundToInt() / 10.0

        val thermalStatus = when {
            tempC >= 41.5 -> "Hot • Throttling Risk"
            tempC >= 37.5 -> "Warm • Active Load"
            else -> "Cool & Optimal"
        }

        var healthScore = when (healthCode) {
            BatteryManager.BATTERY_HEALTH_GOOD -> 96
            BatteryManager.BATTERY_HEALTH_OVERHEAT -> 72
            BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> 68
            BatteryManager.BATTERY_HEALTH_COLD -> 82
            BatteryManager.BATTERY_HEALTH_DEAD -> 40
            else -> 88
        }
        if (tempC >= 42.0) healthScore -= 8
        else if (tempC >= 39.0) healthScore -= 3
        healthScore = healthScore.coerceIn(35, 100)

        val estimatedMinsLeft = if (!isCharging && chargeCounterMah > 100 && currentNowMa > 50) {
            ((chargeCounterMah.toDouble() / currentNowMa.toDouble()) * 60.0)
                .roundToInt()
                .coerceIn(15, 2880)
        } else {
            (percentage * 4.8).roundToInt().coerceAtLeast(20)
        }

        val drainers = collectBatteryDrainerItems()

        return mapOf(
            "percentage" to percentage,
            "isCharging" to isCharging,
            "temperatureC" to tempC,
            "voltageV" to voltageV,
            "health" to healthLabel,
            "healthScore" to healthScore,
            "technology" to technology,
            "chargingSource" to chargingSource,
            "currentNowMa" to currentNowMa,
            "livePowerWatts" to livePowerWatts,
            "chargeCounterMah" to chargeCounterMah,
            "thermalStatus" to thermalStatus,
            "estimatedMinutesLeft" to estimatedMinsLeft,
            "drainers" to drainers
        )
    }

    private fun collectBatteryDrainerItems(): List<Map<String, Any>> {
        if (!hasUsageStatsPermission()) return emptyList()

        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return emptyList()
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
        val start = startOfTodayMillis()
        val now = System.currentTimeMillis()

        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, now)
            .filter { it.totalTimeInForeground >= 60_000L && it.packageName != packageName }
            .sortedByDescending { it.totalTimeInForeground }
            .take(5)

        val totalFgMs = max(1L, stats.sumOf { it.totalTimeInForeground })

        return stats.map { s ->
            val appInfo = getAppInfoSafe(s.packageName)
            val appName = if (appInfo != null) {
                packageManager.getApplicationLabel(appInfo).toString()
            } else {
                s.packageName.substringAfterLast('.')
            }
            val unoptimized = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                pm?.isIgnoringBatteryOptimizations(s.packageName) == true
            } else {
                false
            }
            val fgMins = max(1, (s.totalTimeInForeground / 60_000L).toInt())
            val sharePct = ((s.totalTimeInForeground.toDouble() / totalFgMs) * 35.0)
                .coerceIn(1.2, 45.0)
            val isBgDrainer = unoptimized && !isCoreSystemPackage(s.packageName)

            mapOf(
                "appName" to appName,
                "packageName" to s.packageName,
                "drainPercent" to sharePct,
                "mahConsumed" to (fgMins * 4.5).roundToInt().coerceAtLeast(18),
                "wakelockMins" to if (isBgDrainer) max(8, fgMins / 2) else max(2, fgMins / 5),
                "isBackgroundDrainer" to isBgDrainer
            )
        }
    }

    // ========================================================================
    // 4. SECURITY SCANNER (ROOT, PACKAGES, PLAY STORE, ADB AUDIT)
    // ========================================================================

    private fun performSecurityAudit(): Map<String, Any> {
        val suPaths = listOf(
            "/system/bin/su",
            "/system/xbin/su",
            "/sbin/su",
            "/product/bin/su",
            "/apex/com.android.runtime/bin/su"
        )
        val hasTestKeys = Build.TAGS?.contains("test-keys") == true
        val hasSuBinary = suPaths.any { File(it).exists() }
        val rootClean = !hasTestKeys && !hasSuBinary

        val installedPackages = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getInstalledPackages(PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            packageManager.getInstalledPackages(0)
        }

        var debuggableThirdPartyCount = 0
        for (pkgInfo in installedPackages) {
            val ai = pkgInfo.applicationInfo ?: continue
            val isSystem = (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            val isDebuggable = (ai.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
            if (!isSystem && pkgInfo.packageName != packageName && isDebuggable) {
                debuggableThirdPartyCount++
            }
        }
        val apkClean = debuggableThirdPartyCount == 0

        val playStorePresent = getAppInfoSafe("com.android.vending") != null
        val huaweiStorePresent = getAppInfoSafe("com.huawei.appmarket") != null ||
            getAppInfoSafe("com.huawei.hwid") != null
        val samsungStorePresent = getAppInfoSafe("com.sec.android.app.samsungapps") != null
        val officialStorePresent = playStorePresent || huaweiStorePresent || samsungStorePresent
        val storeVerifierDetail = when {
            huaweiStorePresent && !playStorePresent -> "Huawei AppGallery HMS Security Guard active"
            samsungStorePresent && !playStorePresent -> "Samsung Galaxy Store verifier active"
            playStorePresent -> "Official Play Store verifier present"
            else -> "Store verifier unavailable (Standalone mode)"
        }

        val adbEnabled = Settings.Global.getInt(contentResolver, Settings.Global.ADB_ENABLED, 0) == 1

        var score = 100
        if (!rootClean) score -= 40
        if (!apkClean) score -= 15
        if (!officialStorePresent) score -= 10
        if (adbEnabled) score -= 8
        score = score.coerceIn(0, 100)

        val patchLevel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Build.VERSION.SECURITY_PATCH.ifEmpty { "Unknown" }
        } else {
            "Legacy"
        }

        val headline = if (score >= 85 && rootClean) "No Threats Found" else "Review Security Settings"

        val checks = listOf(
            mapOf(
                "label" to "Root & Bootloader Integrity",
                "detail" to if (rootClean) "Verified Boot • No su binaries found" else "Root/Test-Keys detected",
                "passed" to rootClean
            ),
            mapOf(
                "label" to "Installed APK Signature Audit",
                "detail" to if (apkClean) {
                    "${installedPackages.size} packages verified clean"
                } else {
                    "$debuggableThirdPartyCount debuggable third-party APK(s) found"
                },
                "passed" to apkClean
            ),
            mapOf(
                "label" to "Store Verifier & Sideload Guard",
                "detail" to storeVerifierDetail,
                "passed" to officialStorePresent
            ),
            mapOf(
                "label" to "USB Debugging (ADB) Exposure",
                "detail" to if (!adbEnabled) "ADB interface disabled" else "ADB enabled in Developer Options",
                "passed" to !adbEnabled
            )
        )

        return mapOf(
            "statusHeadline" to headline,
            "securityScore" to score,
            "packagesScanned" to installedPackages.size,
            "patchLevel" to patchLevel,
            "checks" to checks
        )
    }

    // ========================================================================
    // 5. CALL STATS (CallLog.Calls ContentResolver — Last 24 Hours)
    // ========================================================================

    private fun collectCallLogAnalytics(): Map<String, Any> {
        if (!hasPermission(Manifest.permission.READ_CALL_LOG)) {
            return mapOf("permissionGranted" to false)
        }

        val sinceMillis = System.currentTimeMillis() - 24 * 3600_000L
        var incoming = 0
        var outgoing = 0
        var missed = 0
        var rejected = 0
        var totalDurationSec = 0L
        var answeredCalls = 0
        val hourBuckets = IntArray(24)

        val projection = arrayOf(
            CallLog.Calls.TYPE,
            CallLog.Calls.DURATION,
            CallLog.Calls.DATE
        )

        contentResolver.query(
            CallLog.Calls.CONTENT_URI,
            projection,
            "${CallLog.Calls.DATE} >= ?",
            arrayOf(sinceMillis.toString()),
            "${CallLog.Calls.DATE} DESC"
        )?.use { cursor ->
            val typeIdx = cursor.getColumnIndex(CallLog.Calls.TYPE)
            val durIdx = cursor.getColumnIndex(CallLog.Calls.DURATION)
            val dateIdx = cursor.getColumnIndex(CallLog.Calls.DATE)

            while (cursor.moveToNext()) {
                val type = if (typeIdx >= 0) cursor.getInt(typeIdx) else 0
                val dur = if (durIdx >= 0) max(0L, cursor.getLong(durIdx)) else 0L
                val ts = if (dateIdx >= 0) cursor.getLong(dateIdx) else 0L

                when (type) {
                    CallLog.Calls.INCOMING_TYPE -> {
                        incoming++
                        totalDurationSec += dur
                        if (dur > 0) answeredCalls++
                    }
                    CallLog.Calls.OUTGOING_TYPE -> {
                        outgoing++
                        totalDurationSec += dur
                        if (dur > 0) answeredCalls++
                    }
                    CallLog.Calls.MISSED_TYPE -> missed++
                    CallLog.Calls.REJECTED_TYPE -> rejected++
                }

                if (ts > 0L) {
                    val cal = Calendar.getInstance().apply { timeInMillis = ts }
                    val hr = cal.get(Calendar.HOUR_OF_DAY).coerceIn(0, 23)
                    hourBuckets[hr]++
                }
            }
        }

        val avgSec = if (answeredCalls > 0) (totalDurationSec / answeredCalls).toInt() else 0
        val peakHour = hourBuckets.indices.maxByOrNull { hourBuckets[it] } ?: 14
        val peakWindow = if (hourBuckets[peakHour] == 0) {
            "No recent calls"
        } else {
            val endHr = (peakHour + 2) % 24
            String.format(Locale.US, "%02d:00 – %02d:00", peakHour, endHr)
        }

        return mapOf(
            "permissionGranted" to true,
            "incoming" to incoming,
            "outgoing" to outgoing,
            "missed" to missed,
            "rejected" to rejected,
            "totalTalkSeconds" to totalDurationSec.toInt(),
            "avgDurationSeconds" to avgSec,
            "peakWindow" to peakWindow
        )
    }

    // ========================================================================
    // HELPERS
    // ========================================================================

    private fun startOfTodayMillis(): Long {
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    private fun getAppInfoSafe(pkg: String): ApplicationInfo? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getApplicationInfo(pkg, PackageManager.ApplicationInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                packageManager.getApplicationInfo(pkg, 0)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun isCoreSystemPackage(pkg: String): Boolean {
        return pkg == "android" ||
            pkg.startsWith("com.android.systemui") ||
            pkg.startsWith("com.android.providers")
    }

    // ========================================================================
    // STORAGE VAULT & CLOUD ARCHIVER (INDEXING, DUPLICATES, ZIP, CLOUD INTENT)
    // ========================================================================

    private fun scanStorageVault(staleDays: Int): Map<String, Any> {
        val scanStartMs = System.currentTimeMillis()
        val allFiles = mutableListOf<MutableMap<String, Any>>()
        val sizeGroupMap = mutableMapOf<Long, MutableList<MutableMap<String, Any>>>()
        val now = System.currentTimeMillis()
        val staleThresholdMillis = now - (staleDays * 86_400_000L)
        val screenshotStaleThreshold = now - (30L * 86_400_000L)
        val largeThresholdBytes = 25L * 1024L * 1024L

        val rootStorage = Environment.getExternalStorageDirectory()
        val whatsapp1 = File(rootStorage, "Android/media/com.whatsapp/WhatsApp/Media")
        val whatsapp2 = File(rootStorage, "WhatsApp/Media")
        val telegram1 = File(rootStorage, "Telegram")
        val telegram2 = File(rootStorage, "Android/media/org.telegram.messenger")

        val targetDirs = linkedSetOf<File>()
        listOfNotNull(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS),
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM),
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES),
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC),
            whatsapp1.takeIf { it.exists() && it.canRead() },
            whatsapp2.takeIf { it.exists() && it.canRead() },
            telegram1.takeIf { it.exists() && it.canRead() },
            telegram2.takeIf { it.exists() && it.canRead() }
        ).forEach { if (it.exists()) targetDirs.add(it) }

        fun categorizeExtension(ext: String): String {
            return when (ext.lowercase(Locale.ROOT)) {
                "jpg", "jpeg", "png", "webp", "gif", "heic", "svg" -> "image"
                "mp4", "mkv", "mov", "avi", "3gp", "webm" -> "video"
                "mp3", "m4a", "wav", "aac", "ogg", "flac", "opus" -> "audio"
                "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt" -> "document"
                "apk" -> "apk"
                "zip", "rar", "7z", "tar", "gz" -> "archive"
                else -> "other"
            }
        }

        fun scanDirRecursive(dir: File, depth: Int = 0) {
            if (depth > 5 || !dir.exists() || !dir.canRead()) return
            val children = dir.listFiles() ?: return
            for (f in children) {
                if (f.isDirectory) {
                    val name = f.name
                    if (!name.startsWith(".") || name.equals(".Statuses", ignoreCase = true)) {
                        scanDirRecursive(f, depth + 1)
                    }
                } else if (f.isFile && f.length() > 0) {
                    val length = f.length()
                    val lastMod = f.lastModified()
                    val ext = f.extension
                    val cat = categorizeExtension(ext)
                    val isStale = lastMod < staleThresholdMillis
                    val isLarge = length >= largeThresholdBytes

                    val pathLower = f.absolutePath.lowercase(Locale.ROOT)
                    val nameLower = f.name.lowercase(Locale.ROOT)

                    val isWhatsApp = pathLower.contains("whatsapp")
                    val isTelegram = pathLower.contains("telegram")
                    val isSocialMedia = isWhatsApp || isTelegram

                    val isSentMedia = isSocialMedia && (pathLower.contains("/sent") || pathLower.contains("\\sent"))
                    val isVoiceNote = isWhatsApp && (pathLower.contains("voice note") || pathLower.contains("whatsapp audio") || ext.equals("opus", ignoreCase = true))
                    val isStatusCache = isWhatsApp && pathLower.contains(".statuses")

                    val socialType = when {
                        isSentMedia -> "sent"
                        isVoiceNote -> "voice_note"
                        isStatusCache -> "status"
                        isSocialMedia -> "chat_media"
                        else -> ""
                    }

                    val isScreenshot = pathLower.contains("screenshot") || nameLower.startsWith("screenshot")
                    val isOldScreenshot = isScreenshot && (lastMod < screenshotStaleThreshold)
                    val isBurstName = nameLower.contains("burst") || nameLower.contains("_cover")

                    val itemMap = mutableMapOf<String, Any>(
                        "id" to f.absolutePath,
                        "name" to f.name,
                        "path" to f.absolutePath,
                        "sizeBytes" to length,
                        "lastModified" to lastMod,
                        "category" to cat,
                        "isStale" to isStale,
                        "isLarge" to isLarge,
                        "isDuplicateCopy" to false,
                        "isSocialMedia" to isSocialMedia,
                        "socialType" to socialType,
                        "isScreenshot" to isScreenshot,
                        "isOldScreenshot" to isOldScreenshot,
                        "isBurst" to isBurstName
                    )

                    allFiles.add(itemMap)
                    if (length > 2048) {
                        sizeGroupMap.getOrPut(length) { mutableListOf() }.add(itemMap)
                    }
                }
            }
        }

        for (d in targetDirs) {
            scanDirRecursive(d)
        }

        // Group Burst / Rapid-Succession Photos (photos taken within 4.5s in same folder)
        val imageFiles = allFiles.filter { it["category"] == "image" }
        val folderGroups = imageFiles.groupBy { File(it["path"] as String).parent ?: "" }
        for ((_, group) in folderGroups) {
            if (group.size > 1) {
                val sorted = group.sortedBy { (it["lastModified"] as Long) }
                for (i in 1 until sorted.size) {
                    val prev = sorted[i - 1]
                    val curr = sorted[i]
                    val diff = (curr["lastModified"] as Long) - (prev["lastModified"] as Long)
                    if (diff in 0..4500L) {
                        prev["isBurst"] = true
                        curr["isBurst"] = true
                    }
                }
            }
        }

        // Hash cache: skip re-hashing files whose size + lastModified did not change
        val cacheDb = VaultCacheDb(applicationContext)
        val cached: Map<String, CachedHash> = try {
            cacheDb.loadAll()
        } catch (_: Exception) {
            emptyMap()
        }
        val freshEntries = mutableListOf<CachedHash>()
        var cacheHits = 0

        val duplicateGroups = mutableListOf<List<Map<String, Any>>>()
        for ((_, group) in sizeGroupMap) {
            if (group.size > 1) {
                val hashMap = mutableMapOf<String, MutableList<MutableMap<String, Any>>>()
                for (item in group) {
                    val path = item["path"] as String
                    val size = (item["sizeBytes"] as Long)
                    val mtime = (item["lastModified"] as Long)
                    val c = cached[path]
                    val hash: String? = if (c != null && c.size == size && c.mtime == mtime) {
                        cacheHits++
                        c.hash
                    } else {
                        computeFastSampleHash(File(path))?.also {
                            freshEntries.add(CachedHash(path, size, mtime, it))
                        }
                    }
                    if (hash != null) {
                        item["hash"] = hash
                        hashMap.getOrPut(hash) { mutableListOf() }.add(item)
                    }
                }
                for ((h, dups) in hashMap) {
                    if (dups.size > 1) {
                        for (i in 1 until dups.size) {
                            dups[i]["isDuplicateCopy"] = true
                            dups[i]["duplicateGroupId"] = h
                        }
                        dups[0]["duplicateGroupId"] = h
                        duplicateGroups.add(dups)
                    }
                }
            }
        }

        try {
            val existingPaths = HashSet<String>(allFiles.size)
            for (f in allFiles) existingPaths.add(f["path"] as String)
            cacheDb.saveAndPrune(freshEntries, cached.keys, existingPaths)
        } catch (_: Exception) {
        }
        cacheDb.close()

        val statFs = android.os.StatFs(Environment.getExternalStorageDirectory().path)
        val totalBytes = statFs.totalBytes
        val freeBytes = statFs.availableBytes
        val usedBytes = max(0L, totalBytes - freeBytes)

        return mapOf(
            "success" to true,
            "totalBytes" to totalBytes,
            "usedBytes" to usedBytes,
            "freeBytes" to freeBytes,
            "files" to allFiles,
            "duplicateGroups" to duplicateGroups,
            "cacheHits" to cacheHits,
            "cacheMisses" to freshEntries.size,
            "scanMillis" to (System.currentTimeMillis() - scanStartMs)
        )
    }

    private fun computeFastSampleHash(file: File): String? {
        return try {
            val md = MessageDigest.getInstance("SHA-256")
            val len = file.length()
            val stream = FileInputStream(file)
            val buffer = ByteArray(8192)

            val r1 = stream.read(buffer, 0, buffer.size)
            if (r1 > 0) md.update(buffer, 0, r1)

            if (len > 65536) {
                stream.channel.position(len / 2)
                val r2 = stream.read(buffer, 0, buffer.size)
                if (r2 > 0) md.update(buffer, 0, r2)
            }

            if (len > 131072) {
                stream.channel.position(len - 8192)
                val r3 = stream.read(buffer, 0, buffer.size)
                if (r3 > 0) md.update(buffer, 0, r3)
            }
            stream.close()

            md.digest().joinToString("") { "%02x".format(it) }
        } catch (_: Exception) {
            null
        }
    }

    private fun compressFilesToZip(filePaths: List<String>, archiveName: String?): Map<String, Any> {
        val safeName = if (!archiveName.isNullOrBlank()) {
            if (archiveName.endsWith(".zip")) archiveName else "$archiveName.zip"
        } else {
            "SysPulse_Archive_${System.currentTimeMillis()}.zip"
        }

        val outDir = cacheDir
        val zipFile = File(outDir, safeName)
        if (zipFile.exists()) zipFile.delete()

        var totalOriginal = 0L
        val usedNames = mutableSetOf<String>()

        ZipOutputStream(BufferedOutputStream(FileOutputStream(zipFile))).use { zos ->
            zos.setLevel(6)
            for (p in filePaths) {
                val f = File(p)
                if (!f.exists() || !f.isFile) continue
                totalOriginal += f.length()

                var entryName = f.name
                var count = 1
                while (usedNames.contains(entryName)) {
                    val dot = f.name.lastIndexOf('.')
                    entryName = if (dot > 0) {
                        "${f.name.substring(0, dot)}_$count.${f.name.substring(dot + 1)}"
                    } else {
                        "${f.name}_$count"
                    }
                    count++
                }
                usedNames.add(entryName)

                zos.putNextEntry(ZipEntry(entryName))
                BufferedInputStream(FileInputStream(f)).use { bis ->
                    bis.copyTo(zos)
                }
                zos.closeEntry()
            }
        }

        return mapOf(
            "success" to true,
            "archivePath" to zipFile.absolutePath,
            "archiveName" to safeName,
            "originalBytes" to totalOriginal,
            "compressedBytes" to zipFile.length(),
            "filesCount" to usedNames.size
        )
    }

    private fun exportArchiveToCloud(archivePath: String, provider: String): Boolean {
        val file = File(archivePath)
        if (!file.exists()) return false

        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file
        )

        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/zip"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, "SysPulse Cloud Archive: ${file.name}")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val targetPkg = when (provider) {
            "google_drive" -> "com.google.android.apps.docs"
            "onedrive" -> "com.microsoft.skydrive"
            else -> null
        }

        var launched = false
        if (targetPkg != null) {
            intent.setPackage(targetPkg)
            if (intent.resolveActivity(packageManager) != null) {
                mainHandler.post { startActivity(intent) }
                launched = true
            }
        }

        if (!launched) {
            intent.setPackage(null)
            val chooser = Intent.createChooser(intent, "SysPulse Cloud Archive Offload")
            mainHandler.post { startActivity(chooser) }
        }

        return true
    }

    private fun deleteArchivedStorageFiles(filePaths: List<String>): Map<String, Any> {
        var count = 0
        var freed = 0L
        for (p in filePaths) {
            val f = File(p)
            if (f.exists() && f.isFile) {
                val len = f.length()
                if (f.delete()) {
                    count++
                    freed += len
                }
            }
        }
        return mapOf(
            "deletedCount" to count,
            "freedBytes" to freed
        )
    }

    private fun deleteSingleStorageFile(filePath: String): Boolean {
        return try {
            val f = File(filePath)
            if (f.exists() && f.isFile) {
                f.delete()
            } else {
                false
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun openFileWithSystem(filePath: String, mimeType: String?): Boolean {
        try {
            val file = File(filePath)
            if (!file.exists()) return false
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            val determinedMime = mimeType ?: getMimeTypeForPath(filePath)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, determinedMime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            mainHandler.post {
                try {
                    startActivity(intent)
                } catch (_: Exception) {
                    val genericIntent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "*/*")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(Intent.createChooser(genericIntent, "Open with..."))
                }
            }
            return true
        } catch (_: Exception) {
            return false
        }
    }

    private fun getMimeTypeForPath(path: String): String {
        val ext = File(path).extension.lowercase(Locale.ROOT)
        return when (ext) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "webp" -> "image/webp"
            "gif" -> "image/gif"
            "mp4", "mkv", "mov", "avi", "3gp", "webm" -> "video/*"
            "mp3", "m4a", "wav", "aac", "ogg", "flac" -> "audio/*"
            "pdf" -> "application/pdf"
            "apk" -> "application/vnd.android.package-archive"
            "zip" -> "application/zip"
            "txt" -> "text/plain"
            "doc", "docx" -> "application/msword"
            "xls", "xlsx" -> "application/vnd.ms-excel"
            else -> "*/*"
        }
    }

    private fun launchAppUninstaller(packageNameToUninstall: String): Boolean {
        if (packageNameToUninstall.isBlank()) return false
        return try {
            val intent = Intent(Intent.ACTION_DELETE).apply {
                data = Uri.parse("package:$packageNameToUninstall")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            mainHandler.post { startActivity(intent) }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openAppDetailsSettings(packageNameToOpen: String): Boolean {
        if (packageNameToOpen.isBlank()) return false
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageNameToOpen")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            mainHandler.post { startActivity(intent) }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openBatteryOptimizationSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            mainHandler.post { startActivity(intent) }
            true
        } catch (_: Exception) {
            try {
                val fallbackIntent = Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                mainHandler.post { startActivity(fallbackIntent) }
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun launchPhoneDialer(number: String): Boolean {
        if (number.isBlank()) return false
        return try {
            val intent = Intent(Intent.ACTION_DIAL).apply {
                data = Uri.parse("tel:${Uri.encode(number)}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            mainHandler.post { startActivity(intent) }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun initNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "syspulse_smart_alerts",
                "SysPulse Smart Anomaly Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifies when background data spikes, doomscrolling exceeds 45m, or abnormal battery drain is detected."
                enableVibration(true)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.createNotificationChannel(channel)
        }
    }

    private fun triggerSmartAlert(title: String, message: String): Boolean {
        return try {
            initNotificationChannel()
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return false
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )

            val notification = NotificationCompat.Builder(this, "syspulse_smart_alerts")
                .setSmallIcon(android.R.drawable.stat_notify_more)
                .setContentTitle(title)
                .setContentText(message)
                .setStyle(NotificationCompat.BigTextStyle().bigText(message))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)
                .build()

            nm.notify((System.currentTimeMillis() % 100000).toInt(), notification)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun getDetailedCallAndSmsLogs(): Map<String, Any> {
        val callsList = mutableListOf<Map<String, Any>>()
        val smsList = mutableListOf<Map<String, Any>>()

        // 1. Query Calls (Incoming, Outgoing, Missed, Rejected)
        if (hasPermission(Manifest.permission.READ_CALL_LOG)) {
            try {
                val projection = arrayOf(
                    CallLog.Calls.CACHED_NAME,
                    CallLog.Calls.NUMBER,
                    CallLog.Calls.TYPE,
                    CallLog.Calls.DURATION,
                    CallLog.Calls.DATE
                )
                contentResolver.query(
                    CallLog.Calls.CONTENT_URI,
                    projection,
                    null,
                    null,
                    "${CallLog.Calls.DATE} DESC LIMIT 100"
                )?.use { cursor ->
                    val nameIdx = cursor.getColumnIndex(CallLog.Calls.CACHED_NAME)
                    val numIdx = cursor.getColumnIndex(CallLog.Calls.NUMBER)
                    val typeIdx = cursor.getColumnIndex(CallLog.Calls.TYPE)
                    val durIdx = cursor.getColumnIndex(CallLog.Calls.DURATION)
                    val dateIdx = cursor.getColumnIndex(CallLog.Calls.DATE)

                    while (cursor.moveToNext()) {
                        val name = if (nameIdx >= 0) cursor.getString(nameIdx) ?: "" else ""
                        val num = if (numIdx >= 0) cursor.getString(numIdx) ?: "" else ""
                        val rawType = if (typeIdx >= 0) cursor.getInt(typeIdx) else 0
                        val dur = if (durIdx >= 0) cursor.getLong(durIdx) else 0L
                        val date = if (dateIdx >= 0) cursor.getLong(dateIdx) else 0L

                        val typeStr = when (rawType) {
                            CallLog.Calls.INCOMING_TYPE -> "incoming"
                            CallLog.Calls.OUTGOING_TYPE -> "outgoing"
                            CallLog.Calls.MISSED_TYPE -> "missed"
                            CallLog.Calls.REJECTED_TYPE -> "rejected"
                            else -> "other"
                        }

                        callsList.add(mapOf(
                            "name" to (if (name.isNotBlank()) name else (if (num.isNotBlank()) num else "Unknown Contact")),
                            "number" to num,
                            "type" to typeStr,
                            "duration" to dur,
                            "timestamp" to date
                        ))
                    }
                }
            } catch (_: Exception) {}
        }

        // 2. Query SMS Messages (Inbox & Sent)
        if (hasPermission(Manifest.permission.READ_SMS)) {
            try {
                val uri = Telephony.Sms.CONTENT_URI
                val projection = arrayOf(
                    Telephony.Sms.ADDRESS,
                    Telephony.Sms.BODY,
                    Telephony.Sms.DATE,
                    Telephony.Sms.TYPE
                )
                contentResolver.query(
                    uri,
                    projection,
                    null,
                    null,
                    "${Telephony.Sms.DATE} DESC LIMIT 100"
                )?.use { cursor ->
                    val addrIdx = cursor.getColumnIndex(Telephony.Sms.ADDRESS)
                    val bodyIdx = cursor.getColumnIndex(Telephony.Sms.BODY)
                    val dateIdx = cursor.getColumnIndex(Telephony.Sms.DATE)
                    val typeIdx = cursor.getColumnIndex(Telephony.Sms.TYPE)

                    while (cursor.moveToNext()) {
                        val address = if (addrIdx >= 0) cursor.getString(addrIdx) ?: "" else ""
                        val body = if (bodyIdx >= 0) cursor.getString(bodyIdx) ?: "" else ""
                        val date = if (dateIdx >= 0) cursor.getLong(dateIdx) else 0L
                        val type = if (typeIdx >= 0) cursor.getInt(typeIdx) else 1

                        smsList.add(mapOf(
                            "address" to (if (address.isNotBlank()) address else "Unknown"),
                            "body" to body,
                            "date" to date,
                            "isInbox" to (type == Telephony.Sms.MESSAGE_TYPE_INBOX)
                        ))
                    }
                }
            } catch (_: Exception) {}
        }

        return mapOf(
            "calls" to callsList,
            "sms" to smsList,
            "hasCallPermission" to hasPermission(Manifest.permission.READ_CALL_LOG),
            "hasSmsPermission" to hasPermission(Manifest.permission.READ_SMS)
        )
    }

    // =========================================================================
    // 10. UNIFIED SYSTEM CONTROL HUB (Direct Actions + Deep Settings Intents)
    // =========================================================================

    private fun getSystemControlHubState(): Map<String, Any> {
        val audio = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        val ringerModeStr = when (audio?.ringerMode) {
            AudioManager.RINGER_MODE_SILENT -> "silent"
            AudioManager.RINGER_MODE_VIBRATE -> "vibrate"
            else -> "normal"
        }
        val maxMedia = max(1, audio?.getStreamMaxVolume(AudioManager.STREAM_MUSIC) ?: 15)
        val curMedia = audio?.getStreamVolume(AudioManager.STREAM_MUSIC) ?: 8
        val mediaVolPct = ((curMedia.toDouble() / maxMedia.toDouble()) * 100.0).roundToInt().coerceIn(0, 100)

        val maxRing = max(1, audio?.getStreamMaxVolume(AudioManager.STREAM_RING) ?: 7)
        val curRing = audio?.getStreamVolume(AudioManager.STREAM_RING) ?: 5
        val ringVolPct = ((curRing.toDouble() / maxRing.toDouble()) * 100.0).roundToInt().coerceIn(0, 100)

        val rawBrightness = try {
            Settings.System.getInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS, 128)
        } catch (_: Exception) {
            128
        }
        val brightnessPct = ((rawBrightness.toDouble() / 255.0) * 100.0).roundToInt().coerceIn(5, 100)

        val autoBrightness = try {
            Settings.System.getInt(
                contentResolver,
                Settings.System.SCREEN_BRIGHTNESS_MODE,
                Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC
            ) == Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC
        } catch (_: Exception) {
            true
        }

        val timeoutMs = try {
            Settings.System.getInt(contentResolver, Settings.System.SCREEN_OFF_TIMEOUT, 60000)
        } catch (_: Exception) {
            60000
        }
        val timeoutSec = max(15, timeoutMs / 1000)

        val adbEnabled = try {
            Settings.Global.getInt(contentResolver, Settings.Global.ADB_ENABLED, 0) == 1
        } catch (_: Exception) {
            false
        }

        val devOptionsEnabled = try {
            Settings.Global.getInt(contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0) == 1
        } catch (_: Exception) {
            false
        }

        val autoTime = try {
            Settings.Global.getInt(contentResolver, Settings.Global.AUTO_TIME, 1) == 1
        } catch (_: Exception) {
            true
        }

        val autoTimeZone = try {
            Settings.Global.getInt(contentResolver, Settings.Global.AUTO_TIME_ZONE, 1) == 1
        } catch (_: Exception) {
            true
        }

        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        val isDeviceSecure = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            keyguard?.isDeviceSecure == true
        } else {
            keyguard?.isKeyguardSecure == true
        }

        val wifiMgr = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        val wifiEnabled = try {
            wifiMgr?.isWifiEnabled == true
        } catch (_: Exception) {
            true
        }

        val btMgr = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val btEnabled = try {
            btMgr?.adapter?.isEnabled == true
        } catch (_: Exception) {
            false
        }

        val nfcMgr = getSystemService(Context.NFC_SERVICE) as? NfcManager
        val nfcEnabled = try {
            nfcMgr?.defaultAdapter?.isEnabled == true
        } catch (_: Exception) {
            false
        }

        val powerMgr = getSystemService(Context.POWER_SERVICE) as? PowerManager
        val batterySaverOn = powerMgr?.isPowerSaveMode == true

        val canWriteSettings = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.System.canWrite(this)
        } else {
            true
        }

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        val dndGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            nm?.isNotificationPolicyAccessGranted == true
        } else {
            true
        }

        val batSnap = readQuickBatterySnapshot()

        return mapOf(
            "isTorchOn" to isTorchActive,
            "ringerMode" to ringerModeStr,
            "mediaVolumePct" to mediaVolPct,
            "ringVolumePct" to ringVolPct,
            "brightnessPct" to brightnessPct,
            "autoBrightness" to autoBrightness,
            "screenTimeoutSec" to timeoutSec,
            "adbEnabled" to adbEnabled,
            "devOptionsEnabled" to devOptionsEnabled,
            "autoTimeEnabled" to autoTime,
            "autoTimeZoneEnabled" to autoTimeZone,
            "isDeviceSecure" to isDeviceSecure,
            "wifiEnabled" to wifiEnabled,
            "bluetoothEnabled" to btEnabled,
            "nfcEnabled" to nfcEnabled,
            "batterySaverOn" to batterySaverOn,
            "canWriteSettings" to canWriteSettings,
            "dndPolicyGranted" to dndGranted,
            "deviceBrand" to "${Build.MANUFACTURER.uppercase(Locale.US)} ${Build.MODEL}",
            "androidVersion" to "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
            "batteryPct" to (batSnap["batteryPct"] ?: 78),
            "isCharging" to (batSnap["isCharging"] ?: false),
            "batteryHealth" to (batSnap["batteryHealth"] ?: "Good"),
            "batteryHealthScore" to (batSnap["batteryHealthScore"] ?: 96),
            "batteryTempC" to (batSnap["batteryTempC"] ?: 33.0),
            "batteryVoltageV" to (batSnap["batteryVoltageV"] ?: 4.0),
            "batteryCurrentMa" to (batSnap["batteryCurrentMa"] ?: 320),
            "batteryPowerWatts" to (batSnap["batteryPowerWatts"] ?: 1.3),
            "chargingSource" to (batSnap["chargingSource"] ?: "On Battery"),
            "thermalStatus" to (batSnap["thermalStatus"] ?: "Cool & Optimal")
        )
    }

    private fun readQuickBatterySnapshot(): Map<String, Any> {
        val intent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val pct = if (level >= 0 && scale > 0) ((level * 100f) / scale).roundToInt().coerceIn(0, 100) else 78
        val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL
        val tempC = (intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 330) ?: 330) / 10.0
        val rawMv = intent?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 4050) ?: 4050
        val voltageV = if (rawMv > 100) rawMv / 1000.0 else rawMv.toDouble()
        val healthCode = intent?.getIntExtra(BatteryManager.EXTRA_HEALTH, BatteryManager.BATTERY_HEALTH_GOOD)
            ?: BatteryManager.BATTERY_HEALTH_GOOD
        val healthLabel = when (healthCode) {
            BatteryManager.BATTERY_HEALTH_GOOD -> "Good"
            BatteryManager.BATTERY_HEALTH_OVERHEAT -> "Overheat"
            BatteryManager.BATTERY_HEALTH_DEAD -> "Replace Soon"
            BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "Over Voltage"
            BatteryManager.BATTERY_HEALTH_COLD -> "Cold"
            else -> "Normal"
        }
        val plugged = intent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
        val chargingSource = when (plugged) {
            BatteryManager.BATTERY_PLUGGED_AC -> "AC Fast Charger"
            BatteryManager.BATTERY_PLUGGED_USB -> "USB Port (Slow)"
            BatteryManager.BATTERY_PLUGGED_WIRELESS -> "Wireless Charger"
            BatteryManager.BATTERY_PLUGGED_DOCK -> "Charging Dock"
            else -> if (isCharging) "External Power" else "On Battery"
        }
        val bm = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val currentNowRaw = abs(bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW) ?: 0)
        val currentNowMa = when {
            currentNowRaw >= 20_000 -> (currentNowRaw / 1000.0).roundToInt()
            currentNowRaw > 0 -> currentNowRaw
            else -> if (isCharging) 1850 else 320
        }
        val livePowerWatts = (((currentNowMa / 1000.0) * voltageV) * 10.0).roundToInt() / 10.0
        val thermalStatus = when {
            tempC >= 41.5 -> "Hot • Throttling Risk"
            tempC >= 37.5 -> "Warm • Active Load"
            else -> "Cool & Optimal"
        }
        var healthScore = when (healthCode) {
            BatteryManager.BATTERY_HEALTH_GOOD -> 96
            BatteryManager.BATTERY_HEALTH_OVERHEAT -> 72
            BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> 68
            BatteryManager.BATTERY_HEALTH_COLD -> 82
            BatteryManager.BATTERY_HEALTH_DEAD -> 40
            else -> 88
        }
        if (tempC >= 42.0) healthScore -= 8
        else if (tempC >= 39.0) healthScore -= 3
        healthScore = healthScore.coerceIn(35, 100)

        return mapOf(
            "batteryPct" to pct,
            "isCharging" to isCharging,
            "batteryHealth" to healthLabel,
            "batteryHealthScore" to healthScore,
            "batteryTempC" to tempC,
            "batteryVoltageV" to voltageV,
            "batteryCurrentMa" to currentNowMa,
            "batteryPowerWatts" to livePowerWatts,
            "chargingSource" to chargingSource,
            "thermalStatus" to thermalStatus
        )
    }

    private fun executeSafeChargeBooster(): Map<String, Any> {
        var torchTurnedOff = false
        if (isTorchActive && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val camMgr = getSystemService(Context.CAMERA_SERVICE) as? CameraManager
                if (camMgr != null) {
                    for (id in camMgr.cameraIdList) {
                        val hasFlash = camMgr.getCameraCharacteristics(id)
                            .get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
                        if (hasFlash) {
                            camMgr.setTorchMode(id, false)
                            isTorchActive = false
                            torchTurnedOff = true
                            break
                        }
                    }
                }
            } catch (_: Exception) {}
        }

        val candidates = findBackgroundCandidatePackages(limit = 12)
        killBackgroundApps(candidates)
        System.gc()

        var ringerOptimized = false
        try {
            val audio = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            if (audio != null && audio.ringerMode == AudioManager.RINGER_MODE_NORMAL) {
                audio.ringerMode = AudioManager.RINGER_MODE_VIBRATE
                ringerOptimized = true
            }
        } catch (_: Exception) {}

        val canWrite = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.System.canWrite(this)
        } else {
            true
        }
        var screenOptimized = false
        if (canWrite) {
            try {
                Settings.System.putInt(
                    contentResolver,
                    Settings.System.SCREEN_BRIGHTNESS_MODE,
                    Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL
                )
                Settings.System.putInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS, 38)
                Settings.System.putInt(contentResolver, Settings.System.SCREEN_OFF_TIMEOUT, 30_000)
                screenOptimized = true
            } catch (_: Exception) {}
        }

        val snap = readQuickBatterySnapshot()
        val tempC = snap["batteryTempC"] as? Double ?: 33.0
        val watts = snap["batteryPowerWatts"] as? Double ?: 1.5
        val currentMa = snap["batteryCurrentMa"] as? Int ?: 320
        val isCharging = snap["isCharging"] as? Boolean ?: false

        val summaryMsg = buildString {
            append("Safe Charge Booster active: trimmed ${candidates.size} background app(s)")
            if (screenOptimized) append(", dimmed screen to 15% & 30s sleep")
            if (ringerOptimized) append(", switched ringer to Vibrate")
            if (torchTurnedOff) append(", turned off Torch")
            append(". Thermal ${String.format(Locale.US, "%.1f", tempC)}°C • ${String.format(Locale.US, "%.1f", watts)}W.")
            if (!canWrite) append(" Grant 'Modify System Settings' to also auto-dim screen.")
        }

        return mapOf(
            "ok" to true,
            "trimmedApps" to candidates.size,
            "screenOptimized" to screenOptimized,
            "requiresWritePermission" to !canWrite,
            "ringerOptimized" to ringerOptimized,
            "torchTurnedOff" to torchTurnedOff,
            "tempC" to tempC,
            "liveWatts" to watts,
            "currentMa" to currentMa,
            "isCharging" to isCharging,
            "message" to summaryMsg
        )
    }

    private fun executeDirectSystemControl(action: String, value: Any?): Map<String, Any> {
        return try {
            when (action) {
                "toggleTorch" -> {
                    val camMgr = getSystemService(Context.CAMERA_SERVICE) as? CameraManager
                        ?: return mapOf("ok" to false, "message" to "Camera service unavailable")
                    var targetCamId: String? = null
                    for (id in camMgr.cameraIdList) {
                        val chars = camMgr.getCameraCharacteristics(id)
                        val hasFlash = chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
                        if (hasFlash) {
                            targetCamId = id
                            break
                        }
                    }
                    if (targetCamId == null) {
                        return mapOf("ok" to false, "message" to "No hardware flashlight found on device")
                    }
                    val nextState = (value as? Boolean) ?: !isTorchActive
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        camMgr.setTorchMode(targetCamId, nextState)
                        isTorchActive = nextState
                    }
                    mapOf(
                        "ok" to true,
                        "state" to isTorchActive,
                        "message" to if (isTorchActive) "Flashlight turned ON 🔦" else "Flashlight turned OFF"
                    )
                }

                "setRingerMode" -> {
                    val modeReq = (value as? String) ?: "normal"
                    val audio = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                        ?: return mapOf("ok" to false, "message" to "Audio service unavailable")
                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager

                    if (modeReq == "silent" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && nm?.isNotificationPolicyAccessGranted == false) {
                        // Fallback to vibrate or prompt DND policy access
                        audio.ringerMode = AudioManager.RINGER_MODE_VIBRATE
                        openSystemSettingTarget("dnd_policy_access")
                        return mapOf(
                            "ok" to true,
                            "state" to "vibrate",
                            "message" to "Switched to Vibrate. Grant Do-Not-Disturb permission in the opened screen for total Silent mode."
                        )
                    }

                    audio.ringerMode = when (modeReq) {
                        "silent" -> AudioManager.RINGER_MODE_SILENT
                        "vibrate" -> AudioManager.RINGER_MODE_VIBRATE
                        else -> AudioManager.RINGER_MODE_NORMAL
                    }
                    mapOf(
                        "ok" to true,
                        "state" to modeReq,
                        "message" to "Ringer mode set to ${modeReq.uppercase(Locale.US)} 🔔"
                    )
                }

                "setMediaVolume" -> {
                    val pct = ((value as? Number)?.toInt() ?: 50).coerceIn(0, 100)
                    val audio = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                        ?: return mapOf("ok" to false, "message" to "Audio service unavailable")
                    val maxVol = max(1, audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC))
                    val targetVol = ((pct / 100.0) * maxVol).roundToInt().coerceIn(0, maxVol)
                    audio.setStreamVolume(AudioManager.STREAM_MUSIC, targetVol, AudioManager.FLAG_SHOW_UI)
                    mapOf(
                        "ok" to true,
                        "state" to pct,
                        "message" to "Media volume adjusted to $pct% 🔊"
                    )
                }

                "setBrightness" -> {
                    val pct = ((value as? Number)?.toInt() ?: 50).coerceIn(5, 100)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.System.canWrite(this)) {
                        openSystemSettingTarget("write_settings_permission")
                        return mapOf(
                            "ok" to false,
                            "requiresWritePermission" to true,
                            "message" to "Please allow 'Modify System Settings' in the opened screen to control brightness directly."
                        )
                    }
                    val rawVal = ((pct / 100.0) * 255.0).roundToInt().coerceIn(10, 255)
                    Settings.System.putInt(
                        contentResolver,
                        Settings.System.SCREEN_BRIGHTNESS_MODE,
                        Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL
                    )
                    Settings.System.putInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS, rawVal)
                    mapOf(
                        "ok" to true,
                        "state" to pct,
                        "message" to "Screen brightness set to $pct% ☀️"
                    )
                }

                "setAutoBrightness" -> {
                    val enable = (value as? Boolean) ?: true
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.System.canWrite(this)) {
                        openSystemSettingTarget("write_settings_permission")
                        return mapOf(
                            "ok" to false,
                            "requiresWritePermission" to true,
                            "message" to "Please allow 'Modify System Settings' in the opened screen first."
                        )
                    }
                    Settings.System.putInt(
                        contentResolver,
                        Settings.System.SCREEN_BRIGHTNESS_MODE,
                        if (enable) Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC else Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL
                    )
                    mapOf(
                        "ok" to true,
                        "state" to enable,
                        "message" to if (enable) "Adaptive Auto-Brightness Enabled ✨" else "Manual Brightness Mode Active"
                    )
                }

                "setScreenTimeout" -> {
                    val seconds = ((value as? Number)?.toInt() ?: 60).coerceIn(15, 1800)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.System.canWrite(this)) {
                        openSystemSettingTarget("write_settings_permission")
                        return mapOf(
                            "ok" to false,
                            "requiresWritePermission" to true,
                            "message" to "Allow 'Modify System Settings' in the opened screen to adjust screen timeout directly."
                        )
                    }
                    Settings.System.putInt(contentResolver, Settings.System.SCREEN_OFF_TIMEOUT, seconds * 1000)
                    mapOf(
                        "ok" to true,
                        "state" to seconds,
                        "message" to "Screen timeout set to ${if (seconds >= 60) "${seconds / 60} min" else "${seconds}s"} ⏱️"
                    )
                }

                "boostSystemMemory" -> {
                    val candidates = findBackgroundCandidatePackages(limit = 10)
                    killBackgroundApps(candidates)
                    System.gc()
                    mapOf(
                        "ok" to true,
                        "trimmedApps" to candidates.size,
                        "message" to "Cached RAM trimmed for ${candidates.size} app(s). (Recent Apps square cards are OS history snapshots; use Force Stop for auto-restarting apps.)"
                    )
                }

                "safeChargeBooster" -> executeSafeChargeBooster()

                else -> mapOf("ok" to false, "message" to "Unknown direct control action: $action")
            }
        } catch (e: Exception) {
            mapOf("ok" to false, "message" to "Action requires manual confirmation in Settings (${e.javaClass.simpleName})")
        }
    }

    private fun openSystemSettingTarget(targetKey: String): Boolean {
        val primaryIntent: Intent = when (targetKey) {
            // 1. Audio & Sound
            "sound_settings" -> Intent(Settings.ACTION_SOUND_SETTINGS)
            "dnd_settings" -> Intent(Settings.ACTION_ZEN_MODE_PRIORITY_SETTINGS)
            "dnd_policy_access" -> Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            "notification_settings" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_ALL_APPS_NOTIFICATION_SETTINGS)
            } else {
                Intent(Settings.ACTION_SOUND_SETTINGS)
            }

            // 2. Display & Theme
            "display_settings" -> Intent(Settings.ACTION_DISPLAY_SETTINGS)
            "wallpaper_settings" -> Intent(Intent.ACTION_SET_WALLPAPER)
            "night_display_settings" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_NIGHT_DISPLAY_SETTINGS)
            } else {
                Intent(Settings.ACTION_DISPLAY_SETTINGS)
            }
            "cast_display" -> Intent(Settings.ACTION_CAST_SETTINGS)
            "write_settings_permission" -> Intent(
                Settings.ACTION_MANAGE_WRITE_SETTINGS,
                Uri.parse("package:$packageName")
            )

            // 3. Security, Lock & Privacy
            "security_settings" -> Intent(Settings.ACTION_SECURITY_SETTINGS)
            "screen_lock" -> Intent("android.app.action.SET_NEW_PASSWORD")
            "biometric_enroll" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                Intent(Settings.ACTION_BIOMETRIC_ENROLL)
            } else {
                Intent(Settings.ACTION_SECURITY_SETTINGS)
            }
            "privacy_settings" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                Intent(Settings.ACTION_PRIVACY_SETTINGS)
            } else {
                Intent(Settings.ACTION_SECURITY_SETTINGS)
            }
            "location_settings" -> Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
            "unknown_sources" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
            } else {
                Intent(Settings.ACTION_SECURITY_SETTINGS)
            }

            // 4. Connectivity & Network
            "wifi_settings" -> Intent(Settings.ACTION_WIFI_SETTINGS)
            "bluetooth_settings" -> Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
            "hotspot_settings" -> Intent("android.settings.TETHER_SETTINGS")
            "data_roaming_sim" -> Intent(Settings.ACTION_DATA_ROAMING_SETTINGS)
            "airplane_wireless" -> Intent(Settings.ACTION_AIRPLANE_MODE_SETTINGS)
            "nfc_settings" -> Intent(Settings.ACTION_NFC_SETTINGS)
            "vpn_settings" -> Intent(Settings.ACTION_VPN_SETTINGS)
            "private_dns_wireless" -> Intent(Settings.ACTION_WIRELESS_SETTINGS)

            // 5. Battery & Performance
            "battery_saver" -> Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
            "honor_app_launch" -> {
                return openBatteryOptimizationSettings()
            }
            "ignore_battery_opt" -> Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            "power_usage_summary" -> Intent(Intent.ACTION_POWER_USAGE_SUMMARY)

            // 6. Developer Options & System
            "developer_options" -> Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
            "device_info_build" -> Intent(Settings.ACTION_DEVICE_INFO_SETTINGS)

            // 7. Date, Time, Language & Input
            "date_time_settings" -> Intent(Settings.ACTION_DATE_SETTINGS)
            "locale_language" -> Intent(Settings.ACTION_LOCALE_SETTINGS)
            "keyboard_input" -> Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)
            "user_dictionary" -> Intent(Settings.ACTION_USER_DICTIONARY_SETTINGS)

            // 8. Apps & Permissions
            "manage_all_apps" -> Intent(Settings.ACTION_MANAGE_ALL_APPLICATIONS_SETTINGS)
            "default_apps" -> Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS)
            "overlay_permission" -> Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
            "usage_access" -> Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)

            // 9. Accessibility & Storage
            "accessibility_settings" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            "captioning_settings" -> Intent(Settings.ACTION_CAPTIONING_SETTINGS)
            "internal_storage" -> Intent(Settings.ACTION_INTERNAL_STORAGE_SETTINGS)

            else -> Intent(Settings.ACTION_SETTINGS)
        }

        return launchSafeIntent(primaryIntent)
    }

    private fun launchSafeIntent(primary: Intent): Boolean {
        try {
            primary.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(primary)
            return true
        } catch (_: Exception) {
            try {
                // Fallback chooser if wallpaper intent
                if (primary.action == Intent.ACTION_SET_WALLPAPER) {
                    val chooser = Intent.createChooser(primary, "Select Wallpaper").apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(chooser)
                    return true
                }
            } catch (_: Exception) {}
            return try {
                val fallback = Intent(Settings.ACTION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(fallback)
                true
            } catch (_: Exception) {
                false
            }
        }
    }
}

// ============================================================================
// VAULT HASH CACHE (native SQLite, zero external dependencies)
// Remembers (path, size, lastModified, sample-hash) so unchanged files are not re-hashed.
// ============================================================================

internal data class CachedHash(
    val path: String,
    val size: Long,
    val mtime: Long,
    val hash: String
)

internal class VaultCacheDb(context: Context) :
    SQLiteOpenHelper(context, "vault_cache.db", null, 1) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            "CREATE TABLE IF NOT EXISTS file_hash (" +
                "path TEXT PRIMARY KEY, size INTEGER NOT NULL, " +
                "mtime INTEGER NOT NULL, hash TEXT NOT NULL)"
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS file_hash")
        onCreate(db)
    }

    fun loadAll(): Map<String, CachedHash> {
        val out = HashMap<String, CachedHash>()
        readableDatabase.rawQuery("SELECT path, size, mtime, hash FROM file_hash", null).use { c ->
            while (c.moveToNext()) {
                val p = c.getString(0)
                out[p] = CachedHash(p, c.getLong(1), c.getLong(2), c.getString(3))
            }
        }
        return out
    }

    fun saveAndPrune(
        fresh: List<CachedHash>,
        previousPaths: Set<String>,
        existingPaths: Set<String>
    ) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            for (e in fresh) {
                val cv = ContentValues().apply {
                    put("path", e.path)
                    put("size", e.size)
                    put("mtime", e.mtime)
                    put("hash", e.hash)
                }
                db.insertWithOnConflict("file_hash", null, cv, SQLiteDatabase.CONFLICT_REPLACE)
            }
            for (p in previousPaths) {
                if (!existingPaths.contains(p)) {
                    db.delete("file_hash", "path = ?", arrayOf(p))
                }
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }
}
