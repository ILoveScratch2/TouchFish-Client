import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../utils/talker.dart';
import 'auth_state.dart';
import 'chat_ws_service.dart';
import 'real_rtc_peer.dart';
import 'rtc_peer.dart';

/// 视频通话信令 + 状态机。
///
/// 服务端只做信令中继，媒体�?（RTC）走 P2P。本服务监听
/// [ChatWsService] 的加密信令流，处理呼叫 / 应答 / ICE / 挂断状态迁移。
class CallService extends ChangeNotifier {
  CallService._();

  static CallService? _instance;
  static CallService get instance => _instance ??= CallService._();

  static const Duration _ringTimeout = Duration(seconds: 30);
  static const Duration _connectTimeout = Duration(seconds: 20);

  bool Function(Map<String, dynamic> packet) _send =
      (packet) => ChatWsService.instance.sendEncryptedPacket(packet);

  RtcPeerFactory _peerFactory = RealRtcPeer.create;

  Stream<ChatWsEvent>? _eventStream;
  bool _initialized = false;

  RtcCallState _state = RtcCallState.idle;
  RtcCallState get state => _state;

  int? _peerUid;
  int? get peerUid => _peerUid;

  String? _callId;

  RtcPeer? _peer;
  Map<String, dynamic>? _incomingOffer;
  final List<Map<String, dynamic>> _pendingCandidates = [];
  bool _remoteDescriptionApplied = false;

  bool _micEnabled = true;
  bool get micEnabled => _micEnabled;
  bool _cameraEnabled = true;
  bool get cameraEnabled => _cameraEnabled;

  bool _remoteStreamPresent = false;
  bool get remoteStreamPresent => _remoteStreamPresent;

  RtcCallEndReason? _endReason;
  RtcCallEndReason? get endReason => _endReason;

  /// 本端摄像头预览。
  Widget? get localVideo => _peer?.localVideo;

  /// 远端画面。
  Widget? get remoteVideo => _peer?.remoteVideo;

  @visibleForTesting
  RtcPeer? get debugPeer => _peer;

  final Random _random = Random();

  Timer? _ringTimer;
  Timer? _connectTimer;

  /// 打开通话页面（来电时由本服务自动触发）。
  Future<void> Function(int peerUid, {required bool isIncoming})?
      onOpenCallScreen;

  late final StreamSubscription _wsSubscription;

  void init() {
    if (_initialized) return;
    _initialized = true;
    final stream = _eventStream ?? ChatWsService.instance.eventStream;
    _wsSubscription = stream.listen(_onWsEvent);
  }

  @visibleForTesting
  void configureForTesting({
    bool Function(Map<String, dynamic> packet)? sender,
    RtcPeerFactory? peerFactory,
    Stream<ChatWsEvent>? eventStream,
  }) {
    if (sender != null) _send = sender;
    if (peerFactory != null) _peerFactory = peerFactory;
    if (eventStream != null) _eventStream = eventStream;
    init();
  }

  @visibleForTesting
  static void resetForTesting() {
    final service = _instance;
    if (service == null) return;
    service._wsSubscription.cancel();
    service._cancelTimers();
    final peer = service._peer;
    service._peer = null;
    if (peer != null) {
      unawaited(peer.dispose());
    }
    service._initialized = false;
    service._eventStream = null;
    service._state = RtcCallState.idle;
    service._peerUid = null;
    service._callId = null;
    service._incomingOffer = null;
    service._pendingCandidates.clear();
    service._remoteDescriptionApplied = false;
    service._remoteStreamPresent = false;
    service._endReason = null;
    service._micEnabled = true;
    service._cameraEnabled = true;
    service.onOpenCallScreen = null;
    _instance = null;
  }

  /// 呼出视频通话。
  Future<bool> startCall(int peerUid) async {
    if (_state != RtcCallState.idle) return false;
    _resetSession();
    _state = RtcCallState.outgoing;
    _peerUid = peerUid;
    _callId = _generateCallId();
    _micEnabled = true;
    _cameraEnabled = true;
    _endReason = null;
    notifyListeners();
    _startRingTimer();
    try {
      final peer = await _peerFactory(videoEnabled: true);
      _attachPeer(peer);
      final offer = await peer.createOffer();
      _send({
        'type': 'call.invite',
        'call_id': _callId,
        'target_uid': peerUid,
        'payload': offer,
      });
      return true;
    } catch (e, stackTrace) {
      talker.error('CallService.startCall failed', e, stackTrace);
      _finishCall(
        failed: true,
        reason: RtcCallEndReason.mediaFailed,
      );
      return false;
    }
  }

