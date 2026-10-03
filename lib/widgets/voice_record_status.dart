import 'package:flutter/material.dart';
import 'package:waveform_flutter/waveform_flutter.dart';

import '../l10n/app_localizations.dart';

/// mm:ss 短时长格式（用于录音计时 / 上限显示）。
String formatVoiceDurationShort(Duration duration) {
  final totalSeconds = duration.inSeconds.clamp(0, 5999);
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

/// 录音状态条
///
/// 显示提示文案、当前时长、最大时长进度以及录音时的实时振幅波形。
class VoiceRecordStatus extends StatelessWidget {
  final bool isRecording;
  final bool isCancelArmed;
  final bool isUploading;
  final Duration duration;
  final Duration maxDuration;
  final Stream<Amplitude> amplitudeStream;

  const VoiceRecordStatus({
    super.key,
    required this.isRecording,
    required this.isCancelArmed,
    required this.isUploading,
    required this.duration,
    required this.maxDuration,
    required this.amplitudeStream,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final progress = maxDuration.inMilliseconds <= 0
        ? 0.0
        : (duration.inMilliseconds / maxDuration.inMilliseconds).clamp(
            0.0,
            1.0,
          );
    final foregroundColor = isRecording
        ? (isCancelArmed ? colorScheme.onError : colorScheme.onPrimary)
        : isUploading
        ? colorScheme.primary
        : colorScheme.onSurface;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isRecording
                    ? (isCancelArmed
                          ? l10n.voiceReleaseToCancel
                          : l10n.voiceRecordingHint)
                    : isUploading
                    ? l10n.voiceUploading
                    : l10n.voiceHoldToRecord,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              formatVoiceDurationShort(duration),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: isRecording
                ? foregroundColor.withValues(alpha: 0.18)
                : colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(
              isCancelArmed ? colorScheme.onError : foregroundColor,
            ),
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 16,
          child: isRecording
              ? AnimatedWaveList(
                  stream: amplitudeStream,
                  barBuilder: (animation, amplitude) {
                    final activeColor = isCancelArmed
                        ? colorScheme.onError
                        : colorScheme.onPrimary;
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final normalized = (amplitude.current.abs() / 60).clamp(
                          0.16,
                          1.0,
                        );
                        final height = 4 + (normalized * 10 * animation.value);
                        return Container(
                          width: 2.2,
                          height: height.clamp(4.0, 14.0),
                          margin: const EdgeInsets.symmetric(horizontal: 0.75),
                          decoration: BoxDecoration(
                            color: activeColor.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      },
                    );
                  },
                )
              : isUploading
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.voiceSending,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${formatVoiceDurationShort(duration)} / '
                    '${formatVoiceDurationShort(maxDuration)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
