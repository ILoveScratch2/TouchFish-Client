import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:touchfish_client/services/call_service.dart';
import 'package:touchfish_client/services/chat_ws_service.dart';
import 'package:touchfish_client/services/rtc_peer.dart';

class FakeRtcPeer implements RtcPeer {
  bool disposeCalled = false;
  Map<String, dynamic>? remoteSdp;
  bool remoteDescriptionApplied = false;
  final List<Map<String, dynamic>> candidates = [];
  bool micEnabled = true;
  bool cameraEnabled = true;

  final _iceController = StreamController<Map<String, dynamic>>.broadcast();
  final _stateController = StreamController<String>.broadcast();
  final _trackController = StreamController<void>.broadcast();

  static Future<RtcPeer> create({required bool videoEnabled}) async =>
      FakeRtcPeer();

  void emitIceState(String state) => _stateController.add(state);

  @override
  Widget? get localVideo => null;

  @override
  Widget? get remoteVideo => null;

  @override
  Stream<Map<String, dynamic>> get onIceCandidate => _iceController.stream;

  @override
  Stream<String> get onIceConnectionState => _stateController.stream;

  @override
  Stream<void> get onRemoteTrack => _trackController.stream;

  @override
  Future<Map<String, dynamic>> createOffer() async {
    return {'sdp': 'fake-offer-sdp', 'sdp_type': 'offer'};
  }

  @override
  Future<Map<String, dynamic>> createAnswer() async {
    return {'sdp': 'fake-answer-sdp', 'sdp_type': 'answer'};
  }

  @override
  Future<void> setRemoteDescription(Map<String, dynamic> sdp) async {
    remoteSdp = sdp;
    remoteDescriptionApplied = true;
  }

  @override
  Future<void> addCandidate(Map<String, dynamic> candidate) async {
    candidates.add(candidate);
  }

  @override
  Future<void> setMicEnabled(bool enabled) async {
    micEnabled = enabled;
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    cameraEnabled = enabled;
  }

  @override
  Future<void> dispose() async {
    disposeCalled = true;
    await _iceController.close();
    await _stateController.close();
    await _trackController.close();
  }
}

