import '../l10n/app_localizations.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

/// 非文字消息

/// 服务端文件 hash
final RegExp _fileHashPattern = RegExp(r'^[0-9a-f]{64}$');

/// 内部占位符
const Map<String, MessageType> _legacyPlaceholders = {
  '[FILE]': MessageType.file,
  '[IMAGE]': MessageType.image,
  '[VIDEO]': MessageType.video,
  '[AUDIO]': MessageType.audio,
};

MessageType? legacyPlaceholderType(String raw) =>
    _legacyPlaceholders[raw.trim().toUpperCase()];

String mediaTypeLabel(MessageType type, AppLocalizations l10n) {
  return switch (type) {
    MessageType.image => l10n.mediaImageMessage,
    MessageType.video => l10n.mediaVideoMessage,
    MessageType.audio => l10n.mediaAudioMessage,
    MessageType.file => l10n.mediaFileMessage,
    _ => '',
  };
}

bool _isUsableFileName(String? name, String? hash) {
  final value = name?.trim();
  if (value == null || value.isEmpty) return false;
  if (hash != null && value == hash) return false;
  if (_fileHashPattern.hasMatch(value)) return false;
  return true;
}

String mediaPreviewText(
  MessageType type,
  String? fileName,
  AppLocalizations l10n, {
  String? fileHash,
}) {
  final label = mediaTypeLabel(type, l10n);
  final name = _isUsableFileName(fileName, fileHash) ? fileName!.trim() : null;
  if (name == null) return label;
  // 标签本身已带方括号（`[文件]`），直接拼接文件名即可。
  return '$label$name';
}

/// 一条消息面向用户的完整文本
String messagePlainText(ChatMessage message, AppLocalizations l10n) {
  if (message.isDeleted) return '';
  final media = message.media;
  return _plainText(
    l10n: l10n,
    type: message.type,
    raw: message.text,
    fileName: media?.fileName,
    fileHash: media?.fileHash,
    hasMedia: media != null,
    mergedForwardRoomName: message.mergedForward?.sourceRoomName,
  );
}

/// 会话列表最后一条消息的预览文本
String roomPreviewText(ChatRoom room, AppLocalizations l10n) {
  return _plainText(
    l10n: l10n,
    type: room.lastMessageType,
    raw: room.lastMessage ?? '',
    fileName: room.lastMessageFileName,
  );
}

String _plainText({
  required AppLocalizations l10n,
  required MessageType? type,
  required String raw,
  String? fileName,
  String? fileHash,
  bool hasMedia = false,
  String? mergedForwardRoomName,
}) {
  final trimmed = raw.trim();

  if (type != null && type != MessageType.text) {
    if (type == MessageType.mergedForward) {
      final name = mergedForwardRoomName?.trim();
      return name == null || name.isEmpty
          ? l10n.mergedForwardGroup
          : l10n.mergedForwardTitle(name);
    }
    return mediaPreviewText(type, fileName, l10n, fileHash: fileHash);
  }

  // 部分历史消息 type 仍是 text
  if (hasMedia && trimmed.isEmpty) {
    return mediaPreviewText(
      MessageType.file,
      fileName,
      l10n,
      fileHash: fileHash,
    );
  }

  final legacy = _legacyPlaceholders[trimmed.toUpperCase()];
  if (legacy != null) {
    return mediaPreviewText(legacy, fileName, l10n, fileHash: fileHash);
  }

  if (!hasMedia && _fileHashPattern.hasMatch(trimmed)) {
    return l10n.mediaFileMessage;
  }

  return raw;
}
