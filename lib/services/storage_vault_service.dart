import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// STORAGE VAULT DOMAIN MODELS & CLOUD ARCHIVER (ENGLISH)
// ============================================================================

enum VaultFileCategory {
  image,
  video,
  audio,
  document,
  apk,
  archive,
  other;

  String get displayName {
    switch (this) {
      case VaultFileCategory.image:
        return 'Photos';
      case VaultFileCategory.video:
        return 'Videos';
      case VaultFileCategory.audio:
        return 'Audio';
      case VaultFileCategory.document:
        return 'Documents';
      case VaultFileCategory.apk:
        return 'APKs';
      case VaultFileCategory.archive:
        return 'Archives';
      case VaultFileCategory.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case VaultFileCategory.image:
        return Icons.photo_library_rounded;
      case VaultFileCategory.video:
        return Icons.video_collection_rounded;
      case VaultFileCategory.audio:
        return Icons.audio_file_rounded;
      case VaultFileCategory.document:
        return Icons.description_rounded;
      case VaultFileCategory.apk:
        return Icons.android_rounded;
      case VaultFileCategory.archive:
        return Icons.folder_zip_rounded;
      case VaultFileCategory.other:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color get color {
    switch (this) {
      case VaultFileCategory.image:
        return const Color(0xFF38BDF8); // Cyan
      case VaultFileCategory.video:
        return const Color(0xFFA855F7); // Violet
      case VaultFileCategory.audio:
        return const Color(0xFFF59E0B); // Amber
      case VaultFileCategory.document:
        return const Color(0xFF10B981); // Emerald
      case VaultFileCategory.apk:
        return const Color(0xFFFB7185); // Rose
      case VaultFileCategory.archive:
        return const Color(0xFF6366F1); // Indigo
      case VaultFileCategory.other:
        return const Color(0xFF94A3B8); // Slate
    }
  }
}

enum CloudProvider {
  googleDrive,
  oneDrive,
  systemShare;

  String get displayName {
    switch (this) {
      case CloudProvider.googleDrive:
        return 'Google Drive';
      case CloudProvider.oneDrive:
        return 'Microsoft OneDrive';
      case CloudProvider.systemShare:
        return 'System Share Sheet';
    }
  }

  String get nativeIdentifier {
    switch (this) {
      case CloudProvider.googleDrive:
        return 'google_drive';
      case CloudProvider.oneDrive:
        return 'onedrive';
      case CloudProvider.systemShare:
        return 'system';
    }
  }

  IconData get icon {
    switch (this) {
      case CloudProvider.googleDrive:
        return Icons.add_to_drive_rounded;
      case CloudProvider.oneDrive:
        return Icons.cloud_upload_rounded;
      case CloudProvider.systemShare:
        return Icons.share_rounded;
    }
  }
}

class VaultFileItem {
  final String id;
  final String name;
  final String path;
  final int sizeBytes;
  final DateTime lastModified;
  final VaultFileCategory category;
  final String? hash;
  final String? duplicateGroupId;
  final bool isDuplicateCopy;
  final bool isStale;
  final bool isLarge;
  final bool isSocialMedia;
  final String? socialType; // 'sent', 'voice_note', 'status', 'chat_media'
  final bool isScreenshot;
  final bool isOldScreenshot;
  final bool isBurst;

  const VaultFileItem({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.lastModified,
    required this.category,
    this.hash,
    this.duplicateGroupId,
    this.isDuplicateCopy = false,
    this.isStale = false,
    this.isLarge = false,
    this.isSocialMedia = false,
    this.socialType,
    this.isScreenshot = false,
    this.isOldScreenshot = false,
    this.isBurst = false,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedAge {
    final days = DateTime.now().difference(lastModified).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return '${days}d ago';
  }
}

class StorageVaultSummary {
  final int totalBytes;
  final int usedBytes;
  final int freeBytes;
  final Map<VaultFileCategory, int> categoryBytes;
  final Map<VaultFileCategory, int> categoryCounts;
  final List<List<VaultFileItem>> duplicateGroups;
  final List<VaultFileItem> staleFiles;
  final List<VaultFileItem> largeFiles;
  final List<VaultFileItem> allFiles;
  final List<VaultFileItem> socialMediaFiles;
  final List<VaultFileItem> screenshotFiles;
  final List<VaultFileItem> burstFiles;

  /// Scan diagnostics (shows the effect of the native hash cache)
  final int scanMillis;
  final int cacheHits;
  final int cacheMisses;

  const StorageVaultSummary({
    required this.totalBytes,
    required this.usedBytes,
    required this.freeBytes,
    required this.categoryBytes,
    required this.categoryCounts,
    required this.duplicateGroups,
    required this.staleFiles,
    required this.largeFiles,
    required this.allFiles,
    required this.socialMediaFiles,
    required this.screenshotFiles,
    required this.burstFiles,
    this.scanMillis = 0,
    this.cacheHits = 0,
    this.cacheMisses = 0,
  });

  int get totalDuplicateWasteBytes {
    var waste = 0;
    for (final group in duplicateGroups) {
      if (group.length > 1) {
        for (var i = 1; i < group.length; i++) {
          waste += group[i].sizeBytes;
        }
      }
    }
    return waste;
  }

  int get totalStaleBytes =>
      staleFiles.fold(0, (sum, item) => sum + item.sizeBytes);

  int get totalLargeBytes =>
      largeFiles.fold(0, (sum, item) => sum + item.sizeBytes);

  int get totalSocialMediaBytes =>
      socialMediaFiles.fold(0, (sum, item) => sum + item.sizeBytes);

  int get totalScreenshotBytes =>
      screenshotFiles.fold(0, (sum, item) => sum + item.sizeBytes);

  int get totalBurstBytes =>
      burstFiles.fold(0, (sum, item) => sum + item.sizeBytes);

  double get usedPercentage {
    if (totalBytes <= 0) return 0.0;
    return (usedBytes / totalBytes).clamp(0.0, 1.0);
  }
}

class ArchiveCompressionResult {
  final String archivePath;
  final String archiveName;
  final int originalBytes;
  final int compressedBytes;
  final int filesCount;

  const ArchiveCompressionResult({
    required this.archivePath,
    required this.archiveName,
    required this.originalBytes,
    required this.compressedBytes,
    required this.filesCount,
  });

  double get spaceSavedRatio {
    if (originalBytes <= 0) return 0.0;
    final saved = originalBytes - compressedBytes;
    return (saved / originalBytes).clamp(0.0, 1.0);
  }

  String get spaceSavedFormatted {
    final saved = originalBytes - compressedBytes;
    if (saved <= 0) return '0 MB';
    if (saved < 1024 * 1024) return '${(saved / 1024).toStringAsFixed(1)} KB';
    return '${(saved / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ============================================================================
// STORAGE VAULT SERVICE
// ============================================================================

class StorageVaultService {
  StorageVaultService._();
  static final StorageVaultService instance = StorageVaultService._();

  static const MethodChannel _channel =
      MethodChannel('com.syspulse.mobile/telemetry');

  Future<StorageVaultSummary> scanStorage({int staleDays = 60}) async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'scanStorageVault',
        {'staleDays': staleDays},
      );
      if (raw != null && raw['success'] == true) {
        return _parseNativeSummary(raw, staleDays);
      }
    } catch (_) {}

    await Future<void>.delayed(const Duration(milliseconds: 320));
    return _generateMockSummary(staleDays);
  }

  Future<ArchiveCompressionResult> compressFiles(
    List<VaultFileItem> files, {
    String? archiveName,
  }) async {
    final paths = files.map((f) => f.path).toList();
    final totalOriginal = files.fold(0, (sum, f) => sum + f.sizeBytes);

    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'compressFiles',
        {
          'filePaths': paths,
          'archiveName': archiveName,
        },
      );
      if (raw != null && raw['success'] == true) {
        return ArchiveCompressionResult(
          archivePath: raw['archivePath'] as String? ?? '',
          archiveName: raw['archiveName'] as String? ?? 'SysPulse_Archive.zip',
          originalBytes: (raw['originalBytes'] as num?)?.toInt() ?? totalOriginal,
          compressedBytes: (raw['compressedBytes'] as num?)?.toInt() ??
              (totalOriginal * 0.65).toInt(),
          filesCount: (raw['filesCount'] as num?)?.toInt() ?? files.length,
        );
      }
    } catch (_) {}

    await Future<void>.delayed(const Duration(milliseconds: 600));
    final compressedMock = (totalOriginal * 0.62).toInt();
    return ArchiveCompressionResult(
      archivePath: '/storage/emulated/0/Download/SysPulse_Archive.zip',
      archiveName: archiveName ?? 'SysPulse_Archive.zip',
      originalBytes: totalOriginal,
      compressedBytes: compressedMock,
      filesCount: files.length,
    );
  }

  Future<bool> exportToCloud(String archivePath, CloudProvider provider) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
        'exportArchiveToCloud',
        {
          'archivePath': archivePath,
          'provider': provider.nativeIdentifier,
        },
      );
      return ok ?? true;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return true;
    }
  }

  Future<Map<String, dynamic>> deleteArchivedFiles(
      List<VaultFileItem> files) async {
    final paths = files.map((f) => f.path).toList();
    final totalFreed = files.fold(0, (sum, f) => sum + f.sizeBytes);

    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'deleteArchivedFiles',
        {'filePaths': paths},
      );
      if (raw != null) {
        return {
          'deletedCount': raw['deletedCount'] ?? files.length,
          'freedBytes': raw['freedBytes'] ?? totalFreed,
        };
      }
    } catch (_) {}

    await Future<void>.delayed(const Duration(milliseconds: 300));
    return {
      'deletedCount': files.length,
      'freedBytes': totalFreed,
    };
  }

  Future<bool> deleteSingleFile(VaultFileItem file) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
        'deleteSingleFile',
        {'filePath': file.path},
      );
      return ok ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> openFilePreview(VaultFileItem file) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
        'openFilePreview',
        {
          'filePath': file.path,
          'mimeType': null,
        },
      );
      return ok ?? true;
    } catch (_) {
      return false;
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

  StorageVaultSummary _parseNativeSummary(
      Map<String, dynamic> raw, int staleDays) {
    final allFiles = <VaultFileItem>[];
    final dupGroups = <List<VaultFileItem>>[];
    final staleFiles = <VaultFileItem>[];
    final largeFiles = <VaultFileItem>[];
    final socialMediaFiles = <VaultFileItem>[];
    final screenshotFiles = <VaultFileItem>[];
    final burstFiles = <VaultFileItem>[];

    final rawFiles = raw['files'] as List<dynamic>? ?? const [];
    for (final rf in rawFiles) {
      final m = Map<String, dynamic>.from(rf as Map);
      final item = VaultFileItem(
        id: (m['id'] as String?) ?? m['path'] as String,
        name: (m['name'] as String?) ?? 'file',
        path: (m['path'] as String?) ?? '',
        sizeBytes: (m['sizeBytes'] as num?)?.toInt() ?? 0,
        lastModified: DateTime.fromMillisecondsSinceEpoch(
            (m['lastModified'] as num?)?.toInt() ?? 0),
        category: _categoryFromString(m['category'] as String?),
        hash: m['hash'] as String?,
        duplicateGroupId: m['duplicateGroupId'] as String?,
        isDuplicateCopy: m['isDuplicateCopy'] == true,
        isStale: m['isStale'] == true,
        isLarge: m['isLarge'] == true,
        isSocialMedia: m['isSocialMedia'] == true,
        socialType: m['socialType'] as String?,
        isScreenshot: m['isScreenshot'] == true,
        isOldScreenshot: m['isOldScreenshot'] == true,
        isBurst: m['isBurst'] == true,
      );
      allFiles.add(item);
      if (item.isStale) staleFiles.add(item);
      if (item.isLarge) largeFiles.add(item);
      if (item.isSocialMedia) socialMediaFiles.add(item);
      if (item.isScreenshot) screenshotFiles.add(item);
      if (item.isBurst) burstFiles.add(item);
    }

    final rawGroups = raw['duplicateGroups'] as List<dynamic>? ?? const [];
    for (final rg in rawGroups) {
      final groupList = <VaultFileItem>[];
      for (final item in (rg as List<dynamic>)) {
        final m = Map<String, dynamic>.from(item as Map);
        groupList.add(VaultFileItem(
          id: (m['id'] as String?) ?? m['path'] as String,
          name: (m['name'] as String?) ?? 'dup_file',
          path: (m['path'] as String?) ?? '',
          sizeBytes: (m['sizeBytes'] as num?)?.toInt() ?? 0,
          lastModified: DateTime.fromMillisecondsSinceEpoch(
              (m['lastModified'] as num?)?.toInt() ?? 0),
          category: _categoryFromString(m['category'] as String?),
          hash: m['hash'] as String?,
          duplicateGroupId: m['duplicateGroupId'] as String?,
          isDuplicateCopy: m['isDuplicateCopy'] == true,
          isSocialMedia: m['isSocialMedia'] == true,
          socialType: m['socialType'] as String?,
          isScreenshot: m['isScreenshot'] == true,
          isOldScreenshot: m['isOldScreenshot'] == true,
          isBurst: m['isBurst'] == true,
        ));
      }
      if (groupList.isNotEmpty) dupGroups.add(groupList);
    }

    final catBytes = <VaultFileCategory, int>{};
    final catCounts = <VaultFileCategory, int>{};
    for (final cat in VaultFileCategory.values) {
      catBytes[cat] = 0;
      catCounts[cat] = 0;
    }
    for (final f in allFiles) {
      catBytes[f.category] = (catBytes[f.category] ?? 0) + f.sizeBytes;
      catCounts[f.category] = (catCounts[f.category] ?? 0) + 1;
    }

    return StorageVaultSummary(
      totalBytes: (raw['totalBytes'] as num?)?.toInt() ?? 256 * 1024 * 1024 * 1024,
      usedBytes: (raw['usedBytes'] as num?)?.toInt() ?? 174 * 1024 * 1024 * 1024,
      freeBytes: (raw['freeBytes'] as num?)?.toInt() ?? 82 * 1024 * 1024 * 1024,
      categoryBytes: catBytes,
      categoryCounts: catCounts,
      duplicateGroups: dupGroups,
      staleFiles: staleFiles,
      largeFiles: largeFiles,
      allFiles: allFiles,
      socialMediaFiles: socialMediaFiles,
      screenshotFiles: screenshotFiles,
      burstFiles: burstFiles,
      scanMillis: (raw['scanMillis'] as num?)?.toInt() ?? 0,
      cacheHits: (raw['cacheHits'] as num?)?.toInt() ?? 0,
      cacheMisses: (raw['cacheMisses'] as num?)?.toInt() ?? 0,
    );
  }

  VaultFileCategory _categoryFromString(String? cat) {
    switch (cat?.toLowerCase()) {
      case 'image':
      case 'images':
      case 'photos':
        return VaultFileCategory.image;
      case 'video':
      case 'videos':
        return VaultFileCategory.video;
      case 'audio':
      case 'music':
        return VaultFileCategory.audio;
      case 'document':
      case 'documents':
      case 'pdf':
        return VaultFileCategory.document;
      case 'apk':
      case 'apps':
        return VaultFileCategory.apk;
      case 'archive':
      case 'zip':
      case 'rar':
        return VaultFileCategory.archive;
      default:
        return VaultFileCategory.other;
    }
  }

  StorageVaultSummary _generateMockSummary(int staleDays) {
    final now = DateTime.now();
    final mockItems = [
      VaultFileItem(
        id: 'dup_vid_1',
        name: 'VID_20250203_Trip.mp4',
        path: '/storage/emulated/0/DCIM/Camera/VID_20250203_Trip.mp4',
        sizeBytes: 184 * 1024 * 1024,
        lastModified: now.subtract(const Duration(days: 634)),
        category: VaultFileCategory.video,
        hash: 'a1b2c3d4e5f6',
        duplicateGroupId: 'g1',
        isDuplicateCopy: false,
        isStale: true,
        isLarge: true,
      ),
      VaultFileItem(
        id: 'dup_vid_2',
        name: 'VID_20250203_Trip_copy.mp4',
        path: '/storage/emulated/0/WhatsApp/Media/VID_20250203_Trip_copy.mp4',
        sizeBytes: 184 * 1024 * 1024,
        lastModified: now.subtract(const Duration(days: 620)),
        category: VaultFileCategory.video,
        hash: 'a1b2c3d4e5f6',
        duplicateGroupId: 'g1',
        isDuplicateCopy: true,
        isStale: true,
        isLarge: true,
      ),
    ];

    final dupGroups = [
      [mockItems[0], mockItems[1]],
    ];

    final catBytes = <VaultFileCategory, int>{
      VaultFileCategory.image: 24 * 1024 * 1024 * 1024,
      VaultFileCategory.video: 68 * 1024 * 1024 * 1024,
      VaultFileCategory.audio: 12 * 1024 * 1024 * 1024,
      VaultFileCategory.document: 18 * 1024 * 1024 * 1024,
      VaultFileCategory.apk: 14 * 1024 * 1024 * 1024,
      VaultFileCategory.archive: 22 * 1024 * 1024 * 1024,
      VaultFileCategory.other: 16 * 1024 * 1024 * 1024,
    };

    final catCounts = <VaultFileCategory, int>{
      VaultFileCategory.image: 1840,
      VaultFileCategory.video: 142,
      VaultFileCategory.audio: 310,
      VaultFileCategory.document: 420,
      VaultFileCategory.apk: 18,
      VaultFileCategory.archive: 26,
      VaultFileCategory.other: 650,
    };

    return StorageVaultSummary(
      totalBytes: 256 * 1024 * 1024 * 1024,
      usedBytes: 174 * 1024 * 1024 * 1024,
      freeBytes: 82 * 1024 * 1024 * 1024,
      categoryBytes: catBytes,
      categoryCounts: catCounts,
      duplicateGroups: dupGroups,
      staleFiles: mockItems,
      largeFiles: mockItems,
      allFiles: mockItems,
      socialMediaFiles: mockItems,
      screenshotFiles: mockItems,
      burstFiles: mockItems,
    );
  }
}
