import 'package:flutter/widgets.dart';

/// 通话协商结果状态。
enum RtcCallState {
  /// 无通话。
  idle,

  /// 我方呼出，等待对方接听。
  outgoing,

  /// 我方被呼叫，等待接听。
  incoming,

  /// SDP 已交换，正在建立 P2P（ICE）连接。
  connecting,

  /// P2P 已建立，音视频正在传输。
  connected,

  /// 通话已结束。
  ended,

  /// 通话建立失败或异常终止。
  failed,
}

/// 通话结束/失败原因，用于 UI 提示。
enum RtcCallEndReason {
  /// 正常挂断。
  hangup,

  /// 对方拒绝接听。
  declined,

  /// 对方繁忙（正在通话中）。
  busy,

  /// 无人接听。
  noAnswer,

  /// 对方离线。
  offline,

  /// 非好友。
  notFriends,

  /// 被限流。
  rateLimited,

  /// 请求非法。
  invalidRequest,

  /// P2P 媒体连接建立失败。
  connectFailed,

  /// 本地媒体（摄像头/麦克风）不可用。
  mediaFailed,

  /// 对方取消呼叫。
  cancelled,

  /// 未知错误。
  error,
}

class RtcCameraDevice {
  final String id;
  final String label;

  const RtcCameraDevice({required this.id, required this.label});
}

/// 极薄的一次通话 RTC 会话抽象：把 flutter_webrtc 的使用限制在
/// [RealRtcPeer] 一个文件内，方便单元测试注入假实现。
abstract interface class RtcPeer {
  /// 本端摄像头预览 widget。
  Widget? get localVideo;

  /// 远端画面 widget（P2P 建立后才有内容）。
  Widget? get remoteVideo;

  /// 触发新的本地 ICE candidate（可直接发送给对方）。
  Stream<Map<String, dynamic>> get onIceCandidate;

  /// ICE 连接状态变化：'connected' / 'failed' / 'disconnected' 等。
  Stream<String> get onIceConnectionState;

  /// 远端媒体轨道到达（此时 [remoteVideo] 有内容）。
  Stream<void> get onRemoteTrack;

  /// 创建 offer SDP（返回 {sdp, sdp_type}）。
  Future<Map<String, dynamic>> createOffer();

  /// 创建 answer SDP（返回 {sdp, sdp_type}）。
  Future<Map<String, dynamic>> createAnswer();

  /// 应用远端 SDP（{sdp, sdp_type}）。
  Future<void> setRemoteDescription(Map<String, dynamic> sdp);

  /// 添加远端 ICE candidate（{candidate, sdpMid, sdpMLineIndex}）。
  Future<void> addCandidate(Map<String, dynamic> candidate);

  /// 开关本地麦克风。
  Future<void> setMicEnabled(bool enabled);

  /// 开关本地摄像头。
  Future<void> setCameraEnabled(bool enabled);

  /// Nintendo **Switch**Camera
  Future<List<RtcCameraDevice>> listCameras();

  Future<void> switchCamera(String deviceId);

  /// 释放所有本地媒体与连接资源。
  Future<void> dispose();
}

/// 创建 [RtcPeer]，测试可注入假实现。
typedef RtcPeerFactory =
    Future<RtcPeer> Function({
      required bool videoEnabled,
      List<Map<String, dynamic>>? iceServers,
    });