void main() {
  late StreamController<ChatWsEvent> events;
  late List<Map<String, dynamic>> sent;
  late CallService service;

  setUp(() {
    CallService.resetForTesting();
    events = StreamController<ChatWsEvent>.broadcast();
    sent = [];
    service = CallService.instance;
    service.configureForTesting(
      sender: (packet) {
        sent.add(packet);
        return true;
      },
      peerFactory: FakeRtcPeer.create,
      eventStream: events.stream,
    );
  });

  tearDown(() {
    CallService.resetForTesting();
  });

  ChatWsEvent callEvent(String type, Map<String, dynamic> notification) =>
      ChatWsEvent(type: type, notification: notification);

  int? openedUid;
  bool? openedIncoming;
  void wireOpenScreen() {
    service.onOpenCallScreen = (peerUid, {required bool isIncoming}) async {
      openedUid = peerUid;
      openedIncoming = isIncoming;
    };
  }

  test('startCall sends call.invite and enters outgoing', () async {
    final ok = await service.startCall(42);
    expect(ok, isTrue);
    expect(service.state, RtcCallState.outgoing);
    expect(service.peerUid, 42);
    final invite = sent.single;
    expect(invite['type'], 'call.invite');
    expect(invite['target_uid'], 42);
    expect(invite['call_id'], isNotEmpty);
    expect((invite['payload'] as Map)['sdp'], 'fake-offer-sdp');
  });

  test('startCall rejected when already in a call', () async {
    await service.startCall(42);
    final ok = await service.startCall(7);
    expect(ok, isFalse);
    expect(sent.length, 1);
  });

  test('incoming invite notifies open screen and accept sends answer',
      () async {
    wireOpenScreen();
    events.add(callEvent('call.invite', {
      'call_id': 'c1',
      'from_uid': 42,
      'payload': {'sdp': 'remote-sdp', 'sdp_type': 'offer'},
    }));
    await Future<void>.delayed(Duration.zero);
    expect(service.state, RtcCallState.incoming);
    expect(service.peerUid, 42);
    expect(openedUid, 42);
    expect(openedIncoming, isTrue);

    final accepted = await service.acceptCall();
    expect(accepted, isTrue);
    expect(service.state, RtcCallState.connecting);
    final answer = sent.single;
    expect(answer['type'], 'call.answer');
    expect(answer['call_id'], 'c1');
    expect((answer['payload'] as Map)['sdp'], 'fake-answer-sdp');
  });

  test('incoming invite while busy is auto-declined', () async {
    await service.startCall(1);
    events.add(callEvent('call.invite', {
      'call_id': 'other',
      'from_uid': 42,
      'payload': {'sdp': 'x', 'sdp_type': 'offer'},
    }));
    await Future<void>.delayed(Duration.zero);
    final hangup = sent.lastWhere((p) => p['type'] == 'call.hangup');
    expect(hangup['reason'], 'busy');
    expect(hangup['target_uid'], 42);
    expect(service.state, RtcCallState.outgoing);
  });

  test('call.ice buffered before answer then flushed to peer', () async {
    events.add(callEvent('call.invite', {
      'call_id': 'c1',
      'from_uid': 42,
      'payload': {'sdp': 'remote-sdp', 'sdp_type': 'offer'},
    }));
    events.add(callEvent('call.ice', {
      'call_id': 'c1',
      'from_uid': 42,
      'candidate': {'candidate': 'a=b', 'sdpMid': '0', 'sdpMLineIndex': 0},
    }));
    await Future<void>.delayed(Duration.zero);
    await service.acceptCall();
    final servicePeer = service.debugPeer as FakeRtcPeer;
    expect(servicePeer.remoteDescriptionApplied, isTrue);
    expect(servicePeer.candidates.single['candidate'], 'a=b');
  });

  test('decline sends call.hangup decline and ends call', () async {
    events.add(callEvent('call.invite', {
      'call_id': 'c1',
      'from_uid': 42,
      'payload': {'sdp': 'remote-sdp', 'sdp_type': 'offer'},
    }));
    await Future<void>.delayed(Duration.zero);
    service.declineCall();
    expect(service.state, RtcCallState.ended);
    final hangup = sent.single;
    expect(hangup['type'], 'call.hangup');
    expect(hangup['reason'], 'decline');
  });

  test('call.ack offline fails the outgoing call', () async {
    await service.startCall(42);
    final callId = sent.single['call_id'];
    events.add(callEvent('call.ack', {
      'call_id': callId,
      'for': 'call.invite',
      'status': 'offline',
    }));
    await Future<void>.delayed(Duration.zero);
    expect(service.state, RtcCallState.failed);
    expect(service.endReason, RtcCallEndReason.offline);
  });

  test('call.ack not_friends fails the outgoing call', () async {
    await service.startCall(42);
    final callId = sent.single['call_id'];
    events.add(callEvent('call.ack', {
      'call_id': callId,
      'for': 'call.invite',
      'status': 'not_friends',
    }));
    await Future<void>.delayed(Duration.zero);
    expect(service.state, RtcCallState.failed);
    expect(service.endReason, RtcCallEndReason.notFriends);
  });

  test('answer leads to connecting then connected on ICE state', () async {
    await service.startCall(42);
    final callId = sent.single['call_id'];
    events.add(callEvent('call.answer', {
      'call_id': callId,
      'from_uid': 42,
      'payload': {'sdp': 'remote-answer', 'sdp_type': 'answer'},
    }));
    await Future<void>.delayed(Duration.zero);
    expect(service.state, RtcCallState.connecting);
    final peer = service.debugPeer as FakeRtcPeer;
    peer.emitIceState('connected');
    await Future<void>.delayed(Duration.zero);
    expect(service.state, RtcCallState.connected);
  });

  test('remote hangup cancel finishes the call', () async {
    await service.startCall(42);
    final callId = sent.single['call_id'];
    events.add(callEvent('call.hangup', {
      'call_id': callId,
      'from_uid': 42,
      'reason': 'cancel',
    }));
    await Future<void>.delayed(Duration.zero);
    expect(service.state, RtcCallState.ended);
    expect(service.endReason, RtcCallEndReason.cancelled);
  });

  test('hangup sends cancel while outgoing', () async {
    await service.startCall(42);
    service.hangup();
    final hangup = sent.last;
    expect(hangup['type'], 'call.hangup');
    expect(hangup['reason'], 'cancel');
    expect(service.state, RtcCallState.ended);
  });

  test('toggleMute and toggleCamera flip flags and delegate to peer',
      () async {
    await service.startCall(1);
    final peer = service.debugPeer as FakeRtcPeer;
    await service.toggleMute();
    expect(service.micEnabled, isFalse);
    expect(peer.micEnabled, isFalse);
    await service.toggleMute();
    expect(service.micEnabled, isTrue);
    expect(peer.micEnabled, isTrue);
    await service.toggleCamera();
    expect(service.cameraEnabled, isFalse);
    expect(peer.cameraEnabled, isFalse);
  });
}
