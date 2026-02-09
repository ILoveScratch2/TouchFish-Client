import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';

class UserProfileScreen extends StatelessWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // 使用 demo 数据
    final profile = UserProfileDemoData.getDemoProfile(userId);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with back button
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar and basic info
                  _buildBasicInfo(context, profile, l10n, colorScheme),
                  const SizedBox(height: 16),
                  
                  // Personal sign
                  if (profile.personalSign != null)
                    _buildPersonalSign(context, profile, l10n, colorScheme),
                  
                  // Details card
                  _buildDetailsCard(context, profile, l10n, colorScheme),
                  const SizedBox(height: 16),
                  
                  // Introduction
                  if (profile.introduction != null)
                    _buildIntroduction(context, profile, l10n, colorScheme),
                  
                  const SizedBox(height: 16),
                  
                  // Action buttons
                  _buildActionButtons(context, profile, l10n),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo(
    BuildContext context,
    UserProfile profile,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 40,
              backgroundColor: colorScheme.primaryContainer,
              child: profile.avatar != null
                  ? null
                  : Icon(
                      Icons.person,
                      size: 48,
                      color: colorScheme.onPrimaryContainer,
                    ),
            ),
            const SizedBox(width: 16),
            
            // Name and stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.username,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildPermissionBadge(context, profile, l10n, colorScheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionBadge(
    BuildContext context,
    UserProfile profile,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    String permissionText;
    Color badgeColor;
    
    switch (profile.stat.toLowerCase()) {
      case 'admin':
        permissionText = l10n.userProfilePermissionAdmin;
        badgeColor = Colors.red;
        break;
      case 'moderator':
        permissionText = l10n.userProfilePermissionModerator;
        badgeColor = Colors.orange;
        break;
      default:
        permissionText = l10n.userProfilePermissionUser;
        badgeColor = colorScheme.primary;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Text(
        permissionText,
        style: TextStyle(
          color: badgeColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPersonalSign(
    BuildContext context,
    UserProfile profile,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '“${profile.personalSign!}”',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontStyle: FontStyle.italic,
            color: colorScheme.onSurfaceVariant,
          ),
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
              Icons.fingerprint,
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
              Icons.email_outlined,
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
              Icons.event_outlined,
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null)
          Icon(
            Icons.copy,
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

  Widget _buildIntroduction(
    BuildContext context,
    UserProfile profile,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
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
            MarkdownBody(
              data: profile.introduction!,
              styleSheet: MarkdownStyleSheet(
                p: Theme.of(context).textTheme.bodyMedium,
                h1: Theme.of(context).textTheme.headlineSmall,
                h2: Theme.of(context).textTheme.titleLarge,
                h3: Theme.of(context).textTheme.titleMedium,
              ),
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
            icon: const Icon(Icons.person_add),
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
            icon: const Icon(Icons.send),
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
      final date = DateTime.fromMillisecondsSinceEpoch(
        int.parse(timestamp) * 1000,
      );
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }
}
