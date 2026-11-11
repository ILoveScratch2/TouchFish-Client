import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';

import '../../l10n/app_localizations.dart';
import '../../models/file_attachment.dart';
import '../../models/support_ticket.dart';
import '../../services/api/tf_api_client.dart';
import '../../services/auth_state.dart';
import '../../services/file_service.dart';
import '../../services/image_compression_service.dart';
import '../../services/snackbar_service.dart';
import '../../theme/tokens.dart';
import '../../utils/talker.dart';
import '../sheet_scaffold.dart';
import 'ticket_labels.dart';

/// 工单提交弹层
Future<int?> showTicketComposeSheet(
  BuildContext context, {
  required TicketType type,
  String? targetType,
  String? targetId,
  String? initialTitle,
  String? initialContent,
}) {
  return showAppSheet<int>(
    context: context,
    builder: (_) => _TicketComposeSheet(
      type: type,
      targetType: targetType,
      targetId: targetId,
      initialTitle: initialTitle,
      initialContent: initialContent,
    ),
  );
}

class _TicketComposeSheet extends StatefulWidget {
  final TicketType type;
  final String? targetType;
  final String? targetId;
  final String? initialTitle;
  final String? initialContent;

  const _TicketComposeSheet({
    required this.type,
    this.targetType,
    this.targetId,
    this.initialTitle,
    this.initialContent,
  });

  @override
  State<_TicketComposeSheet> createState() => _TicketComposeSheetState();
}

class _TicketComposeSheetState extends State<_TicketComposeSheet> {
  late final TextEditingController _titleController = TextEditingController(
    text: widget.initialTitle ?? '',
  );
  late final TextEditingController _contentController = TextEditingController(
    text: widget.initialContent ?? '',
  );

  /// 类型可改
  late TicketType _type = widget.type;

  /// 举报默认高优先级
  late TicketPriority _priority =
      widget.type == TicketType.report
      ? TicketPriority.high
      : TicketPriority.normal;
  bool _priorityTouched = false;

  final List<FileAttachment> _attachments = [];
  bool _uploading = false;
  bool _submitting = false;

  static const int _maxAttachments = 9;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _selectType(TicketType type) {
    setState(() {
      _type = type;
      if (!_priorityTouched) {
        _priority = type == TicketType.report
            ? TicketPriority.high
            : TicketPriority.normal;
      }
    });
  }

