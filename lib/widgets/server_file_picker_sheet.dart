import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localizations.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../utils/talker.dart';
import 'file_attachment_view.dart';
import 'sheet_scaffold.dart';

/// 选择用户在服务端已上传的文件（免上传直发）。
Future<Map<String, dynamic>?> showServerFilePicker(BuildContext context) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _ServerFilePickerSheet(),
  );
}

class _ServerFilePickerSheet extends StatefulWidget {
  const _ServerFilePickerSheet();

  @override
  State<_ServerFilePickerSheet> createState() => _ServerFilePickerSheetState();
}

class _ServerFilePickerSheetState extends State<_ServerFilePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _filesFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _filesFuture = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) {
      return Future.value(const []);
    }
    return TfApiClient.instance.getUserFiles(uid, password);
  }

  void _retry() {
    setState(() => _filesFuture = _load());
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> files) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return files;
    return files
        .where(
          (f) =>
              (f['file_name'] as String? ?? '').toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return SheetScaffold(
      titleText: l10n.chatInputPickServerFile,
      heightFactor: 0.85,
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: l10n.serverFilePickerSearch,
                prefixIcon: const Icon(Symbols.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _filesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  talker.error('getUserFiles failed', snapshot.error);
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off,
                          size: 40,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.serverFilePickerError,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: _retry,
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  );
                }
                final files = _filter(snapshot.data ?? const []);
                if (files.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isEmpty
                          ? l10n.serverFilePickerEmpty
                          : l10n.serverFilePickerNoMatch,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: files.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) {
                    final file = files[index];
                    return _buildFileTile(context, file);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileTile(BuildContext context, Map<String, dynamic> file) {
    final colorScheme = Theme.of(context).colorScheme;
    final fileName = file['file_name'] as String? ?? 'Unknown';
    final size = (file['size'] as num?)?.toInt() ?? 0;
    final uploadTimeRaw = file['upload_time'];

    String uploadTime = '';
    if (uploadTimeRaw is num) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        (uploadTimeRaw.toDouble() * 1000).toInt(),
      );
      uploadTime =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return ListTile(
      leading: Container(
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
      ),
      title: Text(
        fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        '${formatFileSize(size)}  •  $uploadTime',
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
      ),
      onTap: () => Navigator.of(context).pop(file),
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
