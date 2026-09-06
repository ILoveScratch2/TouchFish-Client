import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:flutter/widgets.dart';

import 'rtc_peer.dart';

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
  return (
    audio: hasMic,
    video: videoRequested && hasCamera,
  );
}

/// 基于 flutter_webrtc 的真实通话会话。
class RealRtcPeer implements RtcPeer {
  final rtc.RTCPeerConnection _pc;
  final rtc.MediaStream _localStream;
  rtc.MediaStream? _remoteStream;
  final rtc.RTCVideoRenderer _localRenderer = rtc.RTCVideoRenderer();
  final rtc.RTCVideoRenderer _remoteRenderer = rtc.RTCVideoRenderer();
  final bool _hasVideo;

  final _candidateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _stateController = StreamController<String>.broadcast();
  final _remoteTrackController = StreamController<void>.broadcast();

  RealRtcPeer._(this._pc, this._localStream, this._hasVideo) {
    _pc.onIceCandidate = (candidate) {
      final value = candidate.candidate;
      if (value == null || value.isEmpty) return;
      _candidateController.add(candidate.toMap());
    };
    _pc.onIceConnectionState = (state) {
      _stateController.add(
        state.toString().split('.').last.toLowerCase(),
      );
    };
    _pc.onTrack = (event) {
      if (event.streams.isEmpty) return;
      _remoteStream = event.streams.first;
      _remoteRenderer.srcObject = event.streams.first;
      _remoteTrackController.add(null);
    };
    _localStream.getAudioTracks().forEach((track) {
      _pc.addTrack(track, _localStream);
    });
    if (_hasVideo) {
      _localStream.getVideoTracks().forEach((track) {
        _pc.addTrack(track, _localStream);
      });
    }
  }

  /// 创建会话：获取本地音视频并建立 RTCPeerConnection。
  static Future<RealRtcPeer> create({
    required bool videoEnabled,
    List<Map<String, dynamic>> iceServers = const [
      {
        'urls': [
          'stun:stun.miwifi.com:3478',
          'stun:stun.qq.com:3478',
        ],
      },
    ],
    rtc.RTCFactory? factory,
  }) async {
    final navigator = factory?.navigator ?? rtc.navigator;

    // 探测真实可用的输入设备。Windows 原生 GetUserAudio 在 `audio:true` 且
    // RecordingDevices() 为 0 时会越界读索引 0，直接段错误崩掉整个 App，
    // 触达不到 Dart 的 catch。这里先用无副作用的 enumerateDevices 安全探测，
    // 只在确实存在输入设备时才请求对应媒体，从根上避免原生崩溃。
    var audioAvailable = true;
    var videoAvailable = videoEnabled;
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      final availability =
          resolveMediaAvailability(devices.map((d) => d.kind ?? ''),
              videoRequested: videoEnabled);
      audioAvailable = availability.audio;
      videoAvailable = availability.video;
    } catch (_) {
      // 枚举失败属异常情况：退回全请求，与旧行为一致。
    }

    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': audioAvailable,
      'video': videoAvailable,
    });
    final pc = await (factory == null
        ? rtc.createPeerConnection({'iceServers': iceServers})
        : factory.createPeerConnection({'iceServers': iceServers}));
    final peer = RealRtcPeer._(pc, stream, videoAvailable);
    await peer._localRenderer.initialize();
    peer._localRenderer.srcObject = stream;
    await peer._remoteRenderer.initialize();
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
    final desc = await _pc.createOffer();
    await _pc.setLocalDescription(desc);
    return {'sdp': desc.sdp, 'sdp_type': desc.type};
  }

  @override
  Future<Map<String, dynamic>> createAnswer() async {
    final desc = await _pc.createAnswer();
    await _pc.setLocalDescription(desc);
    return {'sdp': desc.sdp, 'sdp_type': desc.type};
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
    for (final track in _localStream.getVideoTracks()) {
      track.enabled = enabled;
    }
  }

  @override
  Future<void> dispose() async {
    await _candidateController.close();
    await _stateController.close();
    await _remoteTrackController.close();
    await _localRenderer.dispose();
    await _remoteRenderer.dispose();
    await _localStream.dispose();
    await _pc.dispose();
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