  Future<void> _pickAttachments() async {
    final l10n = AppLocalizations.of(context)!;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploading = true);
    try {
      for (final file in result.files) {
        if (_attachments.length >= _maxAttachments) break;
        final bytes = file.bytes;
        if (bytes == null) continue;
        final maxSize = await TfApiClient.instance.getMaxFileSize();
        if (maxSize != null && bytes.length > maxSize) {
          if (mounted) {
            TouchFishSnackbarService.instance.show(
              l10n.storageFileTooLarge((maxSize / (1024 * 1024)).round()),
            );
          }
          continue;
        }
        final prepared = await ImageCompressionService.instance
            .prepareForUpload(bytes: bytes, fileName: file.name);
        final uploadBytes = prepared?.bytes ?? bytes;
        final uploadName = prepared?.fileName ?? file.name;
        final hash = await FileService.instance.uploadBytes(
          uid: uid,
          password: password,
          fileName: uploadName,
          bytes: uploadBytes,
        );
        if (hash == null || hash.isEmpty || !mounted) continue;
        setState(() {
          _attachments.add(
            FileAttachment(
              hash: hash,
              fileName: uploadName,
              fileSize: uploadBytes.length,
              mimeType: lookupMimeType(uploadName),
            ),
          );
        });
      }
    } catch (error, stackTrace) {
      talker.error('Ticket compose attachment upload failed', error, stackTrace);
      if (mounted) {
        TouchFishSnackbarService.instance.show(l10n.ticketUploadFailed);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final content = _contentController.text.trim();
    if (content.isEmpty && _attachments.isEmpty) {
      TouchFishSnackbarService.instance.show(l10n.ticketContentRequired);
      return;
    }

    setState(() => _submitting = true);
    final ticketId = await TfApiClient.instance.createTicket(
      uid,
      password,
      type: _type,
      title: _titleController.text.trim(),
      content: content,
      targetType: widget.targetType,
      targetId: widget.targetId,
      priority: _priority,
      attachments: _attachments.map((item) => item.hash).toList(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (ticketId == null) {
      final error = TfApiClient.instance.lastTicketError;
      TouchFishSnackbarService.instance.show(_errorText(l10n, error));
      return;
    }

    TouchFishSnackbarService.instance.show(l10n.ticketSubmitted);
    Navigator.pop(context, ticketId);
  }

  String _errorText(AppLocalizations l10n, String? error) {
    switch (error) {
      case 'ticket_type_disabled':
        return l10n.ticketTypeDisabled;
      case 'empty_content':
        return l10n.ticketContentRequired;
      case 'invalid_attachments':
        return l10n.ticketUploadFailed;
      case 'too_many_attachments':
        return l10n.ticketAttachmentLimit;
      default:
        return l10n.ticketSubmitFailed;
    }
  }

  String _typeLabel(AppLocalizations l10n) {
    switch (_type) {
      case TicketType.report:
        return l10n.ticketReport;
      case TicketType.consult:
        return l10n.ticketConsult;
      case TicketType.appeal:
        return l10n.ticketAppeal;
    }
  }

  /// 相关对象的可读描述
  String _targetLabel(AppLocalizations l10n) {
    final id = widget.targetId ?? '';
    final typeLabel = ticketTargetTypeLabel(l10n, widget.targetType);
    if (typeLabel == null) return '${l10n.ticketTarget}：$id';
    return '${l10n.ticketTarget}：$typeLabel #$id';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SheetScaffold(
      titleText: _typeLabel(l10n),
      onClose: () => Navigator.pop(context),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: TFSpace.xl,
          right: TFSpace.xl,
          bottom: MediaQuery.of(context).viewInsets.bottom + TFSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.targetId != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: TFSpace.md),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(TFRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _targetLabel(l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            _sectionLabel(l10n.ticketTypeName, theme, scheme),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<TicketType>(
                segments: [
                  for (final type in TicketType.values)
                    ButtonSegment<TicketType>(
                      value: type,
                      icon: Icon(ticketTypeIcon(type), size: 16),
                      label: Text(ticketTypeLabel(l10n, type)),
                    ),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: _submitting
                    ? null
                    : (selection) => _selectType(selection.first),
              ),
            ),
            const SizedBox(height: TFSpace.lg),
            TextField(
              controller: _titleController,
              maxLength: 120,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.ticketComposeTitle,
                counterText: '',
                prefixIcon: const Icon(Icons.title, size: 18),
              ),
            ),
            const SizedBox(height: TFSpace.md),
            TextField(
              controller: _contentController,
              minLines: 6,
              maxLines: 12,
              maxLength: 4000,
              decoration: InputDecoration(
                labelText: l10n.ticketComposeContent,
                alignLabelWithHint: true,
                counterText: '${_contentController.text.length}/4000',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: TFSpace.md),
            _sectionLabel(l10n.ticketPriority, theme, scheme),
            const SizedBox(height: 8),
            Wrap(
              spacing: TFSpace.sm,
              runSpacing: TFSpace.sm,
              children: [
                for (final priority in TicketPriority.values)
                  ChoiceChip(
                    label: Text(ticketPriorityLabel(l10n, priority)),
                    selected: _priority == priority,
                    onSelected: _submitting
                        ? null
                        : (_) {
                            setState(() {
                              _priority = priority;
                              _priorityTouched = true;
                            });
                          },
                  ),
              ],
            ),
            const SizedBox(height: TFSpace.lg),
            _sectionLabel(l10n.ticketAttachments, theme, scheme),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _submitting ||
                          _uploading ||
                          _attachments.length >= _maxAttachments
                      ? null
                      : _pickAttachments,
                  icon: _uploading
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file, size: 18),
                  label: Text(l10n.ticketAddFile),
                ),
                const SizedBox(width: TFSpace.sm),
                Text(
                  '${_attachments.length}/$_maxAttachments',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: TFSpace.sm),
              Wrap(
                spacing: TFSpace.sm,
                runSpacing: TFSpace.sm,
                children: [
                  for (var index = 0; index < _attachments.length; index++)
                    InputChip(
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(
                          _attachments[index].fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onDeleted: _submitting || _uploading
                          ? null
                          : () => setState(() => _attachments.removeAt(index)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: TFSpace.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting || _uploading ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.ticketComposeSubmit),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, ThemeData theme, ColorScheme scheme) {
    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
