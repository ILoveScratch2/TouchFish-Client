import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../utils/talker.dart';
import 'api/tf_api_client.dart';
import 'api/tf_crypto.dart';
import 'auth_state.dart';

enum ChatWsState { disconnected, connecting, connected, authenticated }

class ChatWsService extends ChangeNotifier {
  static ChatWsService? _instance;
  static ChatWsService get instance => _instance ??= ChatWsService._();
  ChatWsService._();

  ChatWsState _state = ChatWsState.disconnected;
  ChatWsState get state => _state;
  bool get isAuthenticated => _state == ChatWsState.authenticated;

  WebSocketChannel? _channel;
  Uint8List? _sessionAesKey;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  Timer? _pongCheckTimer;
  StreamSubscription? _subscription;
  bool _intentionalClose = false;
  int _reconnectAttempts = 0;
  double _lastPongTime = 0;
  static const _maxReconnectAttempts = 10;
  static const _pongTimeout = Duration(seconds: 15);

  Completer<bool>? _authCompleter;

  final StreamController<ChatWsEvent> _eventController =
      StreamController<ChatWsEvent>.broadcast();
  Stream<ChatWsEvent> get eventStream => _eventController.stream;

  /// Connect to WebSocket, perform RSA+AES handshake, authenticate.
  Future<bool> connect() async {
    if (_state == ChatWsState.connecting || _state == ChatWsState.authenticated) {
      return _state == ChatWsState.authenticated;
    }

    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return false;

    _intentionalClose = false;
    _setState(ChatWsState.connecting);

    try {
      final host = await _resolveHost();
      final tcpPort = await _resolveTcpPort();
      final wsUrl = 'ws://$host:$tcpPort';

      talker.info('ChatWsService connecting to $wsUrl');

      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel = channel;
      _setState(ChatWsState.connected);

      _subscription = channel.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      // Phase 1: Send RSA-encrypted AES key as plain JSON
      final pubKey = await TfApiClient.instance.getRsaPublicKey();
      final aesKey = TfCrypto.generateAesKey();
      _sessionAesKey = aesKey;
      final encryptedAesKey = TfCrypto.rsaEncrypt(aesKey, pubKey);
      channel.sink.add(jsonEncode({
        'type': 'REQ.UPDATE_AES_KEY',
        'aes_key': base64.encode(encryptedAesKey),
      }));

      // Phase 2: Send AUTH.LOGIN encrypted as {"iv": ..., "content": ...}
      // TCP guarantees ordering, so the server will process REQ.UPDATE_AES_KEY first.
      _sendEncrypted(jsonEncode({
        'type': 'AUTH.LOGIN',
        'uid': uid,
        'password': password,
      }));

      // Phase 3: Wait for AUTH.LOGIN_SUCCEEDED
      _authCompleter = Completer<bool>();
      final success = await _authCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          talker.warning('ChatWsService auth timeout');
          return false;
        },
      );
      _authCompleter = null;

