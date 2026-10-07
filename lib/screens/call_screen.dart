import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../services/call_service.dart';
import '../services/chat_data_service.dart';
import '../services/rtc_peer.dart';
import '../services/api/tf_api_client.dart';
import '../models/user_profile.dart';
import '../widgets/account/profile_picture.dart';

/// 视频通话页面：展示本地预览 / 远端画面，以及静音、摄像头、挂断控制。
class CallScreen extends StatefulWidget {
  final int peerUid;

  const CallScreen({super.key, required this.peerUid});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  String? _routeCallId;

  @override
  void initState() {
    super.initState();
    _routeCallId = CallService.instance.callId;
  }

  @override
  void dispose() {
    final service = CallService.instance;
    if (_routeCallId != null &&
        service.callId == _routeCallId &&
        service.state != RtcCallState.idle &&
        service.state != RtcCallState.ended &&
        service.state != RtcCallState.failed) {
      service.hangup();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: CallService.instance,
        builder: (context, child) {
          final service = CallService.instance;
          final state = service.state;
          final isCurrentCall =
              service.peerUid == null || service.peerUid == widget.peerUid;

          if (!isCurrentCall || state == RtcCallState.idle) {
            return const _NoCallPlaceholder();
          }

          final document = switch (state) {
            RtcCallState.incoming => _IncomingCallView(
              peerUid: widget.peerUid,
              onAccept: () => service.acceptCall(),
              onDecline: service.declineCall,
            ),
            RtcCallState.outgoing => _ActiveCallView(
              peerUid: widget.peerUid,
              service: service,
              remoteLabel: 'outgoing',
            ),
            RtcCallState.connecting => _ActiveCallView(
              peerUid: widget.peerUid,
              service: service,
              remoteLabel: 'connecting',
            ),
            RtcCallState.connected => _ActiveCallView(
              peerUid: widget.peerUid,
              service: service,
              remoteLabel: 'connected',
            ),
            RtcCallState.ended => _EndedCallView(
              peerUid: widget.peerUid,
              service: service,
            ),
            RtcCallState.failed => _EndedCallView(
              peerUid: widget.peerUid,
              service: service,
            ),
            RtcCallState.idle => const _NoCallPlaceholder(),
          };

          return document;
        },
      ),
    );
  }
}

class _NoCallPlaceholder extends StatelessWidget {
  const _NoCallPlaceholder();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.videocam_off_outlined,
            color: Colors.white70,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.callNoActiveCall,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.pop(),
            child: Text(l10n.callClose),
          ),
        ],
      ),
    );
  }
}

class _IncomingCallView extends StatelessWidget {
  final int peerUid;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _IncomingCallView({
    required this.peerUid,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = ChatDataService.instance.displayNameForRoom(
      'U$peerUid',
      'UID $peerUid',
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 44,
          child: Text(
            name.isNotEmpty ? name.characters.first : '?',
            style: const TextStyle(fontSize: 36),
          ),
        ),
        const SizedBox(height: 20),
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 22)),
        const SizedBox(height: 8),
        Text(l10n.callIncoming, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundActionButton(
              icon: Icons.call_end_rounded,
              label: l10n.callDecline,
              color: Colors.redAccent,
              onPressed: onDecline,
            ),
            const SizedBox(width: 72),
            _RoundActionButton(
              icon: Icons.videocam_rounded,
              label: l10n.callAccept,
              color: Colors.greenAccent,
              onPressed: onAccept,
            ),
          ],
        ),
      ],
    );
  }
}

class _ActiveCallView extends StatelessWidget {
  final int peerUid;
  final CallService service;
  final String remoteLabel;

  const _ActiveCallView({
    required this.peerUid,
    required this.service,
    required this.remoteLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final remote = service.remoteVideo;
    final local = service.localVideo;
    final String statusText = switch (remoteLabel) {
      'outgoing' => l10n.callCalling,
      'connecting' => l10n.callConnecting,
      _ => '',
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        if (remote != null) remote else _RemoteCallFallback(peerUid: peerUid),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent, Colors.black87],
              stops: [0, 0.42, 1],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: service.hangup,
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: Colors.white,
                      tooltip: l10n.callHangup,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CallPeerIdentity(peerUid: peerUid, compact: true),
                          if (statusText.isNotEmpty)
                            Text(
                              statusText,
                              style: const TextStyle(color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (remoteLabel != 'connected' && remote == null)
                Text(
                  l10n.callWaitingForPeer,
                  style: const TextStyle(color: Colors.white70),
                ),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white12),
                ),
                child: _CallControls(service: service),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
        if (local != null)
          Positioned(
            top: 92,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 112,
                height: 158,
                decoration: BoxDecoration(
                  color: const Color(0xFF171A20),
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: local,
              ),
            ),
          ),
      ],
    );
  }
}

class _RemoteCallFallback extends StatelessWidget {
  final int peerUid;

