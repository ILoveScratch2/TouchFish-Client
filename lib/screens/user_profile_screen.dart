import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../widgets/markdown_renderer.dart';
import '../models/settings_service.dart';
import '../widgets/account/profile_picture.dart';
import '../services/api/tf_api_client.dart';
import '../utils/talker.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final uid = int.tryParse(widget.userId);
      if (uid == null) throw Exception('Invalid userId');
      final profile = await TfApiClient.instance.getUserByUid(uid);
      if (mounted) setState(() { _profile = profile; _isLoading = false; });
    } catch (e) {
      talker.error('UserProfileScreen: _loadProfile failed', e);
      if (mounted) setState(() { _isLoading = false; _error = e.toString(); });
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l10n.userProfileNotFound),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadProfile, child: Text(l10n.retry)),
          ]),
        ),
      );
    }
    final profile = _profile!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with background
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Symbols.share),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Share ${profile.username}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
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

          // Content
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kProfileMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Avatar + name header
                      _buildProfileHeader(context, profile, l10n, colorScheme),

                      // Action buttons
                      _buildActionButtons(context, profile, l10n),
                      const SizedBox(height: 16),

                      // Personal sign
                      if (profile.personalSign != null && profile.personalSign!.isNotEmpty) ...[
                        _buildBioCard(context, profile, l10n, colorScheme),
                        const SizedBox(height: 16),
                      ],

                      // Details card
                      _buildDetailsCard(context, profile, l10n, colorScheme),
                      const SizedBox(height: 16),

                      // Introduction
                      if (profile.introduction != null && profile.introduction!.isNotEmpty) ...[
                        _buildIntroductionCard(context, profile, l10n, colorScheme),
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
            border: Border.all(
              color: colorScheme.surface,
              width: 4,
            ),
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
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '@${profile.username}',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Bio
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
                Clipboard.setData(ClipboardData(text: profile.uid));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.userProfileUidCopied),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              Symbols.email,
              l10n.userProfileEmail,
              profile.email.isEmpty ? l10n.userProfileUnknownEmail : profile.email,
              onTap: profile.email.isEmpty ? null : () {
                Clipboard.setData(ClipboardData(text: profile.email));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${l10n.userProfileEmail} ${l10n.userProfileUidCopied}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
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
    final enableMarkdown = settingsService.getValue<bool>('enableMarkdownRendering', true);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.userProfileIntroduction,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: 实现添加好友功能
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${l10n.userProfileAddFriend}: ${profile.username}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Symbols.person_add),
            label: Text(l10n.userProfileAddFriend),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              // 跳转到聊天页面
              context.go('/chat/${profile.uid}');
            },
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
