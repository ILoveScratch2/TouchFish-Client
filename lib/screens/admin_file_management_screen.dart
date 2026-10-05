import 'package:flutter/material.dart';
import '../services/auth_state.dart';
import '../services/api/tf_api_client.dart';
import '../services/snackbar_service.dart';
import '../widgets/admin_ui.dart';
import '../l10n/app_localizations.dart';
import '../models/file_attachment.dart';
import '../widgets/file_attachment_view.dart';
import '../widgets/sheet_scaffold.dart';

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

  void _clearUidFilter() {
    _uidFilterController.clear();
    _applyUidFilter();
    _loadAllFiles();
  }

  Future<void> _forceDeleteFile(Map<String, dynamic> file) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final l10n = AppLocalizations.of(context)!;
    final hash = file['hash'] as String? ?? '';
    final fileName = file['file_name'] as String? ?? l10n.adminFileUnknown;
    final fileOwner =
        file['username'] as String? ??
        file['uid']?.toString() ??
        l10n.adminFileUnknown;

    final confirmed = await showAdminConfirmDialog(
      context,
      title: l10n.adminFileForceDeleteTitle,
      message: l10n.adminFileForceDeleteConfirm(fileName, fileOwner),
      confirmLabel: l10n.adminFileForceDelete,
      icon: Icons.warning_amber_rounded,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final ok = await TfApiClient.instance.adminForceDeleteFile(
      uid,
      password,
      hash,
    );
    if (!mounted) return;
    if (ok) {
      TouchFishSnackbarService.instance.show(l10n.adminFileForceDeleted(fileName));
      await _loadAllFiles();
    } else {
      TouchFishSnackbarService.instance.show(l10n.adminFileForceDeleteFailed);
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

    return AdminPageScaffold(
      title: l10n.adminFileManagement,
      maxWidth: 960,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: l10n.storageRefresh,
          onPressed: _isLoading ? null : _loadAllFiles,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilterBar(l10n),
          const Divider(height: 1),
          _buildSummaryBar(l10n, colorScheme),
          const Divider(height: 1),
          Expanded(child: _buildBody(l10n)),
        ],
      ),
    );
  }

  Widget _buildFilterBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: AdminSearchField(
              controller: _uidFilterController,
              hintText: l10n.adminFileFilterUid,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                if (value.trim().isEmpty && _filterUid != null) {
                  _clearUidFilter();
                }
              },
              onSubmitted: (_) => _applyUidFilter(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: _applyUidFilter,
            child: Text(l10n.adminFileFilter),
          ),
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
      child: Text(
        l10n.adminFileSummaryStats(
          _filteredFiles.length,
          uniqueUsers,
          _formatSize(totalSize),
        ),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadAllFiles,
      child: _error != null
          ? AdminErrorState(
              message: l10n.adminFileLoadFailed,
              onRetry: _loadAllFiles,
            )
          : _filteredFiles.isEmpty
          ? AdminEmptyState(
              message: _filterUid != null
                  ? l10n.adminFileNoFilesForUid('$_filterUid')
                  : l10n.adminFileNoFiles,
              icon: Icons.inventory_2_outlined,
            )
          : ListView.builder(
              itemCount: _filteredFiles.length,
              itemBuilder: (context, index) =>
                  _buildFileTile(_filteredFiles[index], l10n),
            ),
    );
  }

  Widget _buildFileTile(Map<String, dynamic> file, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    final fileName = file['file_name'] as String? ?? l10n.adminFileUnknown;
    final fileOwner =
        file['username'] as String? ?? l10n.adminFileUnknown;
    final fileUid = file['uid']?.toString() ?? '?';
    final size = (file['size'] as num?)?.toInt() ?? 0;
    final refCount = (file['ref_count'] as num?)?.toInt() ?? 0;
    final uploadCount = (file['upload_user_count'] as num?)?.toInt() ?? 0;

    return ListTile(
      leading: const Icon(Icons.insert_drive_file),
      title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        l10n.adminFileTileMeta(
          fileOwner,
          fileUid,
          _formatSize(size),
          refCount,
          uploadCount,
        ),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () => _showFileActions(file),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined),
            onPressed: () => _showFileActions(file),
            tooltip: l10n.filePreview,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            color: colorScheme.error,
            onPressed: () => _forceDeleteFile(file),
            tooltip: l10n.adminFileForceDelete,
          ),
        ],
      ),
    );
  }

  Future<void> _showFileActions(Map<String, dynamic> file) {
    final attachment = FileAttachment.fromMap(file);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SheetScaffold(
        titleText: attachment.fileName,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FileAttachmentView(
            attachment: attachment,
            allowAutomaticPreview: false,
          ),
        ),
      ),
    );
  }
}
