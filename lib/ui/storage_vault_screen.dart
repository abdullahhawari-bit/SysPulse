import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/local_web_server_service.dart';
import '../services/storage_vault_service.dart';

// ============================================================================
// STORAGE VAULT SCREEN (100% ENGLISH • UNCLUTTERED • VERTICAL RAIL LAYOUT)
// ============================================================================

class StorageVaultScreen extends StatefulWidget {
  const StorageVaultScreen({super.key});

  @override
  State<StorageVaultScreen> createState() => _StorageVaultScreenState();
}

class _StorageVaultScreenState extends State<StorageVaultScreen> {
  final StorageVaultService _service = StorageVaultService.instance;
  StorageVaultSummary? _summary;
  bool _loading = true;
  final int _staleDays = 60;
  String _activeTab = 'duplicates'; // 'duplicates', 'social', 'screenshots', 'stale', 'large', 'all'
  String _socialSubFilter = 'all'; // 'all', 'sent', 'voice_notes', 'status'
  String _screenshotSubFilter = 'all'; // 'all', 'old', 'burst'
  final Set<String> _selectedFileIds = {};

  @override
  void initState() {
    super.initState();
    _loadVaultData();
  }

  Future<void> _loadVaultData() async {
    setState(() => _loading = true);
    final data = await _service.scanStorage(staleDays: _staleDays);
    if (!mounted) return;
    setState(() {
      _summary = data;
      _loading = false;
      _autoSelectCurrentTab(data);
    });
  }

  void _autoSelectCurrentTab(StorageVaultSummary summary) {
    _selectedFileIds.clear();
    if (_activeTab == 'duplicates') {
      for (final group in summary.duplicateGroups) {
        if (group.length > 1) {
          for (var i = 1; i < group.length; i++) {
            _selectedFileIds.add(group[i].id);
          }
        }
      }
    } else if (_activeTab == 'social') {
      // Auto-select sent duplicates & status caches (safe to clean!)
      for (final f in summary.socialMediaFiles) {
        if (f.socialType == 'sent' || f.socialType == 'status') {
          _selectedFileIds.add(f.id);
        }
      }
    } else if (_activeTab == 'screenshots') {
      // Auto-select old screenshots > 30 days
      for (final f in summary.screenshotFiles) {
        if (f.isOldScreenshot) {
          _selectedFileIds.add(f.id);
        }
      }
    } else if (_activeTab == 'stale') {
      for (final file in summary.staleFiles) {
        _selectedFileIds.add(file.id);
      }
    }
  }

  List<VaultFileItem> _getFilteredFiles() {
    if (_summary == null) return const [];
    switch (_activeTab) {
      case 'duplicates':
        final list = <VaultFileItem>[];
        for (final g in _summary!.duplicateGroups) {
          list.addAll(g);
        }
        return list;

      case 'social':
        switch (_socialSubFilter) {
          case 'sent':
            return _summary!.socialMediaFiles
                .where((f) => f.socialType == 'sent')
                .toList();
          case 'voice_notes':
            return _summary!.socialMediaFiles
                .where((f) => f.socialType == 'voice_note')
                .toList();
          case 'status':
            return _summary!.socialMediaFiles
                .where((f) => f.socialType == 'status')
                .toList();
          case 'all':
          default:
            return _summary!.socialMediaFiles;
        }

      case 'screenshots':
        switch (_screenshotSubFilter) {
          case 'old':
            return _summary!.screenshotFiles
                .where((f) => f.isOldScreenshot)
                .toList();
          case 'burst':
            return _summary!.burstFiles;
          case 'all':
          default:
            return _summary!.screenshotFiles;
        }

      case 'stale':
        return _summary!.staleFiles;
      case 'large':
        return _summary!.largeFiles;
      case 'all':
      default:
        return _summary!.allFiles;
    }
  }

