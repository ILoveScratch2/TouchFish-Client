import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/auth_state.dart';
import '../services/api/tf_api_client.dart';
import '../widgets/app_alert_dialog.dart';
import '../l10n/app_localizations.dart';

class StorageManagementScreen extends StatefulWidget {
  const StorageManagementScreen({super.key});

  @override
  State<StorageManagementScreen> createState() => _StorageManagementScreenState();
}

class _StorageManagementScreenState extends State<StorageManagementScreen> {
  List<Map<String, dynamic>> _files = [];
  Map<String, dynamic>? _storageInfo;
  bool _isLoading = true;
  bool _isUploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) {
      setState(() {
        _isLoading = false;
        _error = 'notLoggedIn';
      });
      return;
    }

    try {
      final api = TfApiClient.instance;
      final results = await Future.wait([
        api.getUserFiles(uid, password),
        api.getStorageInfo(uid, password),
      ]);

      if (!mounted) return;
      setState(() {
        _files = results[0] as List<Map<String, dynamic>>;
        _storageInfo = results[1] as Map<String, dynamic>?;
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

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _uploadFile() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.storageCouldNotReadFile), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final maxSize = await TfApiClient.instance.getMaxFileSize();
    if (maxSize != null && bytes.length > maxSize) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.storageFileTooLarge((maxSize / (1024 * 1024)).round())),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final fileBase64 = base64.encode(bytes);
      final response = await TfApiClient.instance.uploadFile(uid, password, file.name, fileBase64);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      if (response != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.storageUploaded(file.name)), behavior: SnackBarBehavior.floating),
        );
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.storageUploadFailed), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.storageUploadError}: $e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteFile(String hash, String fileName) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showTouchFishErrorDialog<bool>(
      context,
      title: l10n.storageDeleteFile,
      message: l10n.storageDeleteConfirm(fileName),
      icon: Icons.delete_outline,
      selectableMessage: false,
      actions: [
        TouchFishDialogAction<bool>(label: l10n.cancel, result: false),
        TouchFishDialogAction<bool>(label: l10n.storageDeleteFile, result: true, isPrimary: true, isDestructive: true),
      ],
    );
    if (confirmed != true || !mounted) return;

    final ok = await TfApiClient.instance.deleteFile(uid, password, hash);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.storageDeleted(fileName)), behavior: SnackBarBehavior.floating),
      );
      await _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.storageDeleteFailed), behavior: SnackBarBehavior.floating),
      );
    }
  }

  IconData _fileIcon(String fileName) {
    final ext = fileName.toLowerCase();
    if (ext.endsWith('.png') || ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.gif') || ext.endsWith('.webp') || ext.endsWith('.bmp')) {
      return Icons.image;
    }
    if (ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.avi') || ext.endsWith('.mkv')) {
      return Icons.videocam;
    }
    if (ext.endsWith('.mp3') || ext.endsWith('.wav') || ext.endsWith('.ogg') || ext.endsWith('.flac')) {
      return Icons.audiotrack;
    }
    if (ext.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (ext.endsWith('.zip') || ext.endsWith('.rar') || ext.endsWith('.7z') || ext.endsWith('.tar') || ext.endsWith('.gz')) {
      return Icons.folder_zip;
    }
    if (ext.endsWith('.doc') || ext.endsWith('.docx')) return Icons.description;
    if (ext.endsWith('.xls') || ext.endsWith('.xlsx')) return Icons.table_chart;
    if (ext.endsWith('.ppt') || ext.endsWith('.pptx')) return Icons.slideshow;
    return Icons.insert_drive_file;
  }

  Color _fileIconColor(String fileName, ColorScheme cs) {
    final ext = fileName.toLowerCase();
    if (ext.endsWith('.png') || ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.gif') || ext.endsWith('.webp')) return cs.tertiary;
    if (ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.avi')) return cs.error;
    if (ext.endsWith('.mp3') || ext.endsWith('.wav') || ext.endsWith('.ogg')) return cs.secondary;
    if (ext.endsWith('.pdf')) return cs.error;
    if (ext.endsWith('.zip') || ext.endsWith('.rar') || ext.endsWith('.7z')) return cs.primary;
    return cs.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.storageTitle),
        actions: [
          IconButton(
            icon: _isUploading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file),
            tooltip: l10n.storageUploadFile,
            onPressed: _isUploading ? null : _uploadFile,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.storageRefresh,
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
      ),
      body: _buildBody(l10n, colorScheme),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      final msg = _error == 'notLoggedIn' ? l10n.storageNotLoggedIn : _error!;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(msg, style: TextStyle(color: colorScheme.error)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: Text(l10n.storageRetry)),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildStorageBar(l10n, colorScheme),
        const Divider(height: 1),
        Expanded(child: _buildFileList(l10n, colorScheme)),
      ],
    );
  }

  Widget _buildStorageBar(AppLocalizations l10n, ColorScheme colorScheme) {
    int used = 0;
    int quota = -1;
    if (_storageInfo != null) {
      used = (_storageInfo!['used'] as num?)?.toInt() ?? 0;
      quota = (_storageInfo!['quota'] as num?)?.toInt() ?? -1;
    }

    final usedStr = _formatSize(used);
    final quotaStr = quota == -1 ? l10n.storageUnlimited : _formatSize(quota);
    final pct = quota > 0 ? used / quota : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      color: colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_outlined, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '${l10n.storageUsed}: $usedStr / $quotaStr',
                style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
              ),
              const Spacer(),
              Text(
                quota == -1 ? '--' : '${(pct * 100).toStringAsFixed(1)}%',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          if (quota > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  pct > 0.9 ? colorScheme.error : colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileList(AppLocalizations l10n, ColorScheme colorScheme) {
    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 64, color: colorScheme.onSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(l10n.storageNoFiles, style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _uploadFile,
              icon: const Icon(Icons.upload_file),
              label: Text(l10n.storageUploadFile),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        itemCount: _files.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) => _buildFileTile(_files[index], l10n, colorScheme),
      ),
    );
  }

  Widget _buildFileTile(Map<String, dynamic> file, AppLocalizations l10n, ColorScheme colorScheme) {
    final hash = file['hash'] as String? ?? '';
    final fileName = file['file_name'] as String? ?? 'Unknown';
    final uploadTimeRaw = file['upload_time'];
    final size = (file['size'] as num?)?.toInt() ?? 0;
    final refCount = (file['ref_count'] as num?)?.toInt() ?? 0;

    String uploadTime = '';
    if (uploadTimeRaw is num) {
      final dt = DateTime.fromMillisecondsSinceEpoch((uploadTimeRaw.toDouble() * 1000).toInt());
      uploadTime = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _fileIconColor(fileName, colorScheme).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(_fileIcon(fileName), color: _fileIconColor(fileName, colorScheme), size: 24),
      ),
      title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        '${_formatSize(size)}  •  Ref: $refCount  •  $uploadTime',
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 20),
        color: colorScheme.error,
        onPressed: () => _deleteFile(hash, fileName),
        tooltip: l10n.storageDeleteFile,
      ),
    );
  }
}
