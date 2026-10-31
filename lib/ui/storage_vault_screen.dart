import 'package:flutter/material.dart';
import '../services/storage_vault_service.dart';

class StorageVaultScreen extends StatefulWidget {
  const StorageVaultScreen({super.key});

  @override
  State<StorageVaultScreen> createState() => _StorageVaultScreenState();
}

class _StorageVaultScreenState extends State<StorageVaultScreen> {
  final StorageVaultService _service = StorageVaultService.instance;
  StorageVaultSummary? _summary;
  bool _loading = true;
  int _staleDays = 60;
  String _activeTab = 'duplicates'; // 'duplicates', 'stale', 'large', 'all'
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
      // Automatically select duplicate copies by default for user convenience
      _autoSelectDuplicates(data);
    });
  }

  void _autoSelectDuplicates(StorageVaultSummary summary) {
    _selectedFileIds.clear();
    for (final group in summary.duplicateGroups) {
      if (group.length > 1) {
        for (var i = 1; i < group.length; i++) {
          _selectedFileIds.add(group[i].id);
        }
      }
    }
  }

  void _autoSelectStale(StorageVaultSummary summary) {
    _selectedFileIds.clear();
    for (final file in summary.staleFiles) {
      _selectedFileIds.add(file.id);
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

  void _showCompressAndOffloadModal() {
    final selectedFiles = _summary!.allFiles
        .where((f) => _selectedFileIds.contains(f.id))
        .toList();

    if (selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء تحديد ملف واحد على الأقل للأرشفة والترحيل'),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        elevation: 0,
        title: const Text(
          'خزنة التخزين والأرشفة السحابية',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'إعادة فحص التخزين',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF38BDF8)),
            onPressed: _loadVaultData,
          ),
        ],
      ),
      body: _loading || _summary == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
            )
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    _buildStorageOverviewCard(_summary!),
                    const SizedBox(height: 16),
                    _buildPillSelector(),
                    const SizedBox(height: 14),
                    _buildActionHeader(),
                    const SizedBox(height: 12),
                    ..._buildFileList(),
                  ],
                ),
                _buildStickyBottomBar(),
              ],
            ),
    );
  }

  Widget _buildStorageOverviewCard(StorageVaultSummary s) {
    final usedGb = (s.usedBytes / (1024 * 1024 * 1024)).toStringAsFixed(1);
    final totalGb = (s.totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(0);
    final pct = (s.usedPercentage * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'سعة التخزين المستخدمة',
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '$usedGb GB',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        ' / $totalGb GB',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF38BDF8).withOpacity(0.3)),
                ),
                child: Text(
                  '$pct% ممتلئ',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: s.usedPercentage,
              minHeight: 10,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
            ),
          ),
          const SizedBox(height: 16),
          // Categories horizontal breakdown
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: VaultFileCategory.values.map((cat) {
                final bytes = s.categoryBytes[cat] ?? 0;
                final count = s.categoryCounts[cat] ?? 0;
                return Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131D3B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cat.color.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(cat.icon, size: 16, color: cat.color),
                      const SizedBox(width: 6),
                      Text(
                        '${cat.displayNameAr}: ${_formatBytes(bytes)} ($count)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE2E8F0),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillSelector() {
    return Row(
      children: [
        _buildPillTab('duplicates', '👥 المكررات',
            _formatBytes(_summary!.totalDuplicateWasteBytes)),
        const SizedBox(width: 8),
        _buildPillTab(
            'stale', '❄️ الراكدة', _formatBytes(_summary!.totalStaleBytes)),
        const SizedBox(width: 8),
        _buildPillTab(
            'large', '🐘 الكبيرة', _formatBytes(_summary!.totalLargeBytes)),
        const SizedBox(width: 8),
        _buildPillTab('all', '📁 الكل', '${_summary!.allFiles.length}'),
      ],
    );
  }

  Widget _buildPillTab(String key, String title, String sub) {
    final active = _activeTab == key;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _activeTab = key;
            if (key == 'duplicates') {
              _autoSelectDuplicates(_summary!);
            } else if (key == 'stale') {
              _autoSelectStale(_summary!);
            }
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF38BDF8).withOpacity(0.18)
                : const Color(0xFF0B132B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? const Color(0xFF38BDF8)
                  : const Color(0xFF1E293B),
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? const Color(0xFF38BDF8) : Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 10,
                  color: active
                      ? const Color(0xFFBAE6FD)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionHeader() {
    final files = _getFilteredFiles();
    final allSelected =
        files.isNotEmpty && files.every((f) => _selectedFileIds.contains(f.id));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'قائمة الملفات (${files.length})',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE2E8F0),
          ),
        ),
        TextButton.icon(
          onPressed: () {
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
          icon: Icon(
            allSelected
                ? Icons.check_box_rounded
                : Icons.check_box_outline_blank_rounded,
            size: 18,
            color: const Color(0xFF38BDF8),
          ),
          label: Text(
            allSelected ? 'إلغاء تحديد الكل' : 'تحديد الكل',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF38BDF8),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFileList() {
    final files = _getFilteredFiles();
    if (files.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(32),
          alignment: Alignment.center,
          child: const Column(
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  size: 48, color: Color(0xFF10B981)),
              SizedBox(height: 12),
              Text(
                'لا توجد ملفات في هذا القسم، ذاكرة جهازك محسنة!',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ];
    }

    return files.map((file) {
      final selected = _selectedFileIds.contains(file.id);
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1E293B).withOpacity(0.6)
              : const Color(0xFF0B132B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFF38BDF8).withOpacity(0.5)
                : const Color(0xFF1E293B),
          ),
        ),
        child: ListTile(
          onTap: () => _toggleFileSelection(file.id),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: file.category.color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(file.category.icon,
                color: file.category.color, size: 22),
          ),
          title: Text(
            file.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          subtitle: Row(
            children: [
              Text(
                file.formattedSize,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '•  ${file.formattedAgeDays}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
              if (file.isDuplicateCopy) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFB7185).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'نسخة مكررة',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFB7185),
                    ),
                  ),
                ),
              ],
            ],
          ),
          trailing: Checkbox(
            value: selected,
            activeColor: const Color(0xFF38BDF8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            onChanged: (_) => _toggleFileSelection(file.id),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildStickyBottomBar() {
    final count = _selectedFileIds.length;
    final totalSizeStr = _formatBytes(_selectedTotalBytes);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.95),
          border: const Border(top: BorderSide(color: Color(0xFF1E293B))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'المحدد: $count ملفات',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                Text(
                  'المساحة: $totalSizeStr',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: count > 0 ? _showCompressAndOffloadModal : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF020617),
                disabledBackgroundColor: const Color(0xFF334155),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.cloud_upload_rounded, size: 20),
              label: const Text(
                'ضغط وترحيل سحابي',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// COMPRESSION & CLOUD OFFLOAD MODAL BOTTOM SHEET
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
  CloudProvider _selectedProvider = CloudProvider.googleDrive;
  bool _compressing = false;
  bool _exporting = false;
  ArchiveCompressionResult? _archiveResult;
  bool _readyToFreeSpace = false;

  Future<void> _startProcess() async {
    setState(() => _compressing = true);

    // 1. Compress into local ZIP
    final res = await _service.compressFiles(widget.selectedFiles);
    if (!mounted) return;

    setState(() {
      _compressing = false;
      _archiveResult = res;
      _exporting = true;
    });

    // 2. Export to chosen cloud provider
    final ok = await _service.exportToCloud(res.archivePath, _selectedProvider);
    if (!mounted) return;

    setState(() {
      _exporting = false;
      if (ok) _readyToFreeSpace = true;
    });
  }

  Future<void> _freeUpSpace() async {
    await _service.deleteArchivedFiles(widget.selectedFiles);
    if (!mounted) return;
    widget.onArchivedAndDeleted();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم ترحيل الأرشيف بنجاح وحذف الملفات الأصلية لتفريغ المساحة! 🎉',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الأرشفة والترحيل السحابي',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_compressing) ...[
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF38BDF8)),
                  SizedBox(height: 16),
                  Text(
                    'جاري ضغط الملفات وتجهيز أرشيف ZIP...',
                    style: TextStyle(fontSize: 14, color: Color(0xFFBAE6FD)),
                  ),
                ],
              ),
            ),
          ] else if (_exporting) ...[
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(color: Color(0xFFA855F7)),
                  const SizedBox(height: 16),
                  Text(
                    'جاري الإرسال إلى ${_selectedProvider.displayNameAr}...',
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFFBAE6FD)),
                  ),
                ],
              ),
            ),
          ] else if (_readyToFreeSpace) ...[
            // Success & Free Space Confirmation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cloud_done_rounded,
                      size: 44, color: Color(0xFF10B981)),
                  const SizedBox(height: 10),
                  const Text(
                    'تم الترحيل السحابي بنجاح! 🎉',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'تم توفير ${_archiveResult?.spaceSavedFormatted ?? ''} بنسبة ضغط ${((_archiveResult?.spaceSavedRatio ?? 0) * 100).toInt()}%',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFFE2E8F0)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _freeUpSpace,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFB7185),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'حذف الملفات الأصلية وتفريغ الذاكرة الآن',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'الاحتفاظ بالملفات الأصلية على الجهاز',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          ] else ...[
            // Provider Selection
            const Text(
              'اختر وجهة الترحيل السحابي:',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            ...CloudProvider.values.map((prov) {
              final active = _selectedProvider == prov;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF38BDF8).withOpacity(0.14)
                      : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF334155),
                  ),
                ),
                child: ListTile(
                  onTap: () => setState(() => _selectedProvider = prov),
                  leading: Icon(prov.icon,
                      color: active
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF94A3B8)),
                  title: Text(
                    prov.displayNameAr,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  trailing: Radio<CloudProvider>(
                    value: prov,
                    groupValue: _selectedProvider,
                    activeColor: const Color(0xFF38BDF8),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedProvider = val);
                      }
                    },
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _startProcess,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF020617),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.archive_rounded),
              label: const Text(
                'بدء الضغط والترحيل السحابي',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
