import 'package:flutter/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../models/api_error.dart';

/// 翻译一下
String localizeApiError(BuildContext context, ApiError error) {
  final l10n = AppLocalizations.of(context);
  if (l10n == null) return error.message;
  final localized = switch (error.code) {
    'AUTH_TOKEN_EXPIRED' => l10n.errorCodeAuthTokenExpired,
    'AUTH_FAILED' => l10n.errorCodeAuthFailed,
    'AUTH_TOKEN_LIMIT_REACHED' => l10n.errorCodeAuthTokenLimitReached,
    'AUTH_NOT_AUTHENTICATED' => l10n.errorCodeAuthNotAuthenticated,
    'PERMISSION_DENIED' => l10n.errorCodePermissionDenied,
    'VALIDATION_INVALID_REQUEST' => l10n.errorCodeValidationInvalidRequest,
    'RESOURCE_NOT_FOUND' => l10n.errorCodeResourceNotFound,
    'RESOURCE_USER_NOT_FOUND' => l10n.errorCodeResourceUserNotFound,
    'RESOURCE_UNAVAILABLE' => l10n.errorCodeResourceUnavailable,
    'AUTH_CANNOT_REVOKE_CURRENT' => l10n.errorCodeAuthCannotRevokeCurrent,
    'PERMISSION_NOT_FRIENDS' => l10n.errorCodePermissionNotFriends,
    'PERMISSION_NOT_GROUP_MEMBER' => l10n.errorCodePermissionNotGroupMember,
    'RESOURCE_GROUP_NOT_FOUND' => l10n.errorCodeResourceGroupNotFound,
    'RESOURCE_USER_BANNED' => l10n.errorCodeResourceUserBanned,
    'VALIDATION_INVALID_UID' => l10n.errorCodeValidationInvalidUid,
    'VALIDATION_INVALID_FILENAME' => l10n.errorCodeValidationInvalidFilename,
    'VALIDATION_EXTENSION_NOT_ALLOWED' =>
      l10n.errorCodeValidationExtensionNotAllowed,
    'VALIDATION_INVALID_FILE_HASH' => l10n.errorCodeValidationInvalidFileHash,
    'VALIDATION_INVALID_CHUNK_PARAMETERS' =>
      l10n.errorCodeValidationInvalidChunkParameters,
    'VALIDATION_INVALID_BASE64' => l10n.errorCodeValidationInvalidBase64,
    'VALIDATION_INVALID_TARGET' => l10n.errorCodeValidationInvalidTarget,
    'VALIDATION_INVALID_QUOTE' => l10n.errorCodeValidationInvalidQuote,
    'VALIDATION_INVALID_CALL_ID' => l10n.errorCodeValidationInvalidCallId,
    'VALIDATION_MESSAGE_TOO_LONG' => l10n.errorCodeValidationMessageTooLong,
    'VALIDATION_MISSING_PARAMETER' => l10n.errorCodeValidationMissingParameter,
    'FILE_NOT_OWNED' => l10n.errorCodeFileNotOwned,
    'FILE_UNAVAILABLE' => l10n.errorCodeFileUnavailable,
    'FILE_TOO_LARGE' => l10n.errorCodeFileTooLarge,
    'FILE_CHUNK_TOO_LARGE' => l10n.errorCodeFileChunkTooLarge,
    'FILE_STORAGE_QUOTA_EXCEEDED' => l10n.errorCodeFileStorageQuotaExceeded,
    'FILE_TOO_MANY_UPLOADS' => l10n.errorCodeFileTooManyUploads,
    'FILE_DECODE_FAILED' => l10n.errorCodeFileDecodeFailed,
    'FILE_MISSING_FILE_ID' => l10n.errorCodeFileMissingFileId,
    'FILE_INVALID_FILE_ID' => l10n.errorCodeFileInvalidFileId,
    'FILE_CHUNK_TOTAL_MISMATCH' => l10n.errorCodeFileChunkTotalMismatch,
    'FILE_MISSING_CHUNK' => l10n.errorCodeFileMissingChunk,
    'FILE_WRITE_FAILED' => l10n.errorCodeFileWriteFailed,
    'FILE_DIRECTORY_CREATION_FAILED' =>
      l10n.errorCodeFileDirectoryCreationFailed,
    'FILE_CHUNK_INFO_FAILED' => l10n.errorCodeFileChunkInfoFailed,
    'FILE_CHUNK_READ_FAILED' => l10n.errorCodeFileChunkReadFailed,
    'FILE_HASH_VERIFICATION_FAILED' => l10n.errorCodeFileHashVerificationFailed,
    'FILE_FINALIZATION_FAILED' => l10n.errorCodeFileFinalizationFailed,
    'FILE_REFERENCE_FAILED' => l10n.errorCodeFileReferenceFailed,
    'FILE_UPLOAD_FAILED' => l10n.errorCodeFileUploadFailed,
    'STICKER_UNSUPPORTED_TYPE' => l10n.errorCodeStickerUnsupportedType,
    'STICKER_TOO_LARGE' => l10n.errorCodeStickerTooLarge,
    'STICKER_QUOTA_EXCEEDED' => l10n.errorCodeStickerQuotaExceeded,
    'MESSAGE_CLIENT_MID_CONFLICT' => l10n.errorCodeMessageClientMidConflict,
    'MESSAGE_ALREADY_RECALLED' => l10n.errorCodeMessageAlreadyRecalled,
    'RATE_LIMITED' => l10n.errorCodeRateLimited,
    'CONFLICT' => l10n.errorCodeConflict,
    'SERVER_ERROR' => l10n.errorCodeServerError,
    _ => null,
  };
  return localized ?? error.message;
}