  const _RemoteCallFallback({required this.peerUid});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0E1117),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CallPeerIdentity(peerUid: peerUid),
          const SizedBox(height: 16),
          _CallPeerIdentity(peerUid: peerUid, compact: true),
        ],
      ),
    );
  }
}

class _CallControls extends StatelessWidget {
  final CallService service;

  const _CallControls({required this.service});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 20,
      runSpacing: 12,
      children: [
        _RoundActionButton(
          icon: service.micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
          label: service.micEnabled ? l10n.callMute : l10n.callUnmute,
          color: service.micEnabled ? Colors.white : Colors.white70,
          onPressed: () => service.toggleMute(),
        ),
        _RoundActionButton(
          icon: service.cameraEnabled
              ? Icons.videocam_rounded
              : Icons.videocam_off_rounded,
          label: service.cameraEnabled ? l10n.callCameraOff : l10n.callCameraOn,
          color: service.cameraEnabled ? Colors.white : Colors.white70,
          onPressed: () => service.toggleCamera(),
        ),
        _RoundActionButton(
          icon: Icons.flip_camera_ios_rounded,
          label: l10n.callSwitchCamera,
          color: Colors.white,
          onPressed: () => _showCameraPicker(context, service),
        ),
        _RoundActionButton(
          icon: Icons.call_end_rounded,
          label: l10n.callHangup,
          color: Colors.redAccent,
          onPressed: service.hangup,
        ),
      ],
    );
  }

  Future<void> _showCameraPicker(
    BuildContext context,
    CallService service,
  ) async {
    List<RtcCameraDevice> cameras;
    try {
      cameras = await service.listCameras();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to list cameras: $error')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    if (cameras.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No available cameras')));
      return;
    }
    final selected = await showModalBottomSheet<RtcCameraDevice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: cameras.length,
          itemBuilder: (context, index) {
            final camera = cameras[index];
            return ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: Text(
                camera.label.isEmpty ? 'Camera ${index + 1}' : camera.label,
              ),
              onTap: () => Navigator.of(context).pop(camera),
            );
          },
        ),
      ),
    );
    if (selected != null) {
      try {
        await service.switchCamera(selected.id);
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to switch camera: $error')),
          );
        }
      }
    }
  }
}

class _CallPeerIdentity extends StatefulWidget {
  final int peerUid;
  final bool compact;

  const _CallPeerIdentity({required this.peerUid, this.compact = false});

  @override
  State<_CallPeerIdentity> createState() => _CallPeerIdentityState();
}

class _CallPeerIdentityState extends State<_CallPeerIdentity> {
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _profile =
        ChatDataService.instance.getUser('U${widget.peerUid}') ??
        ChatDataService.instance.getUser(widget.peerUid.toString());
    if (_profile == null) _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await TfApiClient.instance.getUserByUid(widget.peerUid);
    if (!mounted || profile == null) return;
    ChatDataService.instance.cacheUserProfile(profile);
    setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final name = profile == null
        ? 'UID ${widget.peerUid}'
        : ChatDataService.instance.displayNameForRoom(
            'U${widget.peerUid}',
            profile.username,
          );
    if (widget.compact) {
      return Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return ProfilePictureWidget(avatarUrl: profile?.avatar, radius: 52);
  }
}

class _EndedCallView extends StatelessWidget {
  final int peerUid;
  final CallService service;

  const _EndedCallView({required this.peerUid, required this.service});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = ChatDataService.instance.displayNameForRoom(
      'U$peerUid',
      'UID $peerUid',
    );
    final reason = service.endReason;
    final text = reason == null ? l10n.callEnded : _reasonText(l10n, reason);
    return Container(
      color: const Color(0xFF0E1117),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF252B35),
            ),
            child: const Icon(
              Icons.call_end_rounded,
              color: Colors.white70,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 32),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () => service.retryCall(),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.retry),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () {
                  service.resetFinishedCall();
                  context.pop();
                },
                icon: const Icon(Icons.close_rounded),
                label: Text(l10n.callClose),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _reasonText(AppLocalizations l10n, RtcCallEndReason reason) {
    return switch (reason) {
      RtcCallEndReason.hangup => l10n.callEnded,
      RtcCallEndReason.declined => l10n.callPeerDeclined,
      RtcCallEndReason.busy => l10n.callPeerBusy,
      RtcCallEndReason.noAnswer => l10n.callNoAnswer,
      RtcCallEndReason.offline => l10n.callPeerOffline,
      RtcCallEndReason.notFriends => l10n.callNotFriends,
      RtcCallEndReason.rateLimited => l10n.callServerLimited,
      RtcCallEndReason.invalidRequest => l10n.callInvalidRequest,
      RtcCallEndReason.connectFailed => l10n.callConnectFailed,
      RtcCallEndReason.mediaFailed => l10n.callMediaUnavailable,
      RtcCallEndReason.cancelled => l10n.callCancelled,
      RtcCallEndReason.error => l10n.callEndError,
    };
  }
}

class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _RoundActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color.withValues(alpha: 0.35),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(icon, color: color, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
