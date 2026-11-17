import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/auth_state.dart';
import '../services/api/tf_api_client.dart';
import '../services/file_service.dart';
import '../services/snackbar_service.dart';
import '../utils/format.dart';
import '../utils/talker.dart';
import '../widgets/app_alert_dialog.dart';
import '../l10n/app_localizations.dart';
import '../models/file_attachment.dart';
import '../widgets/file_attachment_view.dart';
import '../widgets/file_thumbnail.dart';
import '../widgets/sheet_scaffold.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/error_state.dart';
import '../widgets/ui/loading_indicator.dart';
import '../theme/tokens.dart';

/// 存储页的失败类型
enum StorageError { notLoggedIn, loadFailed }

class StorageManagementScreen extends StatefulWidget {
  const StorageManagementScreen({super.key});

  @override
  State<StorageManagementScreen> createState() =>
      _StorageManagementScreenState();
}

class _StorageManagementScreenState extends State<StorageManagementScreen> {
  List<Map<String, dynamic>> _files = [];
  Map<String, dynamic>? _storageInfo;
  bool _isLoading = true;

  /// 上传进度 0..1
  double? _uploadProgress;
  bool get _isUploading => _uploadProgress != null;
  StorageError? _error;

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
        _error = StorageError.notLoggedIn;
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
      talker.error('StorageManagement load failed', e);
      setState(() {
        _isLoading = false;
        // 只记录失败类型，原始异常进日志，不直接展示给用户。
        _error = StorageError.loadFailed;
      });
    }
  }

  String _formatSize(int bytes) => formatBytes(bytes);

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
      TouchFishSnackbarService.instance.show(
        l10n.storageCouldNotReadFile,
      );
      return;
    }

    final maxSize = await TfApiClient.instance.getMaxFileSize();
    if (maxSize != null && bytes.length > maxSize) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      TouchFishSnackbarService.instance.show(
        l10n.storageFileTooLarge((maxSize / (1024 * 1024)).round()),
      );
      return;
    }

    setState(() => _uploadProgress = 0);

    try {
      // 超过阈值的文件内部会走分块上传，避免把整个文件塞进一个加密请求。
      final hash = await FileService.instance.uploadBytes(
        uid: uid,
        password: password,
        fileName: file.name,
        bytes: bytes,
        onProgress: (transferred) {
          if (!mounted || _uploadProgress == null) return;
          final total = bytes.length;
          if (total <= 0) return;
          final value = (transferred / total).clamp(0.0, 1.0);
          // 变化不足时不重建。
          final current = _uploadProgress!;
          if (value < 1 && (value - current).abs() < 0.01) return;
          setState(() => _uploadProgress = value);
        },
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      if (hash != null) {
        TouchFishSnackbarService.instance.show(
          l10n.storageUploaded(file.name),
        );
        await _loadData();
      } else {
        TouchFishSnackbarService.instance.show(
          l10n.storageUploadFailed,
        );
      }
    } catch (e, stack) {
      talker.error('Storage upload failed', e, stack);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      TouchFishSnackbarService.instance.show(l10n.storageUploadError);
    } finally {
      if (mounted) setState(() => _uploadProgress = null);
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
        TouchFishDialogAction<bool>(
          label: l10n.storageDeleteFile,
          result: true,
          isPrimary: true,
          isDestructive: true,
        ),
      ],
    );
    if (confirmed != true || !mounted) return;

    final ok = await TfApiClient.instance.deleteFile(uid, password, hash);
    if (!mounted) return;
    if (ok) {
      TouchFishSnackbarService.instance.show(
        l10n.storageDeleted(fileName),
      );
      await _loadData();
    } else {
      TouchFishSnackbarService.instance.show(
        l10n.storageDeleteFailed,
      );
    }
  }

  Future<void> _dereferenceFile(String hash, String fileName) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showTouchFishErrorDialog<bool>(
      context,
      title: l10n.storageDereference,
      message: l10n.storageDereferenceConfirm(fileName),
      icon: Icons.link_off,
      selectableMessage: false,
      actions: [
        TouchFishDialogAction<bool>(label: l10n.cancel, result: false),
        TouchFishDialogAction<bool>(
          label: l10n.storageDereference,
          result: true,
          isPrimary: true,
        ),
      ],
    );
    if (confirmed != true || !mounted) return;

    final ok = await TfApiClient.instance.dereferenceFile(uid, password, hash);
    if (!mounted) return;
    if (ok) {
      TouchFishSnackbarService.instance.show(
        l10n.storageDereferenced(fileName),
      );
      await _loadData();
    } else {
      TouchFishSnackbarService.instance.show(
        l10n.storageDereferenceFailed,
      );
    }
  }

  IconData _fileIcon(String fileName) {
    final ext = fileName.toLowerCase();
    if (ext.endsWith('.png') ||
        ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.webp') ||
        ext.endsWith('.bmp')) {
      return Icons.image;
    }
    if (ext.endsWith('.mp4') ||
        ext.endsWith('.mov') ||
        ext.endsWith('.avi') ||
        ext.endsWith('.mkv')) {
      return Icons.videocam;
    }
    if (ext.endsWith('.mp3') ||
        ext.endsWith('.wav') ||
        ext.endsWith('.ogg') ||
        ext.endsWith('.flac')) {
      return Icons.audiotrack;
    }
    if (ext.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (ext.endsWith('.zip') ||
        ext.endsWith('.rar') ||
        ext.endsWith('.7z') ||
        ext.endsWith('.tar') ||
        ext.endsWith('.gz')) {
      return Icons.folder_zip;
    }
    if (ext.endsWith('.doc') || ext.endsWith('.docx')) return Icons.description;
    if (ext.endsWith('.xls') || ext.endsWith('.xlsx')) return Icons.table_chart;
    if (ext.endsWith('.ppt') || ext.endsWith('.pptx')) return Icons.slideshow;
    return Icons.insert_drive_file;
  }

  Color _fileIconColor(String fileName, ColorScheme cs) {
    final ext = fileName.toLowerCase();
    if (ext.endsWith('.png') ||
        ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.webp')) {
      return cs.tertiary;
    }
    if (ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.avi')) {
      return cs.error;
    }
    if (ext.endsWith('.mp3') || ext.endsWith('.wav') || ext.endsWith('.ogg')) {
      return cs.secondary;
    }
    if (ext.endsWith('.pdf')) return cs.error;
    if (ext.endsWith('.zip') || ext.endsWith('.rar') || ext.endsWith('.7z')) {
      return cs.primary;
    }
    return cs.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _uploadProgress == null
              ? l10n.storageTitle
              : '${l10n.storageTitle} · ${(_uploadProgress! * 100).round()}%',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: l10n.storageUploadFile,
            onPressed: _isUploading ? null : _uploadFile,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.storageRefresh,
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
        // 上传进度条
        bottom: _uploadProgress == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _uploadProgress,
                  minHeight: 3,
                ),
              ),
      ),
      body: _buildBody(l10n, colorScheme),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ColorScheme colorScheme) {
    if (_isLoading) {
      return const LoadingIndicator();
    }

    if (_error != null) {
      return ErrorState(
        title: _error == StorageError.notLoggedIn
            ? l10n.storageNotLoggedIn
            : l10n.commonLoadFailed,
        onRetry: _loadData,
        retryLabel: l10n.storageRetry,
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
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                quota == -1 ? '--' : '${(pct * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
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
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            EmptyState(
              icon: Icons.cloud_off,
              title: l10n.storageNoFiles,
              action: FilledButton.tonalIcon(
                onPressed: _uploadFile,
                icon: const Icon(Icons.upload_file),
                label: Text(l10n.storageUploadFile),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        itemCount: _files.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) =>
            _buildFileTile(_files[index], l10n, colorScheme),
      ),
    );
  }

  Widget _buildFileTile(
    Map<String, dynamic> file,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final hash = file['hash'] as String? ?? '';
    final fileName = file['file_name'] as String? ?? 'Unknown';
    final uploadTimeRaw = file['upload_time'];
    final size = (file['size'] as num?)?.toInt() ?? 0;
    final refCount = (file['ref_count'] as num?)?.toInt() ?? 0;

    final uploadTime = formatTimestamp(uploadTimeRaw as num?);

    final leadingFallback = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _fileIconColor(fileName, colorScheme).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        _fileIcon(fileName),
        color: _fileIconColor(fileName, colorScheme),
        size: 24,
      ),
    );
    final attachment = FileAttachment.fromMap(file);
    final leading = attachment.isImage && attachment.hasThumb && hash.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: FileThumbnail(hash: hash, fallback: leadingFallback),
          )
        : leadingFallback;

    return ListTile(
      leading: leading,
      title: Text(
        fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        '${_formatSize(size)}  •  Ref: $refCount  •  $uploadTime',
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
      ),
      onTap: () => _showFileActions(file),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined, size: 20),
            onPressed: () => _showFileActions(file),
            tooltip: l10n.filePreview,
          ),
          PopupMenuButton<String>(
            tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
            onSelected: (value) {
              if (value == 'dereference') {
                _dereferenceFile(hash, fileName);
              } else if (value == 'delete') {
                _deleteFile(hash, fileName);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'dereference',
                child: Row(
                  children: [
                    const Icon(Icons.link_off, size: 20),
                    const SizedBox(width: TFSpace.md),
                    Text(l10n.storageDereference, maxLines: 1),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: TFSpace.md),
                    Text(
                      l10n.storageDeleteFile,
                      maxLines: 1,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ],
                ),
              ),
            ],
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

