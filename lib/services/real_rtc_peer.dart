import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:flutter/widgets.dart';

import 'rtc_peer.dart';

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
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': videoEnabled,
    });
    final pc = await (factory == null
        ? rtc.createPeerConnection({'iceServers': iceServers})
        : factory.createPeerConnection({'iceServers': iceServers}));
    final peer = RealRtcPeer._(pc, stream, videoEnabled);
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