  /// 接听来电。
  Future<bool> acceptCall() async {
    if (_state != RtcCallState.incoming) return false;
    final offer = _incomingOffer;
    if (offer == null) {
      _finishCall(failed: true, reason: RtcCallEndReason.error);
      return false;
    }
    _cancelTimers();
    _state = RtcCallState.connecting;
    notifyListeners();
    _startConnectTimer();
    try {
      final peer = await _peerFactory(videoEnabled: true);
      _attachPeer(peer);
      await peer.setRemoteDescription(offer);
      _remoteDescriptionApplied = true;
      for (final candidate in List.of(_pendingCandidates)) {
        try {
          await peer.addCandidate(candidate);
        } catch (_) {}
      }
      _pendingCandidates.clear();
      final answer = await peer.createAnswer();
      _send({
        'type': 'call.answer',
        'call_id': _callId,
        'target_uid': _peerUid,
        'payload': answer,
      });
      return true;
    } catch (e, stackTrace) {
      talker.error('CallService.acceptCall failed', e, stackTrace);
      _finishCall(failed: true, reason: RtcCallEndReason.mediaFailed);
      return false;
    }
  }

  /// 拒绝来电。
  void declineCall() {
    if (_state != RtcCallState.incoming) return;
    _sendHangup('decline');
    _finishCall(failed: false, reason: RtcCallEndReason.hangup);
  }

  /// 挂断 / 取消当前通话。
  void hangup() {
    if (_state == RtcCallState.idle) return;
    final reason = _state == RtcCallState.incoming
        ? 'decline'
        : _state == RtcCallState.outgoing
            ? 'cancel'
            : 'hangup';
    _sendHangup(reason);
    _finishCall(failed: false, reason: RtcCallEndReason.hangup);
  }

  Future<void> toggleMute() async {
    final peer = _peer;
    if (peer == null) return;
    _micEnabled = !_micEnabled;
    try {
      await peer.setMicEnabled(_micEnabled);
    } catch (e, stackTrace) {
      talker.error('CallService.toggleMute failed', e, stackTrace);
    }
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    final peer = _peer;
    if (peer == null) return;
    _cameraEnabled = !_cameraEnabled;
    try {
      await peer.setCameraEnabled(_cameraEnabled);
    } catch (e, stackTrace) {
      talker.error('CallService.toggleCamera failed', e, stackTrace);
    }
    notifyListeners();
  }

  void _sendHangup(String reason) {
    if (_callId != null && _peerUid != null) {
      _send({
        'type': 'call.hangup',
        'call_id': _callId,
        'target_uid': _peerUid,
        'reason': reason,
      });
    }
  }

  void _onWsEvent(ChatWsEvent event) {
    final data = event.notification;
    if (data == null) return;
    switch (event.type) {
      case 'call.invite':
        _onInvite(data);
        break;
      case 'call.answer':
        _onAnswer(data);
        break;
      case 'call.ice':
        _onIce(data);
        break;
      case 'call.hangup':
        _onRemoteHangup(data);
        break;
      case 'call.ack':
        _onAck(data);
        break;
    }
  }

  void _onInvite(Map<String, dynamic> data) {
    final fromUid = data['from_uid'];
    final callId = data['call_id'];
    final payload = data['payload'];
    if (fromUid is! int || callId is! String) return;
    if (payload is! Map<String, dynamic> || payload['sdp'] is! String) {
      _send({
        'type': 'call.hangup',
        'call_id': callId,
        'target_uid': fromUid,
        'reason': 'cancel',
      });
      return;
    }
    if (_state != RtcCallState.idle) {
      _send({
        'type': 'call.hangup',
        'call_id': callId,
        'target_uid': fromUid,
        'reason': 'busy',
      });
      return;
    }
    _state = RtcCallState.incoming;
    _peerUid = fromUid;
    _callId = callId;
    _incomingOffer = payload;
    notifyListeners();
    onOpenCallScreen?.call(fromUid, isIncoming: true);
  }

  void _onAnswer(Map<String, dynamic> data) {
    if (_state != RtcCallState.outgoing) return;
    final fromUid = data['from_uid'];
    final callId = data['call_id'];
    final payload = data['payload'];
    if (fromUid != _peerUid || callId != _callId) return;
    if (payload is! Map<String, dynamic> || payload['sdp'] is! String) {
      _finishCall(failed: true, reason: RtcCallEndReason.invalidRequest);
      return;
    }
    _cancelRingTimer();
    _state = RtcCallState.connecting;
    notifyListeners();
    _startConnectTimer();
    _applyRemote(payload);
  }

  void _onIce(Map<String, dynamic> data) {
    final fromUid = data['from_uid'];
    final callId = data['call_id'];
    final candidate = data['candidate'];
    if (fromUid != _peerUid || callId != _callId) return;
    if (candidate is! Map<String, dynamic>) return;
    final peer = _peer;
    if (peer != null && _remoteDescriptionApplied) {
      unawaited(peer.addCandidate(candidate).catchError((_) {}));
    } else {
      _pendingCandidates.add(candidate);
    }
  }