      if (success) {
        _setState(ChatWsState.authenticated);
        _reconnectAttempts = 0;
        _startPing();
        talker.info('ChatWsService authenticated');
      } else {
        _disconnectCleanup();
      }
      return success;
    } catch (e) {
      talker.error('ChatWsService connect error', e);
      _scheduleReconnect();
      return false;
    }
  }

  void _onData(dynamic data) {
    String text;
    if (data is String) {
      text = data;
    } else if (data is List<int>) {
      text = utf8.decode(data);
    } else {
      return;
    }

    // Try to decrypt as {"iv": "...", "content": "..."} JSON
    if (_sessionAesKey != null) {
      final decrypted = _tryDecrypt(text);
      if (decrypted != null) {
        try {
          final data = jsonDecode(decrypted) as Map<String, dynamic>;
          _processPacket(data);
          return;
        } catch (_) {}
      }
    }

    // Plain JSON (used during REQ.UPDATE_AES_KEY handshake - no response needed)
    try {
      final parsed = jsonDecode(text);
      if (parsed is Map<String, dynamic>) {
        if (parsed['type'] == 'AUTH.LOGIN_SUCCEEDED') {
          _authCompleter?.complete(true);
        }
      }
    } catch (_) {}
  }

  void _onError(Object error) {
    talker.error('ChatWsService stream error', error);
  }

  void _onDone() {
    talker.info('ChatWsService stream closed');
    if (!_intentionalClose) _scheduleReconnect();
  }

  void _processPacket(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return;

    if (type == 'AUTH.LOGIN_SUCCEEDED') {
      _authCompleter?.complete(true);
      return;
    }

    if (type == 'PONG') {
      _lastPongTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
      return;
    }

    if (type == 'NOTIFICATION.NEW') {
      final notif = data['notification'] as Map<String, dynamic>?;
      if (notif != null) {
        final ts = (notif['time_stamp'] as num?)?.toDouble();
        _eventController.add(ChatWsEvent(
          type: 'NOTIFICATION.NEW',
          notification: notif,
          timeStamp: ts ?? DateTime.now().millisecondsSinceEpoch / 1000.0,
        ));
      }
      return;
    }

    // Forward other typed events (message.ack, message.read, typing.*)
    _eventController.add(ChatWsEvent(
      type: type,
      notification: data,
      timeStamp: DateTime.now().millisecondsSinceEpoch / 1000.0,
    ));
  }

  /// Send AES-encrypted payload as {"iv": "<base64>", "content": "<base64>"}
  void _sendEncrypted(String plainJson) {
    if (_sessionAesKey == null || _channel == null) return;
    final iv = TfCrypto.generateIv();
    final encrypted = TfCrypto.aesEncrypt(plainJson, _sessionAesKey!, iv);
    final payload = jsonEncode({
      'iv': base64.encode(iv),
      'content': base64.encode(encrypted),
    });
    _channel!.sink.add(payload);
  }

  /// Try to decrypt a {"iv": "...", "content": "..."} JSON message
  String? _tryDecrypt(String text) {
    if (_sessionAesKey == null) return null;
    try {
      final wrapper = jsonDecode(text);
      if (wrapper is! Map<String, dynamic>) return null;
      final ivB64 = wrapper['iv'];
      final contentB64 = wrapper['content'];
      if (ivB64 is! String || contentB64 is! String) return null;
      final iv = base64.decode(ivB64);
      final ct = base64.decode(contentB64);
      return TfCrypto.aesDecrypt(Uint8List.fromList(ct), _sessionAesKey!, Uint8List.fromList(iv));
    } catch (_) {
      return null;
    }
  }

  Future<String> _resolveHost() async {
    final prefs = await SharedPreferences.getInstance();
    final serversJson = prefs.getStringList('serversV2');
    final selectedIndex = prefs.getInt('selectedServerIndex') ?? 0;
    if (serversJson != null && serversJson.isNotEmpty) {
      final idx = selectedIndex.clamp(0, serversJson.length - 1);
      final info = jsonDecode(serversJson[idx]) as Map<String, dynamic>;
      return info['address'] as String? ?? '127.0.0.1';
    }
    return '127.0.0.1';
  }

  Future<int> _resolveTcpPort() async {
    final prefs = await SharedPreferences.getInstance();
    final serversJson = prefs.getStringList('serversV2');
    final selectedIndex = prefs.getInt('selectedServerIndex') ?? 0;
    if (serversJson != null && serversJson.isNotEmpty) {
      final idx = selectedIndex.clamp(0, serversJson.length - 1);
      final info = jsonDecode(serversJson[idx]) as Map<String, dynamic>;
      final raw = info['tcpPort'] ?? info['tcp_port'];
      if (raw != null) return int.tryParse(raw.toString()) ?? 1145;
    }
    return 1145;
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pongCheckTimer?.cancel();
    _pongCheckTimer = null; // only start after first PING
    _pingTimer = Timer.periodic(const Duration(seconds: 50), (_) {
      if (_state == ChatWsState.authenticated && _channel != null) {
        try {
          _sendEncrypted(jsonEncode({'type': 'PING'}));
        } catch (_) {}
        if (_pongCheckTimer == null) {
          _lastPongTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
          _pongCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
            if (_state != ChatWsState.authenticated || _channel == null) return;
            final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
            if (now - _lastPongTime > _pongTimeout.inSeconds) {
              talker.warning('ChatWsService PONG timeout, reconnecting');
              _scheduleReconnect();
            }
          });
        }
      }
    });
  }

  void _disconnectCleanup() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _sessionAesKey = null;
    _pingTimer?.cancel();
    _pongCheckTimer?.cancel();
    _setState(ChatWsState.disconnected);
  }

  void _scheduleReconnect() {
    _disconnectCleanup();
    if (_intentionalClose) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectAttempts++;
    final delay = Duration(seconds: min(_reconnectAttempts * 2, 30));
    talker.info('ChatWsService reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_intentionalClose) connect();
    });
  }

  void _setState(ChatWsState s) {
    if (_state != s) {
      _state = s;
      notifyListeners();
    }
  }

  // --- Public API ---

  Future<bool> sendTextMessage(String sendToUid, String text, {int quote = -1, String? clientMid}) {
    if (_state != ChatWsState.authenticated) return Future.value(false);
    try {
      final payload = <String, dynamic>{
        'type': 'message.plain',
        'content': {'plain': text, 'send_to': 'U$sendToUid', 'quote': quote},
      };
      if (clientMid != null) payload['client_mid'] = clientMid;
      _sendEncrypted(jsonEncode(payload));
      return Future.value(true);
    } catch (e) {
      talker.error('sendTextMessage error', e);
      return Future.value(false);
    }
  }

  Future<bool> sendGroupTextMessage(int gid, String text, {int quote = -1, String? clientMid}) {
    if (_state != ChatWsState.authenticated) return Future.value(false);
    try {
      final payload = <String, dynamic>{
        'type': 'message.plain',
        'content': {'plain': text, 'send_to': 'G$gid', 'quote': quote},
      };
      if (clientMid != null) payload['client_mid'] = clientMid;
      _sendEncrypted(jsonEncode(payload));
      return Future.value(true);
    } catch (e) {
      talker.error('sendGroupTextMessage error', e);
      return Future.value(false);
    }
  }

  Future<bool> sendFileMessage(String sendToUid, String fileHash, {int quote = -1, String? clientMid}) {
    if (_state != ChatWsState.authenticated) return Future.value(false);
    try {
      final payload = <String, dynamic>{
        'type': 'message.file',
        'content': {'send_to': 'U$sendToUid', 'quote': quote},
        'file_hashes': fileHash,
      };
      if (clientMid != null) payload['client_mid'] = clientMid;
      _sendEncrypted(jsonEncode(payload));
      return Future.value(true);
    } catch (e) {
      talker.error('sendFileMessage error', e);
      return Future.value(false);
    }
  }

  Future<bool> sendGroupFileMessage(int gid, String fileHash, {int quote = -1, String? clientMid}) {
    if (_state != ChatWsState.authenticated) return Future.value(false);
    try {
      final payload = <String, dynamic>{
        'type': 'message.file',
        'content': {'send_to': 'G$gid', 'quote': quote},
        'file_hashes': fileHash,
      };
      if (clientMid != null) payload['client_mid'] = clientMid;
      _sendEncrypted(jsonEncode(payload));
      return Future.value(true);
    } catch (e) {
      talker.error('sendGroupFileMessage error', e);
      return Future.value(false);
    }
  }

  void sendReadReceipt(String roomId, int lastMid) {
    if (_state != ChatWsState.authenticated) return;
    _sendEncrypted(jsonEncode({
      'type': 'message.read',
      'room_id': roomId,
      'last_mid': lastMid,
    }));
  }

  void sendTyping(String roomId, bool isTyping) {
    if (_state != ChatWsState.authenticated) return;
    _sendEncrypted(jsonEncode({
      'type': isTyping ? 'typing.start' : 'typing.stop',
      'room_id': roomId,
    }));
  }

  Future<void> disconnect() async {
    _intentionalClose = true;
    _reconnectTimer?.cancel();
    _disconnectCleanup();
  }

  @override
  void dispose() {
    disconnect();
    _eventController.close();
    super.dispose();
  }
}

class ChatWsEvent {
  final String type;
  final Map<String, dynamic>? notification;
  final double? timeStamp;

  const ChatWsEvent({
    required this.type,
    this.notification,
    this.timeStamp,
  });
}
