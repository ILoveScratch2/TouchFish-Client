import 'package:flutter/material.dart';
import '../services/auth_state.dart';
import '../services/api/tf_api_client.dart';
import '../widgets/app_alert_dialog.dart';
import '../l10n/app_localizations.dart';

class AdminFileManagementScreen extends StatefulWidget {
  const AdminFileManagementScreen({super.key});

  @override
  State<AdminFileManagementScreen> createState() =>
      _AdminFileManagementScreenState();
}

class _AdminFileManagementScreenState extends State<AdminFileManagementScreen> {
  List<Map<String, dynamic>> _allFiles = [];
  List<Map<String, dynamic>> _filteredFiles = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _uidFilterController = TextEditingController();
  int? _filterUid;

  @override
  void initState() {
    super.initState();
    _loadAllFiles();
  }

  @override
  void dispose() {
    _uidFilterController.dispose();
    super.dispose();
  }

  Future<void> _loadAllFiles() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final files = await TfApiClient.instance.adminGetAllFiles(
        uid,
        password,
        targetUid: _filterUid,
      );
      if (!mounted) return;
      setState(() {
        _allFiles = files;
        _filteredFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _applyUidFilter() {
    final text = _uidFilterController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _filterUid = null;
        _filteredFiles = _allFiles;
      });
    } else {
      final uid = int.tryParse(text);
      setState(() {
        _filterUid = uid;
        if (uid != null) {
          _filteredFiles = _allFiles.where((f) => f['uid'] == uid).toList();
        }
      });
    }
  }

  Future<void> _forceDeleteFile(Map<String, dynamic> file) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final l10n = AppLocalizations.of(context)!;
    final hash = file['hash'] as String? ?? '';
    final fileName = file['file_name'] as String? ?? 'Unknown';
    final fileOwner =
        file['username'] as String? ?? file['uid']?.toString() ?? 'Unknown';

    final confirmed = await showTouchFishErrorDialog<bool>(
      context,
      title: l10n.adminFileForceDeleteTitle,
      message: l10n.adminFileForceDeleteConfirm(fileName, fileOwner),
      icon: Icons.warning_amber_rounded,
      selectableMessage: false,
      actions: [
        TouchFishDialogAction<bool>(label: l10n.cancel, result: false),
        TouchFishDialogAction<bool>(
          label: l10n.adminFileForceDelete,
          result: true,
          isPrimary: true,
          isDestructive: true,
        ),
      ],
    );
    if (confirmed != true || !mounted) return;

    final ok = await TfApiClient.instance.adminForceDeleteFile(
      uid,
      password,
      hash,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.adminFileForceDeleted(fileName)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadAllFiles();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.adminFileForceDeleteFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminFileManagement),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.storageRefresh,
            onPressed: _isLoading ? null : _loadAllFiles,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(l10n, colorScheme),
          const Divider(height: 1),
          _buildSummaryBar(l10n, colorScheme),
          const Divider(height: 1),
          Expanded(child: _buildBody(l10n, colorScheme)),
        ],
      ),
    );
  }

  Widget _buildFilterBar(AppLocalizations l10n, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _uidFilterController,
              decoration: InputDecoration(
                hintText: l10n.adminFileFilterUid,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: _filterUid != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _uidFilterController.clear();
                          _applyUidFilter();
                        },
                      )
                    : null,
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _applyUidFilter(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _applyUidFilter,
            child: Text(l10n.adminFileFilter),
          ),
          if (_filterUid != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                _uidFilterController.clear();
                _applyUidFilter();
                _loadAllFiles();
              },
              child: Text(l10n.adminFileFilterClear),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryBar(AppLocalizations l10n, ColorScheme colorScheme) {
    final totalSize = _filteredFiles.fold<int>(
      0,
      (sum, f) => sum + ((f['size'] as num?)?.toInt() ?? 0),
    );
    final uniqueUsers = _filteredFiles.map((f) => f['uid']).toSet().length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Text(
            '${l10n.adminFileSummaryFiles}: ${_filteredFiles.length}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 16),
          Text(
            '${l10n.adminFileSummaryUsers}: $uniqueUsers',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 16),
          Text(
            '${l10n.adminFileSummaryTotal}: ${_formatSize(totalSize)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ColorScheme colorScheme) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: colorScheme.error)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAllFiles,
              child: Text(l10n.storageRetry),
            ),
          ],
        ),
      );
    }

    if (_filteredFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _filterUid != null
                  ? l10n.adminFileNoFilesForUid('$_filterUid')
                  : l10n.adminFileNoFiles,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllFiles,
      child: ListView.builder(
        itemCount: _filteredFiles.length,
        itemBuilder: (context, index) =>
            _buildFileTile(_filteredFiles[index], colorScheme, l10n),
      ),
    );
  }

  Widget _buildFileTile(
    Map<String, dynamic> file,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    final fileName = file['file_name'] as String? ?? 'Unknown';
    final fileOwner = file['username'] as String? ?? 'UID: ${file['uid']}';
    final fileUid = file['uid']?.toString() ?? '?';
    final size = (file['size'] as num?)?.toInt() ?? 0;
    final refCount = (file['ref_count'] as num?)?.toInt() ?? 0;
    final uploadCount = (file['upload_user_count'] as num?)?.toInt() ?? 0;

    return ListTile(
      leading: const Icon(Icons.insert_drive_file),
      title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        'Owner: $fileOwner (UID: $fileUid)  •  ${_formatSize(size)}  •  Refs: $refCount  •  Uploads: $uploadCount',
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_forever),
        color: colorScheme.error,
        onPressed: () => _forceDeleteFile(file),
        tooltip: l10n.adminFileForceDelete,
      ),
    );
  }
}
