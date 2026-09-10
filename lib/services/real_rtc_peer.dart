import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:flutter/widgets.dart';

import 'rtc_peer.dart';
import '../utils/talker.dart';

/// 依据枚举出的设备与用户是否要视频，决定 getUserMedia 该请求哪些媒体。
///
/// Windows 原生 GetUserAudio 在 `audio:true` 且无任何录音设备时越界崩溃，
/// 因此必须仅在确有对应输入设备时才请求，绝不能盲传 `audio:true`。
@visibleForTesting
({bool audio, bool video}) resolveMediaAvailability(
  Iterable<String> deviceKinds, {
  required bool videoRequested,
}) {
  final hasMic = deviceKinds.contains('audioinput');
  final hasCamera = deviceKinds.contains('videoinput');
  return (audio: hasMic, video: videoRequested && hasCamera);
}

/// 构建 camera
@visibleForTesting
dynamic buildVideoConstraints(String? deviceId, {required bool isWeb}) {
  if (deviceId == null || deviceId.isEmpty) return true;
  if (isWeb) {
    return {
      'deviceId': {'exact': deviceId},
    };
  }
  return {
    'optional': [
      {'sourceId': deviceId},
    ],
  };
}

/// 基于 flutter_webrtc 的真实通话会话。
class RealRtcPeer implements RtcPeer {
  final rtc.RTCPeerConnection _pc;
  final rtc.MediaStream _localStream;
  rtc.MediaStream? _remoteStream;
  final rtc.RTCVideoRenderer _localRenderer = rtc.RTCVideoRenderer();
  final rtc.RTCVideoRenderer _remoteRenderer = rtc.RTCVideoRenderer();
  final bool _hasVideo;
  final dynamic _navigator;
  bool _disposed = false;
  rtc.RTCRtpSender? _videoSender;
  Future<void>? _videoSenderReady;
  rtc.MediaStreamTrack? _videoTrack;
  final List<rtc.MediaStream> _replacementStreams = [];

  final _candidateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _stateController = StreamController<String>.broadcast();
  final _remoteTrackController = StreamController<void>.broadcast();

  RealRtcPeer._(this._pc, this._localStream, this._hasVideo, this._navigator) {
    _pc.onIceCandidate = (candidate) {
      final value = candidate.candidate;
      if (value == null || value.isEmpty) return;
      _candidateController.add(candidate.toMap());
    };
    _pc.onIceConnectionState = (state) {
      final normalized = state.toString().split('.').last.toLowerCase();
      final value = normalized.endsWith('completed')
          ? 'completed'
          : normalized.endsWith('connected')
          ? 'connected'
          : normalized.endsWith('failed')
          ? 'failed'
          : normalized.endsWith('disconnected')
          ? 'disconnected'
          : normalized;
      _stateController.add(value);
    };
    _pc.onTrack = (event) async {
      if (_disposed) return;
      final stream = event.streams.isNotEmpty
          ? event.streams.first
          : (_remoteStream ??= await rtc.createLocalMediaStream('remote'));
      if (event.streams.isEmpty) {
        await stream.addTrack(event.track);
      }
      _remoteStream = stream;
      _remoteRenderer.srcObject = stream;
      if (!_remoteTrackController.isClosed) {
        _remoteTrackController.add(null);
      }
    };
    final audioTracks = _localStream.getAudioTracks();
    final videoTracks = _localStream.getVideoTracks();
    final track = videoTracks.isEmpty ? null : videoTracks.first;
    _videoSenderReady = () async {
      await Future.wait(
        audioTracks.map((audioTrack) => _pc.addTrack(audioTrack, _localStream)),
      );
      if (track != null && _hasVideo) {
        _videoTrack = track;
        _videoSender = await _pc.addTrack(track, _localStream);
      }
    }();
  }

