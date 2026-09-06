import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../services/call_service.dart';
import '../services/chat_data_service.dart';
import '../services/rtc_peer.dart';

/// 视频通话页面：展示本地预览 / 远端画面，以及静音、摄像头、挂断控制。
class CallScreen extends StatelessWidget {
  final int peerUid;

  const CallScreen({super.key, required this.peerUid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: CallService.instance,
        builder: (context, child) {
          final service = CallService.instance;
          final state = service.state;
          final isCurrentCall = service.peerUid == null ||
              service.peerUid == peerUid;

          if (!isCurrentCall || state == RtcCallState.idle) {
            return const _NoCallPlaceholder();
          }

          final document = switch (state) {
            RtcCallState.incoming => _IncomingCallView(
                peerUid: peerUid,
                onAccept: () => service.acceptCall(),
                onDecline: service.declineCall,
              ),
            RtcCallState.outgoing => _ActiveCallView(
                peerUid: peerUid,
                service: service,
                remoteLabel: 'outgoing',
              ),
            RtcCallState.connecting => _ActiveCallView(
                peerUid: peerUid,
                service: service,
                remoteLabel: 'connecting',
              ),
            RtcCallState.connected => _ActiveCallView(
                peerUid: peerUid,
                service: service,
                remoteLabel: 'connected',
              ),
            RtcCallState.ended => _EndedCallView(peerUid: peerUid, service: service),
            RtcCallState.failed => _EndedCallView(peerUid: peerUid, service: service),
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
          const Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 64),
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
        Text(
          l10n.callIncoming,
          style: const TextStyle(color: Colors.white70),
        ),
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
    final name = ChatDataService.instance.displayNameForRoom(
      'U$peerUid',
      'UID $peerUid',
    );

    final String statusText = switch (remoteLabel) {
      'outgoing' => l10n.callCalling,
      'connecting' => l10n.callConnecting,
      _ => '',
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        if (remote != null)
          remote
        else
          Container(color: Colors.black),
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
              if (statusText.isNotEmpty)
                Text(statusText,
                    style: const TextStyle(color: Colors.white70)),
              const Spacer(),
              if (remoteLabel != 'connected')
                Center(
                  child: Text(
                    l10n.callWaitingForPeer,
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              const SizedBox(height: 20),
              _CallControls(service: service, isConnected: remoteLabel == 'connected'),
              const SizedBox(height: 24),
            ],
          ),
        ),
        if (local != null && remoteLabel == 'connected')
          Positioned(
            top: 80,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 140, height: 200, child: local),
            ),
          ),
      ],
    );
  }
}

class _CallControls extends StatelessWidget {
  final CallService service;
  final bool isConnected;

  const _CallControls({required this.service, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isConnected) ...[
          _RoundActionButton(
            icon: service.micEnabled
                ? Icons.mic_rounded
                : Icons.mic_off_rounded,
            label: service.micEnabled ? l10n.callMute : l10n.callUnmute,
            color: service.micEnabled ? Colors.white24 : Colors.white,
            onPressed: () => service.toggleMute(),
          ),
          const SizedBox(width: 48),
          _RoundActionButton(
            icon: service.cameraEnabled
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            label: service.cameraEnabled
                ? l10n.callCameraOff
                : l10n.callCameraOn,
            color: service.cameraEnabled ? Colors.white24 : Colors.white,
            onPressed: () => service.toggleCamera(),
          ),
          const SizedBox(width: 72),
        ],
        _RoundActionButton(
          icon: Icons.call_end_rounded,
          label: l10n.callHangup,
          color: Colors.redAccent,
          onPressed: service.hangup,
        ),
      ],
    );
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 22)),
        const SizedBox(height: 12),
        Text(text, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close_rounded),
          label: Text(l10n.callClose),
        ),
      ],
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