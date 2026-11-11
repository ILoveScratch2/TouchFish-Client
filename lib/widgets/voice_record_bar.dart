import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as rec;
import 'package:waveform_flutter/waveform_flutter.dart';

import '../utils/talker.dart';
import 'voice_record_status.dart';

/// 录音条
/// 按住录音、松手发送、上滑取消的
/// Web 平台暂不支持录音。
class VoiceRecordBar extends StatefulWidget {
  final Future<void> Function(String path, int durationMs) onRecorded;
  final bool enabled;

  const VoiceRecordBar({
    super.key,
    required this.onRecorded,
    this.enabled = true,
  });

  @override
  State<VoiceRecordBar> createState() => _VoiceRecordBarState();
}

class _VoiceRecordBarState extends State<VoiceRecordBar> {
  static const _maxDuration = Duration(minutes: 5);
  static const _cancelDragDistance = 56.0;

  final rec.AudioRecorder _recorder = rec.AudioRecorder();
  final Stopwatch _stopwatch = Stopwatch();
  final StreamController<Amplitude> _amplitudeController =
      StreamController<Amplitude>.broadcast();
  StreamSubscription<rec.Amplitude>? _amplitudeSub;
  Timer? _ticker;
  String? _recordingPath;
  bool _isRecording = false;
  bool _isSending = false;
  bool _cancelArmed = false;
  Duration _duration = Duration.zero;

  bool get _supported => !kIsWeb;

  @override
  void dispose() {
    _ticker?.cancel();
    _amplitudeSub?.cancel();
    _amplitudeController.close();
    _recorder.dispose();
    super.dispose();
  }

  /// 桌面端优先用 WAV（Windows Media Foundation 不保证 AAC 编码器可用），
  /// 移动端沿用 AAC-LC。
  Future<({rec.AudioEncoder encoder, String extension})> _pickEncoder() async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return (encoder: rec.AudioEncoder.aacLc, extension: 'm4a');
    }
    return (encoder: rec.AudioEncoder.wav, extension: 'wav');
  }

  Future<void> _startRecording() async {
    if (!widget.enabled || _isRecording || _isSending) return;
    if (!await _recorder.hasPermission()) {
      talker.warning('VoiceRecorder: microphone permission denied');
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final picked = await _pickEncoder();
      final path = p.join(
        dir.path,
        'voice_${DateTime.now().millisecondsSinceEpoch}.${picked.extension}',
      );
      final isMobile =
          Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
      final config = rec.RecordConfig(
        encoder: picked.encoder,
        numChannels: 1,
        autoGain: isMobile,
        echoCancel: isMobile,
        noiseSuppress: isMobile,
      );
      await _recorder.start(config, path: path);
      _recordingPath = path;
      _stopwatch
        ..reset()
        ..start();
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(milliseconds: 150), (_) {
        if (!mounted) return;
        final elapsed = _stopwatch.elapsed;
        if (elapsed >= _maxDuration) {
          setState(() => _duration = _maxDuration);
          unawaited(_finishRecording(cancel: false));
          return;
        }
        setState(() => _duration = elapsed);
      });
      _amplitudeSub?.cancel();
      _amplitudeSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 90))
          .listen((value) {
            _amplitudeController.add(
              Amplitude(current: value.current, max: value.max),
            );
          });
      setState(() {
        _isRecording = true;
        _cancelArmed = false;
        _duration = Duration.zero;
      });
    } catch (e) {
      talker.error('VoiceRecorder start failed', e);
    }
  }

  Future<void> _finishRecording({required bool cancel}) async {
    if (!_isRecording) return;
    _ticker?.cancel();
    _stopwatch.stop();
    _amplitudeSub?.cancel();
    final durationMs = _stopwatch.elapsedMilliseconds;
    var finalPath = _recordingPath;
    try {
      final result = await _recorder.stop();
      if (result != null) finalPath = result;
    } catch (e) {
      talker.error('VoiceRecorder stop failed', e);
    }
    final shouldDiscard = cancel || finalPath == null || durationMs < 400;
    setState(() {
      _isRecording = false;
      _cancelArmed = false;
    });
    _recordingPath = null;

    if (shouldDiscard) {
      if (finalPath != null) {
        try {
          final file = File(finalPath);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      setState(() => _duration = Duration.zero);
      return;
    }

    final recordedPath = finalPath;
    setState(() => _isSending = true);
    try {
      await widget.onRecorded(recordedPath, durationMs);
    } catch (e) {
      talker.error('VoiceRecorder send failed', e);
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _duration = Duration.zero;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (_) => unawaited(_startRecording()),
      onLongPressMoveUpdate: (details) {
        if (!_isRecording) return;
        final armed = details.offsetFromOrigin.dy < -_cancelDragDistance;
        if (armed != _cancelArmed && mounted) {
          setState(() => _cancelArmed = armed);
        }
      },
      onLongPressEnd: (_) => unawaited(_finishRecording(cancel: _cancelArmed)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: _isRecording || _isSending ? 82 : 70,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          color: _isRecording
              ? (_cancelArmed ? colorScheme.error : colorScheme.primary)
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: VoiceRecordStatus(
            isRecording: _isRecording,
            isCancelArmed: _cancelArmed,
            isUploading: _isSending,
            duration: _duration,
            maxDuration: _maxDuration,
            amplitudeStream: _amplitudeController.stream,
          ),
        ),
      ),
    );
  }
}
