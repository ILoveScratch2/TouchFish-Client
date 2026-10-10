import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/friend_request.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/chat_data_service.dart';
import '../services/snackbar_service.dart';
import '../utils/talker.dart';

/// 待处理好友申请列表（服务端 /friend/requests，含申请留言）。
///
/// 不依赖通知（通知处理完即删），是申请的持久视图。
class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  bool _isLoading = true;
  List<FriendRequestEntry> _requests = const [];
  final Set<int> _processing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (mounted) setState(() => _isLoading = true);
    final requests = await TfApiClient.instance.queryFriendRequests(
      uid,
      password,
    );
    if (!mounted) return;
    setState(() {
      _requests = requests;
      _isLoading = false;
    });
  }

  Future<void> _handle(FriendRequestEntry entry, bool accept) async {
    final l10n = AppLocalizations.of(context)!;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null || _processing.contains(entry.uid)) {
      return;
    }
    setState(() => _processing.add(entry.uid));
    try {
      final ok = await TfApiClient.instance.dealFriendShip(
        uid,
        password,
        entry.uid,
        accept ? 'allow' : 'reject',
      );
      if (!mounted) return;
      if (ok) {
        setState(() => _requests =
            _requests.where((e) => e.uid != entry.uid).toList());
        if (accept) {
          ChatDataService.instance.addFriendToContacts(entry.uid);
          unawaited(ChatDataService.instance.loadContactsAndRooms());
        }
        TouchFishSnackbarService.instance.show(
          accept ? l10n.chatInviteAccept : l10n.chatInviteReject,
        );
      } else {
        TouchFishSnackbarService.instance.show(l10n.commonFailedOperation);
      }
    } catch (e) {
      talker.error('FriendRequests handle failed', e);
      if (mounted) {
        TouchFishSnackbarService.instance.show(l10n.commonFailedOperation);
      }
    } finally {
      if (mounted) setState(() => _processing.remove(entry.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.friendRequestsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.retry,
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? _buildEmpty(l10n)
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _requests.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _buildTile(l10n, _requests[index]),
            ),
    );
  }

  Widget _buildEmpty(AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_add_alt,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.friendRequestEmpty,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(AppLocalizations l10n, FriendRequestEntry entry) {
    final theme = Theme.of(context);
    final busy = _processing.contains(entry.uid);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          Icons.person_add_outlined,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(entry.username),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.sign.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              entry.sign,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (entry.message.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(entry.message),
          ],
          if (entry.requestAt > 0) ...[
            const SizedBox(height: 4),
            Text(
              _formatTime(entry.requestAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      trailing: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: theme.colorScheme.error),
                  tooltip: l10n.chatInviteReject,
                  onPressed: () => _handle(entry, false),
                ),
                IconButton.filled(
                  icon: const Icon(Icons.check),
                  tooltip: l10n.chatInviteAccept,
                  onPressed: () => _handle(entry, true),
                ),
              ],
            ),
    );
  }

  static String _formatTime(double timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch((timestamp * 1000).round());
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