  void _onRemoteHangup(Map<String, dynamic> data) {
    final fromUid = data['from_uid'];
    final callId = data['call_id'];
    if (fromUid != _peerUid || callId != _callId) return;
    switch (data['reason']) {
      case 'decline':
        _finishCall(failed: true, reason: RtcCallEndReason.declined);
        break;
      case 'busy':
        _finishCall(failed: true, reason: RtcCallEndReason.busy);
        break;
      case 'cancel':
        _finishCall(failed: false, reason: RtcCallEndReason.cancelled);
        break;
      case 'error':
        _finishCall(failed: true, reason: RtcCallEndReason.error);
        break;
      default:
        _finishCall(failed: false, reason: RtcCallEndReason.hangup);
    }
  }

  void _onAck(Map<String, dynamic> data) {
    final callId = data['call_id'];
    if (callId != _callId) return;
    if (data['for'] != 'call.invite') return;
    if (_state != RtcCallState.outgoing) return;
    switch (data['status']) {
      case 'offline':
        _finishCall(failed: true, reason: RtcCallEndReason.offline);
        break;
      case 'not_friends':
        _finishCall(failed: true, reason: RtcCallEndReason.notFriends);
        break;
      case 'rate_limited':
        _finishCall(failed: true, reason: RtcCallEndReason.rateLimited);
        break;
      case 'invalid_target':
      case 'invalid_call_id':
      case 'invalid_request':
        _finishCall(failed: true, reason: RtcCallEndReason.invalidRequest);
        break;
    }
  }

  void _applyRemote(Map<String, dynamic> sdp) async {
    final peer = _peer;
    if (peer == null) return;
    try {
      await peer.setRemoteDescription(sdp);
      _remoteDescriptionApplied = true;
      for (final candidate in List.of(_pendingCandidates)) {
        try {
          await peer.addCandidate(candidate);
        } catch (_) {}
      }
      _pendingCandidates.clear();
    } catch (e, stackTrace) {
      talker.error('CallService._applyRemote failed', e, stackTrace);
      _finishCall(failed: true, reason: RtcCallEndReason.connectFailed);
    }
  }

  void _attachPeer(RtcPeer peer) {
    _peer = peer;
    _remoteDescriptionApplied = false;
    peer.onIceCandidate.listen((candidate) {
      final callId = _callId;
      final peerUid = _peerUid;
      if (_state == RtcCallState.idle || callId == null || peerUid == null) {
        return;
      }
      _send({
        'type': 'call.ice',
        'call_id': callId,
        'target_uid': peerUid,
        'candidate': candidate,
      });
    });
    peer.onIceConnectionState.listen(_onPeerIceState);
    peer.onRemoteTrack.listen((_) {
      _remoteStreamPresent = true;
      notifyListeners();
    });
  }

  void _onPeerIceState(String state) {
    switch (state) {
      case 'connected':
        _cancelConnectTimer();
        if (_state == RtcCallState.connecting) {
          _state = RtcCallState.connected;
          notifyListeners();
        }
        break;
      case 'failed':
        if (_state == RtcCallState.connecting ||
            _state == RtcCallState.connected) {
          _finishCall(failed: true, reason: RtcCallEndReason.connectFailed);
        }
        break;
    }
  }

  void _startRingTimer() {
    _ringTimer = Timer(_ringTimeout, () {
      if (_state != RtcCallState.outgoing) return;
      _sendHangup('cancel');
      _finishCall(failed: true, reason: RtcCallEndReason.noAnswer);
    });
  }

  void _startConnectTimer() {
    _connectTimer = Timer(_connectTimeout, () {
      if (_state != RtcCallState.connecting) return;
      _finishCall(failed: true, reason: RtcCallEndReason.connectFailed);
    });
  }

  void _cancelTimers() {
    _cancelRingTimer();
    _cancelConnectTimer();
  }

  void _cancelRingTimer() {
    _ringTimer?.cancel();
    _ringTimer = null;
  }

  void _cancelConnectTimer() {
    _connectTimer?.cancel();
    _connectTimer = null;
  }

  void _finishCall({
    required bool failed,
    RtcCallEndReason reason = RtcCallEndReason.hangup,
  }) {
    _cancelTimers();
    final peer = _peer;
    _peer = null;
    _state = failed ? RtcCallState.failed : RtcCallState.ended;
    _endReason = reason;
    _peerUid = null;
    _callId = null;
    _incomingOffer = null;
    _pendingCandidates.clear();
    _remoteDescriptionApplied = false;
    _remoteStreamPresent = false;
    notifyListeners();
    if (peer != null) {
      unawaited(peer.dispose());
    }
  }

  void _resetSession() {
    _cancelTimers();
    final peer = _peer;
    _peer = null;
    _incomingOffer = null;
    _pendingCandidates.clear();
    _remoteDescriptionApplied = false;
    _remoteStreamPresent = false;
    if (peer != null) {
      unawaited(peer.dispose());
    }
  }

  String _generateCallId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final uid = AuthState.instance.uid?.toString() ?? 'u';
    final nonce = _random.nextInt(0x7fffffff);
    return '$now-$uid-$nonce';
  }
}