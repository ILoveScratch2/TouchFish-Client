import '../l10n/app_localizations.dart';

/// 失败原因
abstract final class SendFailureReason {
  const SendFailureReason._();

  static const timeout = 'send.timeout';
  static const network = 'send.network';
  static const rejected = 'send.rejected';
  static const upload = 'send.upload';
}

String localizeFailureReason(AppLocalizations l10n, String? reason) {
  if (reason == null || reason.isEmpty) return l10n.messageRetrySend;

  switch (reason) {
    case SendFailureReason.timeout:
      return l10n.messageSendTimeout;
    case SendFailureReason.network:
      return l10n.messageSendNetworkFailed;
    case SendFailureReason.rejected:
      return l10n.messageSendRejected;
    case SendFailureReason.upload:
      return l10n.messageSendUploadFailed;
    default:
      return reason;
  }
}
