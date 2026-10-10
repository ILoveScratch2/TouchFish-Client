import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../widgets/markdown_renderer.dart';
import '../models/settings_service.dart';
import '../widgets/account/profile_picture.dart';
import '../services/api/tf_api_client.dart';
import '../routes/app_routes.dart';
import '../services/auth_state.dart';
import '../services/feature_flags.dart';
import '../services/snackbar_service.dart';
import '../utils/talker.dart';
import '../utils/clipboard_utils.dart';
import '../widgets/text_entry_dialog.dart';

const double _kProfileMaxWidth = 680;

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserProfile? _profile;
  bool _isLoading = true;
  String? _error;
  bool _isAddingFriend = false;
  bool? _isFriend;
  // null = 未知：服务端未提供拉黑状态查询接口，默认按"未拉黑"展示
  bool? _isBlocked;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final uid = int.tryParse(widget.userId);
      if (uid == null) throw Exception('Invalid userId');
      final profile = await TfApiClient.instance.getUserByUid(uid);
      bool? isFriend;
      final myUid = AuthState.instance.uid;
      final password = AuthState.instance.password;
      if (profile != null &&
          myUid != null &&
          password != null &&
          uid != myUid) {
        final friendUids = await TfApiClient.instance.getFriendList(
          myUid,
          password,
        );
        if (friendUids != null) isFriend = friendUids.contains(uid);
      }
      if (mounted) {
        setState(() {
          _profile = profile;
          _isFriend = isFriend;
          _isLoading = false;
        });
      }
    } catch (e) {
      talker.error('UserProfileScreen: _loadProfile failed', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _copyText(
    BuildContext context,
    String text,
    String successMessage,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final copied = await copyTextToClipboard(text);
    TouchFishSnackbarService.instance.show(
      copied ? successMessage : l10n.copyFailedText,
      type: copied ? SnackbarType.info : SnackbarType.error,
    );
  }

  Future<void> _addFriend(UserProfile target, AppLocalizations l10n) async {
    final myUid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (myUid == null || password == null) {
      TouchFishSnackbarService.instance.show(l10n.storageNotLoggedIn);
      return;
    }

    final targetUid = int.tryParse(target.uid);
    if (targetUid == null) return;

    // 可选申请留言（留空直接申请；重复申请会覆盖为最新留言）
    final message = await showDialog<String>(
      context: context,
      builder: (ctx) => TextEntryDialog(
        title: l10n.userProfileAddFriend,
        hintText: l10n.userProfileFriendRequestHint,
        cancelLabel: l10n.commonCancel,
        confirmLabel: l10n.userProfileAddFriend,
        icon: Icons.person_add_alt,
        maxLines: 3,
        allowEmpty: true,
      ),
    );
    if (message == null || !mounted) return;

    setState(() => _isAddingFriend = true);
    try {
      final ok = await TfApiClient.instance.addFriend(
        myUid,
        password,
        targetUid,
        message,
      );
      if (!mounted) return;
      final blocked =
          TfApiClient.instance.lastApiError?.code == 'FRIEND_BLOCKED';
      TouchFishSnackbarService.instance.show(
        ok
            ? l10n.userProfileFriendRequestSent(target.username)
            : blocked
            ? l10n.friendRequestBlocked
            : l10n.userProfileFriendRequestFailed,
      );
    } finally {
      if (mounted) setState(() => _isAddingFriend = false);
    }
  }

  Future<void> _blockUser(UserProfile profile, AppLocalizations l10n) async {
    final myUid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final targetUid = int.tryParse(profile.uid);
    if (myUid == null || password == null || targetUid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.friendBlock),
        content: Text(l10n.friendBlockConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.friendBlock),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await TfApiClient.instance.blockUser(
      myUid,
      password,
      targetUid,
    );
    if (!mounted) return;
    TouchFishSnackbarService.instance.show(
      ok ? l10n.friendBlock : l10n.commonFailedOperation,
    );
    if (ok) {
      setState(() {
        _isFriend = false;
        _isBlocked = true;
      });
    }
  }

  Future<void> _unblockUser(UserProfile profile, AppLocalizations l10n) async {
    final myUid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final targetUid = int.tryParse(profile.uid);
    if (myUid == null || password == null || targetUid == null) return;

    final ok = await TfApiClient.instance.unblockUser(
      myUid,
      password,
      targetUid,
    );
    if (!mounted) return;
    TouchFishSnackbarService.instance.show(
      ok ? l10n.friendUnblock : l10n.commonFailedOperation,
    );
    if (ok) {
      setState(() => _isBlocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _profile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.userProfileNotFound),
              const SizedBox(height: 8),
              TextButton(onPressed: _loadProfile, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }
    final profile = _profile!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.chat);
                }
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Symbols.share),
                onPressed: () {
                  TouchFishSnackbarService.instance.show('Share ${profile.username}');
                },
              ),
              if (AuthState.instance.uid?.toString() != profile.uid)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'block') {
                      _blockUser(profile, l10n);
                    } else if (value == 'unblock') {
                      _unblockUser(profile, l10n);
                    }
                  },
                  itemBuilder: (context) => [
                    if (_isBlocked == true)
                      PopupMenuItem(
                        value: 'unblock',
                        child: Text(l10n.friendUnblock),
                      )
                    else
                      PopupMenuItem(
                        value: 'block',
                        child: Text(l10n.friendBlock),
                      ),
                  ],
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.secondaryContainer,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kProfileMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProfileHeader(context, profile, l10n, colorScheme),
                      _buildActionButtons(context, profile, l10n),
                      const SizedBox(height: 16),
                      if (profile.personalSign != null &&
                          profile.personalSign!.isNotEmpty) ...[
                        _buildBioCard(context, profile, l10n, colorScheme),
                        const SizedBox(height: 16),
                      ],
                      _buildDetailsCard(context, profile, l10n, colorScheme),
                      const SizedBox(height: 16),
                      if (profile.introduction != null &&
                          profile.introduction!.isNotEmpty) ...[
                        _buildIntroductionCard(
                          context,
                          profile,
                          l10n,
                          colorScheme,
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    UserProfile profile,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.surface, width: 4),
          ),
          child: ProfilePictureWidget(
            avatarUrl: profile.avatar,
            radius: 72,
            fallbackText: profile.username,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          profile.username,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '@${profile.username}',
          style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBioCard(
    BuildContext context,
    UserProfile profile,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.userProfilePersonalSign,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '"${profile.personalSign!}"',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(
    BuildContext context,
    UserProfile profile,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              context,
              Symbols.fingerprint,
              l10n.userProfileUid,
              profile.uid,
              onTap: () {
                _copyText(context, profile.uid, l10n.userProfileUidCopied);
              },
            ),
            // 邮箱未公开（服务端裁剪为空）或未设置时不占位展示
            if (profile.email.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                Symbols.email,
                l10n.userProfileEmail,
                profile.email,
                onTap: () {
                  _copyText(
                    context,
                    profile.email,
                    '${l10n.userProfileEmail} ${l10n.userProfileUidCopied}',
                  );
                },
              ),
            ],
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              Symbols.event,
              l10n.userProfileJoinedAt,
              _formatTimestamp(profile.createTime),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null)
          Icon(
            Symbols.content_copy,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
      ],
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }
    return content;
  }

  Widget _buildIntroductionCard(
    BuildContext context,
    UserProfile profile,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final settingsService = SettingsService.instance;
    final enableMarkdown = settingsService.getValue<bool>(
      'enableMarkdownRendering',
      true,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.userProfileIntroduction,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            enableMarkdown
                ? MarkdownRenderer(
                    data: profile.introduction!,
                    selectable: true,
                  )
                : Text(
                    profile.introduction!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    UserProfile profile,
    AppLocalizations l10n,
  ) {
    final myUid = AuthState.instance.uid;
    final isSelf = myUid != null && myUid.toString() == profile.uid;
    if (isSelf || _isFriend == null) return const SizedBox.shrink();

    final flags = FeatureFlags.instance;
    return Row(
      children: [
        if (!_isFriend! && flags.friendRequest) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isAddingFriend
                  ? null
                  : () => _addFriend(profile, l10n),
              icon: _isAddingFriend
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Symbols.person_add),
              label: Text(l10n.userProfileAddFriend),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
        if (_isFriend! && flags.privateChat)
          Expanded(
            child: FilledButton.icon(
              onPressed: () => context.go('/chat/U${profile.uid}'),
              icon: const Icon(Symbols.send),
              label: Text(l10n.userProfileSendMessage),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
      ],
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final seconds = double.parse(timestamp);
      final date = DateTime.fromMillisecondsSinceEpoch(
        (seconds * 1000).round(),
      );
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
    } catch (e) {
      talker.error('Failed to parse timestamp: $timestamp', e);
      return timestamp;
    }
  }
}