  /// 创建会话：获取本地音视频并建立 RTCPeerConnection。
  static Future<RealRtcPeer> create({
    required bool videoEnabled,
    List<Map<String, dynamic>>? iceServers,
    rtc.RTCFactory? factory,
  }) async {
    final servers =
        iceServers ??
        const [
          {
            'urls': ['stun:stun.epygi.com', 'stun:stun.fitauto.ru'],
          },
        ];
    final navigator = factory?.navigator ?? rtc.navigator;

    // 探测真实可用的输入设备。Windows 原生 GetUserAudio 在 `audio:true` 且
    // RecordingDevices() 为 0 时会越界读索引 0，直接段错误崩掉整个 App，
    // 触达不到 Dart 的 catch。这里先用无副作用的 enumerateDevices 安全探测，
    // 只在确实存在输入设备时才请求对应媒体，从根上避免原生崩溃。
    var audioAvailable = true;
    var videoAvailable = false;
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      final availability = resolveMediaAvailability(
        devices.map((d) => d.kind ?? ''),
        videoRequested: videoEnabled,
      );
      audioAvailable = availability.audio;
    } catch (_) {
      // 枚举失败属异常情况：退回全请求，与旧行为一致。
    }

    rtc.MediaStream stream;
    if (videoEnabled) {
      try {
        stream = await navigator.mediaDevices.getUserMedia({
          'audio': audioAvailable,
          'video': buildVideoConstraints(null, isWeb: kIsWeb),
        });
      } catch (error, stackTrace) {
        talker.warning('Video capture failed; falling back to audio', error);
        talker.error('Video capture details', error, stackTrace);
        try {
          stream = await navigator.mediaDevices.getUserMedia({
            'audio': audioAvailable,
            'video': buildVideoConstraints(null, isWeb: kIsWeb),
          });
        } catch (retryError, retryStackTrace) {
          talker.error(
            'Generic video capture retry failed; using audio only',
            retryError,
            retryStackTrace,
          );
          stream = await navigator.mediaDevices.getUserMedia({
            'audio': audioAvailable,
            'video': false,
          });
        }
      }
    } else {
      stream = await navigator.mediaDevices.getUserMedia({
        'audio': audioAvailable,
        'video': false,
      });
    }
    videoAvailable = videoEnabled && stream.getVideoTracks().isNotEmpty;
    if (videoEnabled && !videoAvailable) {
      talker.warning(
        'Video capture returned no video tracks; continuing with audio only',
      );
    }
    final pc = await (factory == null
        ? rtc.createPeerConnection({'iceServers': servers})
        : factory.createPeerConnection({'iceServers': servers}));
    final peer = RealRtcPeer._(pc, stream, videoAvailable, navigator);
    await peer._localRenderer.initialize();
    peer._localRenderer.srcObject = stream;
    await peer._remoteRenderer.initialize();
    await peer._videoSenderReady;
    return peer;
  }

  @override
  Widget? get localVideo => RtcVideoPreview(_localRenderer);

  @override
  Widget? get remoteVideo {
    return _remoteStream == null ? null : RtcVideoPreview(_remoteRenderer);
  }

  @override
  Stream<Map<String, dynamic>> get onIceCandidate =>
      _candidateController.stream;

  @override
  Stream<String> get onIceConnectionState => _stateController.stream;

  @override
  Stream<void> get onRemoteTrack => _remoteTrackController.stream;

  @override
  Future<Map<String, dynamic>> createOffer() async {
    await _videoSenderReady;
    final desc = await _pc.createOffer();
    await _pc.setLocalDescription(desc);
    await _logTransceiverDirections('offer');
    return {'sdp': desc.sdp, 'sdp_type': desc.type};
  }

  @override
  Future<Map<String, dynamic>> createAnswer() async {
    await _videoSenderReady;
    final desc = await _pc.createAnswer();
    await _pc.setLocalDescription(desc);
    await _logTransceiverDirections('answer');
    return {'sdp': desc.sdp, 'sdp_type': desc.type};
  }

  Future<void> _logTransceiverDirections(String phase) async {
    try {
      final transceivers = await _pc.getTransceivers();
      final parts = <String>[];
      for (final t in transceivers) {
        final direction = await t.getDirection();
        parts.add(
          '${t.mid.isEmpty ? '-' : t.mid}:${t.sender.track?.kind ?? '?'}=${direction.name}',
        );
      }
      talker.debug('transceivers after $phase: ${parts.join(', ')}');
    } catch (_) {
    }
  }

  @override
  Future<void> setRemoteDescription(Map<String, dynamic> sdp) async {
    await _pc.setRemoteDescription(
      rtc.RTCSessionDescription(
        sdp['sdp'] as String?,
        sdp['sdp_type'] as String?,
      ),
    );
  }

  @override
  Future<void> addCandidate(Map<String, dynamic> candidate) async {
    await _pc.addCandidate(
      rtc.RTCIceCandidate(
        candidate['candidate'] as String?,
        candidate['sdpMid'] as String?,
        candidate['sdpMLineIndex'] as int?,
      ),
    );
  }

  @override
  Future<void> setMicEnabled(bool enabled) async {
    for (final track in _localStream.getAudioTracks()) {
      track.enabled = enabled;
    }
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    if (!_hasVideo) return;
    _videoTrack?.enabled = enabled;
  }

  @override
  Future<List<RtcCameraDevice>> listCameras() async {
    final rawDevices = await _navigator.mediaDevices.enumerateDevices();
    final cameras = <RtcCameraDevice>[];
    for (final rawDevice in rawDevices) {
      final device = rawDevice as rtc.MediaDeviceInfo;
      final deviceId = device.deviceId;
      if (device.kind != 'videoinput' || deviceId.isEmpty) {
        continue;
      }
      cameras.add(RtcCameraDevice(id: deviceId, label: device.label));
    }
    return cameras;
  }

  @override
  Future<void> switchCamera(String deviceId) async {
    await _videoSenderReady;
    final sender = _videoSender;
    if (sender == null) {
      throw StateError('No active video sender');
    }
    final stream = await _navigator.mediaDevices.getUserMedia({
      'audio': false,
      'video': buildVideoConstraints(deviceId, isWeb: kIsWeb),
    });
    final nextTrack = stream.getVideoTracks().isEmpty
        ? null
        : stream.getVideoTracks().first;
    if (nextTrack == null) {
      await stream.dispose();
      throw StateError('Selected camera has no video track');
    }
    await sender.replaceTrack(nextTrack);
    final oldTrack = _videoTrack;
    if (oldTrack != null) {
      await _localStream.removeTrack(oldTrack);
    }
    await _localStream.addTrack(nextTrack);
    _replacementStreams.add(stream);
    _videoTrack = nextTrack;
    _localRenderer.srcObject = _localStream;
    if (oldTrack != null) {
      try {
        await oldTrack.stop();
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final track in _localStream.getTracks()) {
      try {
        await track.stop();
      } catch (_) {}
    }
    try {
      await _pc.close();
    } catch (_) {}
    try {
      await _localStream.dispose();
    } catch (_) {}
    try {
      await _localRenderer.dispose();
    } catch (_) {}
    try {
      await _remoteRenderer.dispose();
    } catch (_) {}
    for (final stream in _replacementStreams) {
      try {
        await stream.dispose();
      } catch (_) {}
    }
    await _candidateController.close();
    await _stateController.close();
    await _remoteTrackController.close();
    try {
      await _pc.dispose();
    } catch (_) {}
  }
}

class RtcVideoPreview extends StatelessWidget {
  final rtc.RTCVideoRenderer renderer;

  const RtcVideoPreview(this.renderer, {super.key});

  @override
  Widget build(BuildContext context) {
    return rtc.RTCVideoView(
      renderer,
      objectFit: rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }
}
