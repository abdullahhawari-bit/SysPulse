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
  final int _staleDays = 60;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      appBar: AppBar(
        backgroundColor: const Color(0xFF030712),
        elevation: 0,
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storage Vault & Archiver',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Duplicate Cleaner & Cloud Backup',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
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
                ListView(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 115),
                  children: [
                    _buildCompactOverviewCard(_summary!),
                    const SizedBox(height: 12),
                    _buildTabPills(),
                    const SizedBox(height: 12),
                    _buildSectionHeader(),
                    const SizedBox(height: 8),
                    ..._buildFileList(),
                  ],
                ),
                _buildStickyBottomBar(),
              ],
            ),
    );
  }

  Widget _buildCompactOverviewCard(StorageVaultSummary s) {
    final usedGb = (s.usedBytes / (1024 * 1024 * 1024)).toStringAsFixed(1);
    final totalGb = (s.totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(0);
    final pct = (s.usedPercentage * 100).toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.storage_rounded, size: 18, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 8),
                  Text(
                    'Storage: $usedGb GB / $totalGb GB',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$pct% used',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: s.usedPercentage,
              minHeight: 6,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: VaultFileCategory.values.map((cat) {
                final bytes = s.categoryBytes[cat] ?? 0;
                final count = s.categoryCounts[cat] ?? 0;
                if (count == 0 && bytes == 0) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cat.color.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat.icon, size: 12, color: cat.color),
                      const SizedBox(width: 5),
                      Text(
                        '${cat.displayName}: ${_formatBytes(bytes)}',
                        style: const TextStyle(
                          fontSize: 10,
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

  Widget _buildTabPills() {
    return Row(
      children: [
        _buildPillTab('duplicates', 'Duplicates', _formatBytes(_summary!.totalDuplicateWasteBytes)),
        const SizedBox(width: 6),
        _buildPillTab('stale', 'Dormant', _formatBytes(_summary!.totalStaleBytes)),
        const SizedBox(width: 6),
        _buildPillTab('large', 'Large Files', _formatBytes(_summary!.totalLargeBytes)),
        const SizedBox(width: 6),
        _buildPillTab('all', 'All Files', '${_summary!.allFiles.length}'),
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF38BDF8).withOpacity(0.18) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? const Color(0xFF38BDF8) : Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: active ? const Color(0xFFBAE6FD) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    final files = _getFilteredFiles();
    final allSelected = files.isNotEmpty && files.every((f) => _selectedFileIds.contains(f.id));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Files (${files.length})',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE2E8F0),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                Icon(
                  allSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  size: 16,
                  color: const Color(0xFF38BDF8),
                ),
                const SizedBox(width: 4),
                Text(
                  allSelected ? 'Deselect All' : 'Select All',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ],
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
          padding: const EdgeInsets.all(28),
          alignment: Alignment.center,
          child: const Column(
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 40, color: Color(0xFF10B981)),
              SizedBox(height: 10),
              Text(
                'No files found in this category. Clean & optimized!',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ];
    }

    return files.map((file) {
      final selected = _selectedFileIds.contains(file.id);
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF38BDF8).withOpacity(0.4) : const Color(0xFF1E293B),
          ),
        ),
        child: InkWell(
          onTap: () => _toggleFileSelection(file.id),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: file.category.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(file.category.icon, color: file.category.color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            file.formattedSize,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '• ${file.formattedAge}',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                          ),
                          if (file.isDuplicateCopy) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFB7185).withOpacity(0.18),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Duplicate',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFB7185),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.85,
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
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0B132B).withOpacity(0.96),
          border: const Border(top: BorderSide(color: Color(0xFF1E293B))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count files selected',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                  Text(
                    totalSizeStr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: count > 0 ? _showCompressAndOffloadModal : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF020617),
                disabledBackgroundColor: const Color(0xFF1E293B),
                disabledForegroundColor: const Color(0xFF475569),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.cloud_upload_rounded, size: 18),
              label: const Text(
                'Archive & Offload',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
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
  CloudProvider _selectedProvider = CloudProvider.googleDrive;
  bool _compressing = false;
  bool _exporting = false;
  ArchiveCompressionResult? _archiveResult;
  bool _readyToFreeSpace = false;

  Future<void> _startProcess() async {
    setState(() => _compressing = true);

    final res = await _service.compressFiles(widget.selectedFiles);
    if (!mounted) return;

    setState(() {
      _compressing = false;
      _archiveResult = res;
      _exporting = true;
    });

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
                  const SizedBox(height: 14),
                  Text(
                    'Exporting to ${_selectedProvider.displayName}...',
                    style: const TextStyle(fontSize: 13, color: Color(0xFFBAE6FD)),
                  ),
                ],
              ),
            ),
          ] else if (_readyToFreeSpace) ...[
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
                ],
              ),
            ),
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
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Keep Originals on Phone',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ),
          ] else ...[
            const Text(
              'Select Cloud Destination:',
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
                'Compress & Offload to Cloud',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