  int get _selectedTotalBytes {
    if (_summary == null) return 0;
    var total = 0;
    for (final f in _summary!.allFiles) {
      if (_selectedFileIds.contains(f.id)) {
        total += f.sizeBytes;
      }
    }
    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void _toggleFileSelection(String id) {
    setState(() {
      if (_selectedFileIds.contains(id)) {
        _selectedFileIds.remove(id);
      } else {
        _selectedFileIds.add(id);
      }
    });
  }

  // --- ACTIONS: PREVIEW FILE ---
  void _openFilePreviewModal(VaultFileItem file) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _FilePreviewModal(
        file: file,
        onDeleteRequested: () {
          Navigator.pop(ctx);
          _confirmDeleteSingleFile(file);
        },
        onUninstallRequested: () {
          Navigator.pop(ctx);
          _confirmUninstallApp(file);
        },
      ),
    );
  }

  // --- ACTIONS: DELETE SINGLE FILE ---
  void _confirmDeleteSingleFile(VaultFileItem file) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFFB7185), size: 22),
            SizedBox(width: 8),
            Text(
              'Delete File?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete:\n"${file.name}"?\n\nThis will free up ${file.formattedSize} immediately.',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFB7185),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.deleteSingleFile(file);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted "${file.name}" (${file.formattedSize} freed)'),
                ),
              );
              _loadVaultData();
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  // --- ACTIONS: BATCH DELETE SELECTED FILES ---
  void _confirmDeleteSelectedFiles() {
    final selectedFiles = _summary!.allFiles
        .where((f) => _selectedFileIds.contains(f.id))
        .toList();

    if (selectedFiles.isEmpty) return;

    final freedStr = _formatBytes(_selectedTotalBytes);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: Color(0xFFFB7185), size: 24),
            const SizedBox(width: 8),
            Text(
              'Delete ${selectedFiles.length} Files?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete all ${selectedFiles.length} selected files?\n\nReclaimed storage: $freedStr.\nThis action cannot be undone.',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFB7185),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _service.deleteArchivedFiles(selectedFiles);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Deleted ${res['deletedCount']} files! Reclaimed ${_formatBytes(res['freedBytes'] as int)} 🎉',
                  ),
                ),
              );
              _loadVaultData();
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  // --- ACTIONS: UNINSTALL APP ---
  void _confirmUninstallApp(VaultFileItem file) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFFB7185), size: 22),
            SizedBox(width: 8),
            Text(
              'Uninstall App?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'SysPulse will open the Android system uninstaller for this APK package (${file.name}).\nDo you want to proceed?',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFB7185),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _service.openFilePreview(file);
            },
            child: const Text('Open Uninstaller'),
          ),
        ],
      ),
    );
  }

  // --- ACTIONS: COMPRESS & CLOUD OFFLOAD ---
  void _showCompressAndOffloadModal() {
    final selectedFiles = _summary!.allFiles
        .where((f) => _selectedFileIds.contains(f.id))
        .toList();

    if (selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one file to archive.'),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B132B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CloudArchiverModal(
        selectedFiles: selectedFiles,
        onArchivedAndDeleted: () {
          Navigator.pop(ctx);
          _loadVaultData();
        },
      ),
    );
  }

  void _showWifiPcTransferModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _WifiPcTransferSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      appBar: AppBar(
        backgroundColor: const Color(0xFF030712),
        elevation: 0,
        titleSpacing: 14,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storage Vault & Cleaner',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Smart Cleanup • Duplicate Scanner • Cloud Archiver',
              style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Wi-Fi PC Transfer',
            icon: const Icon(Icons.wifi_tethering_rounded, color: Color(0xFF10B981), size: 22),
            onPressed: _showWifiPcTransferModal,
          ),
          IconButton(
            tooltip: 'Rescan Storage',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF38BDF8), size: 22),
            onPressed: _loadVaultData,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading || _summary == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
            )
          : Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LEFT COLUMN: VERTICAL NAVIGATION RAIL TABS
                    _buildLeftVerticalRail(),

                    // RIGHT COLUMN: EXPANDED CONTENT AREA
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildRightHeader(),
                          Expanded(
                            child: _buildRightFileList(),
                          ),
                          // Space for floating sticky action bar
                          const SizedBox(height: 70),
                        ],
                      ),
                    ),
                  ],
                ),

                // PERSISTENT FLOATING BOTTOM ACTION BAR
                _buildStickyBottomBar(),
              ],
            ),
    );
  }

  // ==========================================================================
  // LEFT COLUMN: VERTICAL RAIL FOR DUPLICATES, DORMANT, LARGE, ALL FILES
  // ==========================================================================
  Widget _buildLeftVerticalRail() {
    return Container(
      width: 98,
      decoration: const BoxDecoration(
        color: Color(0xFF090D16),
        border: Border(
          right: BorderSide(color: Color(0xFF1E293B)),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
        children: [
          _buildVerticalRailTab(
            key: 'duplicates',
            title: 'Duplicates',
            icon: Icons.copy_all_rounded,
            badge: _formatBytes(_summary!.totalDuplicateWasteBytes),
            activeColor: const Color(0xFF38BDF8),
          ),
          const SizedBox(height: 8),
          _buildVerticalRailTab(
            key: 'social',
            title: 'Social Media',
            icon: Icons.chat_bubble_outline_rounded,
            badge: _formatBytes(_summary!.totalSocialMediaBytes),
            activeColor: const Color(0xFF10B981),
          ),
          const SizedBox(height: 8),
          _buildVerticalRailTab(
            key: 'screenshots',
            title: 'Screenshots',
            icon: Icons.screenshot_monitor_rounded,
            badge: _formatBytes(_summary!.totalScreenshotBytes),
            activeColor: const Color(0xFFFB7185),
          ),
          const SizedBox(height: 8),
          _buildVerticalRailTab(
            key: 'stale',
            title: 'Dormant',
            icon: Icons.snooze_rounded,
            badge: _formatBytes(_summary!.totalStaleBytes),
            activeColor: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 8),
          _buildVerticalRailTab(
            key: 'large',
            title: 'Large Files',
            icon: Icons.fitness_center_rounded,
            badge: _formatBytes(_summary!.totalLargeBytes),
            activeColor: const Color(0xFFA855F7),
          ),
          const SizedBox(height: 8),
          _buildVerticalRailTab(
            key: 'all',
            title: 'All Files',
            icon: Icons.folder_copy_rounded,
            badge: '${_summary!.allFiles.length}',
            activeColor: const Color(0xFF06B6D4),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalRailTab({
    required String key,
    required String title,
    required IconData icon,
    required String badge,
    required Color activeColor,
  }) {
    final active = _activeTab == key;
    return InkWell(
      onTap: () {
        setState(() {
          _activeTab = key;
          _autoSelectCurrentTab(_summary!);
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 5),
        decoration: BoxDecoration(
          color: active ? activeColor.withOpacity(0.16) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? activeColor : const Color(0xFF1E293B),
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: active ? activeColor : const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10.0,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? Colors.white : const Color(0xFF94A3B8),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: active ? activeColor.withOpacity(0.22) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    badge,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 9.0,
                      fontWeight: FontWeight.w700,
                      color: active ? activeColor : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // RIGHT AREA: HEADER (COMPACT STORAGE BAR & SELECTION CONTROLS)
  // ==========================================================================
  Widget _buildRightHeader() {
    final s = _summary!;
    final usedGb = (s.usedBytes / (1024 * 1024 * 1024)).toStringAsFixed(1);
    final totalGb = (s.totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(0);
    final pct = (s.usedPercentage * 100).toInt();

    final files = _getFilteredFiles();
    final allSelected = files.isNotEmpty && files.every((f) => _selectedFileIds.contains(f.id));

    String sectionTitle;
    switch (_activeTab) {
      case 'duplicates':
        sectionTitle = 'Duplicates (${files.length})';
        break;
      case 'social':
        sectionTitle = 'WhatsApp & Telegram (${files.length})';
        break;
      case 'screenshots':
        sectionTitle = 'Screenshots & Bursts (${files.length})';
        break;
      case 'stale':
        sectionTitle = 'Dormant 60d+ (${files.length})';
        break;
      case 'large':
        sectionTitle = 'Large Files >25MB (${files.length})';
        break;
      case 'all':
      default:
        sectionTitle = 'All Storage (${files.length})';
        break;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: const BoxDecoration(
        color: Color(0xFF030712),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact Storage Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Storage: $usedGb / $totalGb GB',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE2E8F0),
                ),
              ),
              Text(
                '$pct% used',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF38BDF8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: s.usedPercentage,
              minHeight: 5,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
            ),
          ),
          if (s.scanMillis > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Scan: ${(s.scanMillis / 1000).toStringAsFixed(2)}s  •  Cache hits: ${s.cacheHits}  •  New hashes: ${s.cacheMisses}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
            ),
          ],
          const SizedBox(height: 8),

          // Section Title & Select All Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  sectionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    if (allSelected) {
                      for (final f in files) {
                        _selectedFileIds.remove(f.id);
                      }
                    } else {
                      for (final f in files) {
                        _selectedFileIds.add(f.id);
                      }
                    }
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        allSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        size: 15,
                        color: const Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        allSelected ? 'Deselect' : 'Select All',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Interactive Sub-filter Chips for Social Media & Screenshots
          if (_activeTab == 'social') ...[
            const SizedBox(height: 7),
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'AI Media Triage: Separate junk (voice notes, sent copies, status cache) from personal photos.',
                      style: TextStyle(fontSize: 10.5, color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedFileIds.clear();
                        for (final f in s.socialMediaFiles) {
                          if (f.socialType == 'sent' || f.socialType == 'status' || f.socialType == 'voice_note') {
                            _selectedFileIds.add(f.id);
                          }
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Selected WhatsApp Junk only. Personal photos preserved!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Triage Junk',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF020617)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSubFilterChip('All Media', 'all', _socialSubFilter == 'all',
                      () => setState(() => _socialSubFilter = 'all'), const Color(0xFF10B981)),
                  const SizedBox(width: 5),
                  _buildSubFilterChip('Sent Copies', 'sent', _socialSubFilter == 'sent',
                      () => setState(() => _socialSubFilter = 'sent'), const Color(0xFFFB7185)),
                  const SizedBox(width: 5),
                  _buildSubFilterChip('Voice Notes', 'voice_notes', _socialSubFilter == 'voice_notes',
                      () => setState(() => _socialSubFilter = 'voice_notes'), const Color(0xFFF59E0B)),
                  const SizedBox(width: 5),
                  _buildSubFilterChip('Status Cache', 'status', _socialSubFilter == 'status',
                      () => setState(() => _socialSubFilter = 'status'), const Color(0xFF38BDF8)),
                ],
              ),
            ),
          ] else if (_activeTab == 'screenshots') ...[
            const SizedBox(height: 7),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSubFilterChip('All (${s.screenshotFiles.length})', 'all',
                      _screenshotSubFilter == 'all',
                      () => setState(() => _screenshotSubFilter = 'all'), const Color(0xFFFB7185)),
                  const SizedBox(width: 5),
                  _buildSubFilterChip('Older >30d', 'old',
                      _screenshotSubFilter == 'old',
                      () => setState(() => _screenshotSubFilter = 'old'), const Color(0xFFF59E0B)),
                  const SizedBox(width: 5),
                  _buildSubFilterChip('Burst Shots', 'burst',
                      _screenshotSubFilter == 'burst',
                      () => setState(() => _screenshotSubFilter = 'burst'), const Color(0xFFA855F7)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubFilterChip(
      String label, String key, bool active, VoidCallback onTap, Color accent) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: active ? accent.withOpacity(0.2) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? accent : const Color(0xFF334155),
            width: active ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildCardTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ==========================================================================
  // RIGHT AREA: FILE LIST WITH IN-APP PREVIEW, DELETE & SELECT
  // ==========================================================================
  Widget _buildRightFileList() {
    final files = _getFilteredFiles();
    if (files.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline_rounded, size: 42, color: Color(0xFF10B981)),
              const SizedBox(height: 10),
              Text(
                'No files in this category.\nDevice is clean & optimized!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade300, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 20),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final selected = _selectedFileIds.contains(file.id);
        final isImage = file.category == VaultFileCategory.image;
        final isApk = file.category == VaultFileCategory.apk;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1E293B).withOpacity(0.65) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF38BDF8).withOpacity(0.5) : const Color(0xFF1E293B),
            ),
          ),
          child: InkWell(
            onTap: () => _toggleFileSelection(file.id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Row(
                children: [
                  // THUMBNAIL / AVATAR PREVIEW
                  GestureDetector(
                    onTap: () => _openFilePreviewModal(file),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: file.category.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: file.category.color.withOpacity(0.25)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: isImage
                          ? Image.file(
                              File(file.path),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                file.category.icon,
                                color: file.category.color,
                                size: 20,
                              ),
                            )
                          : Icon(
                              file.category.icon,
                              color: file.category.color,
                              size: 20,
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // FILE NAME & METADATA
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              file.formattedSize,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '• ${file.formattedAge}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                            if (file.isDuplicateCopy) ...[
                              const SizedBox(width: 5),
                              _buildCardTag('Duplicate', const Color(0xFFFB7185)),
                            ] else if (file.socialType == 'sent') ...[
                              const SizedBox(width: 5),
                              _buildCardTag('Sent Copy', const Color(0xFFFB7185)),
                            ] else if (file.socialType == 'voice_note') ...[
                              const SizedBox(width: 5),
                              _buildCardTag('Voice Note', const Color(0xFFF59E0B)),
                            ] else if (file.socialType == 'status') ...[
                              const SizedBox(width: 5),
                              _buildCardTag('Status', const Color(0xFF38BDF8)),
                            ] else if (file.isOldScreenshot) ...[
                              const SizedBox(width: 5),
                              _buildCardTag('Old Shot', const Color(0xFFFB7185)),
                            ] else if (file.isBurst) ...[
                              const SizedBox(width: 5),
                              _buildCardTag('Burst', const Color(0xFFA855F7)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // QUICK ACTION BUTTONS: PREVIEW, DELETE, UNINSTALL, CHECKBOX
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Preview icon button
                      IconButton(
                        tooltip: 'Preview File',
                        icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: Color(0xFF94A3B8)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => _openFilePreviewModal(file),
                      ),

                      // Delete icon button
                      IconButton(
                        tooltip: 'Delete File',
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFFB7185)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => _confirmDeleteSingleFile(file),
                      ),

                      // Selection Checkbox
                      Transform.scale(
                        scale: 0.8,
                        child: Checkbox(
                          value: selected,
                          activeColor: const Color(0xFF38BDF8),
                          checkColor: const Color(0xFF020617),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          side: const BorderSide(color: Color(0xFF475569)),
                          onChanged: (_) => _toggleFileSelection(file.id),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================================================
  // PERSISTENT BOTTOM BAR (DELETE SELECTED & CLOUD OFFLOAD)
  // ==========================================================================
  Widget _buildStickyBottomBar() {
    final count = _selectedFileIds.length;
    final totalSizeStr = _formatBytes(_selectedTotalBytes);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF090D16).withOpacity(0.96),
          border: const Border(top: BorderSide(color: Color(0xFF1E293B))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Selected files counter & size
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count files selected',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                  ),
                  Text(
                    totalSizeStr,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ],
              ),
            ),

            // Action: Delete Selected
            IconButton(
              tooltip: 'Delete Selected Files',
              onPressed: count > 0 ? _confirmDeleteSelectedFiles : null,
              style: IconButton.styleFrom(
                backgroundColor: count > 0 ? const Color(0xFFFB7185).withOpacity(0.18) : const Color(0xFF1E293B),
                foregroundColor: count > 0 ? const Color(0xFFFB7185) : const Color(0xFF475569),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.delete_sweep_rounded, size: 20),
            ),
            const SizedBox(width: 8),

            // Action: Archive & Cloud Offload
            ElevatedButton.icon(
              onPressed: count > 0 ? _showCompressAndOffloadModal : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF020617),
                disabledBackgroundColor: const Color(0xFF1E293B),
                disabledForegroundColor: const Color(0xFF475569),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.cloud_upload_rounded, size: 16),
              label: const Text(
                'Archive & Cloud',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// FILE PREVIEW MODAL (IMAGES, VIDEOS, APKS, DOCS)
// ============================================================================

class _FilePreviewModal extends StatelessWidget {
  final VaultFileItem file;
  final VoidCallback onDeleteRequested;
  final VoidCallback onUninstallRequested;

  const _FilePreviewModal({
    required this.file,
    required this.onDeleteRequested,
    required this.onUninstallRequested,
  });

  @override
  Widget build(BuildContext context) {
    final isImage = file.category == VaultFileCategory.image;
    final isVideo = file.category == VaultFileCategory.video;
    final isApk = file.category == VaultFileCategory.apk;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(file.category.icon, size: 20, color: file.category.color),
                  const SizedBox(width: 8),
                  Text(
                    '${file.category.displayName} Preview',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Main Visual Content
          if (isImage)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  color: Colors.black,
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.file(
                        File(file.path),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text(
                            'Unable to render image preview.',
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF030712),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(file.category.icon, size: 52, color: file.category.color),
                  const SizedBox(height: 12),
                  Text(
                    file.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${file.formattedSize} • ${file.formattedAge}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 14),

          // File Details
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF030712),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 3),
                Text(
                  file.path,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Action Buttons Row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF020617),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(
                    isVideo
                        ? Icons.play_arrow_rounded
                        : (isApk ? Icons.android_rounded : Icons.open_in_new_rounded),
                    size: 18,
                  ),
                  label: Text(
                    isVideo
                        ? 'Play Video'
                        : (isApk ? 'Open / Install' : 'Open in System App'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () {
                    StorageVaultService.instance.openFilePreview(file);
                  },
                ),
              ),
              const SizedBox(width: 8),
              if (isApk) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: const Color(0xFF020617),
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                  label: const Text('Uninstall', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: onUninstallRequested,
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                tooltip: 'Delete File',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFB7185).withOpacity(0.18),
                  foregroundColor: const Color(0xFFFB7185),
                  padding: const EdgeInsets.all(11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.delete_forever_rounded, size: 20),
                onPressed: onDeleteRequested,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPRESSION & CLOUD OFFLOAD MODAL (ENGLISH)
// ============================================================================

class _CloudArchiverModal extends StatefulWidget {
  final List<VaultFileItem> selectedFiles;
  final VoidCallback onArchivedAndDeleted;

  const _CloudArchiverModal({
    required this.selectedFiles,
    required this.onArchivedAndDeleted,
  });

  @override
  State<_CloudArchiverModal> createState() => _CloudArchiverModalState();
}

class _CloudArchiverModalState extends State<_CloudArchiverModal> {
  final StorageVaultService _service = StorageVaultService.instance;
  CloudProvider _selectedProvider = CloudProvider.localWifiPc;
  bool _compressing = false;
  bool _exporting = false;
  ArchiveCompressionResult? _archiveResult;
  bool _readyToFreeSpace = false;
  String? _wifiUrl;

  Future<void> _startProcess() async {
    setState(() => _compressing = true);

    final res = await _service.compressFiles(widget.selectedFiles);
    if (!mounted) return;

    setState(() {
      _compressing = false;
      _archiveResult = res;
      _exporting = true;
    });

    if (_selectedProvider == CloudProvider.localWifiPc) {
      final ok = await LocalWebServerService.instance.startServer(
        fileToShare: File(res.archivePath),
      );
      if (!mounted) return;
      setState(() {
        _exporting = false;
        if (ok) {
          _wifiUrl = LocalWebServerService.instance.currentStatus.url;
          _readyToFreeSpace = true;
        }
      });
    } else {
      final ok = await _service.exportToCloud(res.archivePath, _selectedProvider);
      if (!mounted) return;

      setState(() {
        _exporting = false;
        if (ok) _readyToFreeSpace = true;
      });
    }
  }

  Future<void> _freeUpSpace() async {
    await LocalWebServerService.instance.stopServer();
    await _service.deleteArchivedFiles(widget.selectedFiles);
    if (!mounted) return;
    widget.onArchivedAndDeleted();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Archive offloaded & original files safely cleaned! 🎉'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cloud Archiver & Offload',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_compressing) ...[
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF38BDF8)),
                  SizedBox(height: 14),
                  Text(
                    'Compressing into secure ZIP archive...',
                    style: TextStyle(fontSize: 13, color: Color(0xFFBAE6FD)),
                  ),
                ],
              ),
            ),
          ] else if (_exporting) ...[
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(color: Color(0xFFA855F7)),
                  SizedBox(height: 14),
                  Text(
                    'Preparing ${_selectedProvider.displayName}...',
                    style: const TextStyle(fontSize: 13, color: Color(0xFFBAE6FD)),
                  ),
                ],
              ),
            ),
          ] else if (_readyToFreeSpace) ...[
            if (_selectedProvider == CloudProvider.localWifiPc) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.wifi_tethering_rounded, size: 36, color: Color(0xFF10B981)),
                    const SizedBox(height: 8),
                    const Text(
                      'Wi-Fi PC Server Active! 🚀',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Open this link in your computer browser (Same Wi-Fi):',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.6)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SelectableText(
                            _wifiUrl ?? 'http://192.168.1.x:8080',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF38BDF8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF38BDF8)),
                            tooltip: 'Copy Link',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              if (_wifiUrl != null) {
                                Clipboard.setData(ClipboardData(text: _wifiUrl!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Server URL copied to clipboard!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    StreamBuilder<LocalServerStatus>(
                      stream: LocalWebServerService.instance.statusStream,
                      initialData: LocalWebServerService.instance.currentStatus,
                      builder: (context, snap) {
                        final status = snap.data;
                        final sentMb = ((status?.totalBytesSent ?? 0) / (1024 * 1024)).toStringAsFixed(1);
                        return Text(
                          'Direct Stream: $sentMb MB transferred to PC • 0 Internet Used',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_done_rounded, size: 38, color: Color(0xFF10B981)),
                    const SizedBox(height: 8),
                    const Text(
                      'Archived to Cloud Successfully! 🎉',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Saved ${_archiveResult?.spaceSavedFormatted ?? ''} with ${((_archiveResult?.spaceSavedRatio ?? 0) * 100).toInt()}% compression',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
                    ),
                    if (_archiveResult?.isMultiPart == true) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '📦 Cloud Arbitrage: Auto-split into ${_archiveResult?.partsCount} parts for free tiers',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF38BDF8)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _freeUpSpace,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFB7185),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Free Up Storage Now (Delete Originals)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () async {
                await LocalWebServerService.instance.stopServer();
                if (mounted) Navigator.pop(context);
              },
              child: const Text(
                'Keep Originals on Phone & Close',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ),
          ] else ...[
            const Text(
              'Select Archive & Transfer Mode:',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 10),
            ...CloudProvider.values.map((prov) {
              final active = _selectedProvider == prov;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF38BDF8).withOpacity(0.12) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                  ),
                ),
                child: ListTile(
                  dense: true,
                  onTap: () => setState(() => _selectedProvider = prov),
                  leading: Icon(prov.icon, size: 20, color: active ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8)),
                  title: Text(
                    prov.displayName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  trailing: Radio<CloudProvider>(
                    value: prov,
                    groupValue: _selectedProvider,
                    activeColor: const Color(0xFF38BDF8),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedProvider = val);
                    },
                  ),
                ),
              );
            }),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _startProcess,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF020617),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.archive_rounded, size: 18),
              label: const Text(
                'Compress & Start Transfer',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// STANDALONE WI-FI PC TRANSFER SHEET (P2P LOCAL SERVER)
// ============================================================================

class _WifiPcTransferSheet extends StatefulWidget {
  const _WifiPcTransferSheet();

  @override
  State<_WifiPcTransferSheet> createState() => _WifiPcTransferSheetState();
}

class _WifiPcTransferSheetState extends State<_WifiPcTransferSheet> {
  final _server = LocalWebServerService.instance;
  bool _starting = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LocalServerStatus>(
      stream: _server.statusStream,
      initialData: _server.currentStatus,
      builder: (context, snap) {
        final status = snap.data ?? _server.currentStatus;
        final isRunning = status.isRunning;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isRunning ? const Color(0xFF10B981) : const Color(0xFF38BDF8)).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.wifi_tethering_rounded,
                          color: isRunning ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Wi-Fi PC Direct Transfer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            isRunning ? 'Server Active • Ready for PC' : 'Local P2P Web Server (0 Data)',
                            style: TextStyle(
                              fontSize: 11,
                              color: isRunning ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!isRunning) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How it works:',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF38BDF8)),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '1. Tap "Start PC Server" below.\n2. Open Chrome or Edge on your computer (on the same Wi-Fi).\n3. Enter the local IP address to download phone files at up to 100 MB/s without internet.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFFCBD5E1), height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _starting
                      ? null
                      : () async {
                          setState(() => _starting = true);
                          await _server.startServer();
                          if (mounted) setState(() => _starting = false);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: const Color(0xFF020617),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _starting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text(
                    'Start PC Transfer Server',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Enter this URL into your computer browser:',
                        style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF030712),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF38BDF8)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SelectableText(
                              status.url,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF38BDF8),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF38BDF8)),
                              tooltip: 'Copy URL',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: status.url));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Address copied to clipboard!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('Transferred', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                              Text(
                                '${(status.totalBytesSent / (1024 * 1024)).toStringAsFixed(1)} MB',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('Connections', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                              Text(
                                '${status.activeConnections}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('Port', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                              Text(
                                '${status.port}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    await _server.stopServer();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444).withOpacity(0.2),
                    foregroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                    ),
                  ),
                  icon: const Icon(Icons.stop_rounded, size: 20),
                  label: const Text(
                    'Stop Transfer Server',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
