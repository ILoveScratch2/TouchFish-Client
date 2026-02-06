import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import '../models/user_profile_model.dart';
import '../l10n/app_localizations.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    // 模拟网慢了点
    await Future.delayed(const Duration(milliseconds: 300));

    final profile = UserProfileDemoData.getUserProfile(widget.userId);

    setState(() {
      _profile = profile ??
          UserProfileDemoData.createDefaultProfile(
            widget.userId,
            'user_${widget.userId}',
          );
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_profile?.displayName ?? l10n.profileTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showMoreOptions(context);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? Center(child: Text(l10n.profileNotFound))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProfileHeader(context, _profile!),
                      const SizedBox(height: 16),
                      _buildBioCard(context, _profile!),
                      const SizedBox(height: 16),
                      _buildDetailsCard(context, _profile!),
                      const SizedBox(height: 16),
                      _buildBadgesCard(context, _profile!),
                      const SizedBox(height: 16),
                      _buildActionsCard(context, _profile!),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserProfile profile) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: colorScheme.primaryContainer,
                  child: profile.avatar != null
                      ? null
                      : Icon(
                          Icons.person,
                          size: 50,
                          color: colorScheme.onPrimaryContainer,
                        ),
                ),
                if (profile.status != null)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(context, profile.status),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        _getStatusIcon(profile.status),
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Display Name
            Text(
              profile.displayName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),

            // Username
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: profile.username));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.profileUsernameCopied),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '@${profile.username}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                        ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.copy,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ),

            // Status
            if (profile.status != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(context, profile.status)
                    .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _getStatusColor(context, profile.status),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getStatusIcon(profile.status),
                      size: 16,
                      color: _getStatusColor(context, profile.status),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      profile.status!,
                      style: TextStyle(
                        color: _getStatusColor(context, profile.status),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBioCard(BuildContext context, UserProfile profile) {
    final l10n = AppLocalizations.of(context)!;

    if (profile.bio == null || profile.bio!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileBio,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            SmoothMarkdown(
              data: profile.bio!,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
              useEnhancedComponents: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context, UserProfile profile) {
    final l10n = AppLocalizations.of(context)!;
    final details = <Widget>[];

    // Email
    if (profile.email != null) {
      details.add(_buildDetailItem(
        context,
        Icons.email_outlined,
        l10n.profileEmail,
        profile.email!,
      ));
    }

    // Location
    if (profile.location != null) {
      details.add(_buildDetailItem(
        context,
        Icons.location_on_outlined,
        l10n.profileLocation,
        profile.location!,
      ));
    }

    // Birthday & Age
    if (profile.birthday != null) {
      final dateFormat = DateFormat('yyyy-MM-dd');
      final birthdayStr = dateFormat.format(profile.birthday!);
      final age = profile.age;
      final ageStr = age != null ? ' (${l10n.profileAge(age)})' : '';

      details.add(_buildDetailItem(
        context,
        Icons.cake_outlined,
        l10n.profileBirthday,
        birthdayStr + ageStr,
      ));
    }

    // Joined At
    final joinedFormat = DateFormat('yyyy-MM-dd');
    details.add(_buildDetailItem(
      context,
      Icons.event_outlined,
      l10n.profileJoinedAt,
      joinedFormat.format(profile.joinedAt),
    ));

    if (details.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileDetails,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...details,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: colorScheme.primary,
          ),
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
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesCard(BuildContext context, UserProfile profile) {
    final l10n = AppLocalizations.of(context)!;

    if (profile.badges == null || profile.badges!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileBadges,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.badges!.map((badge) {
                return _buildBadgeChip(context, badge);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeChip(BuildContext context, String badge) {
    final colorScheme = Theme.of(context).colorScheme;

    return Chip(
      avatar: Icon(
        Icons.military_tech,
        size: 16,
        color: colorScheme.primary,
      ),
      label: Text(badge),
      backgroundColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: colorScheme.onPrimaryContainer,
        fontWeight: FontWeight.w500,
      ),
      side: BorderSide.none,
    );
  }

  Widget _buildActionsCard(BuildContext context, UserProfile profile) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.message_outlined),
            title: Text(l10n.profileSendMessage),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Close the profile screen first, then navigate to chat
              Navigator.of(context).pop();
              context.go('/chat/${profile.id}');
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.person_add_outlined),
            title: Text(l10n.profileAddFriend),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // 没有加好友
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.profileFeatureNotImplemented)),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.block_outlined),
                title: Text(l10n.profileBlock),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.profileFeatureNotImplemented)),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.report_outlined),
                title: Text(l10n.profileReport),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.profileFeatureNotImplemented)),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(BuildContext context, String? status) {
    final colorScheme = Theme.of(context).colorScheme;

    if (status == null) return colorScheme.onSurfaceVariant;

    switch (status) {
      case '在线':
        return Colors.green;
      case 'Online':
        return Colors.green;
      case '离开':
        return Colors.orange;
      case 'Away':
        return Colors.orange;
      case '离线':
        return colorScheme.onSurfaceVariant;
      case 'Offline':
        return colorScheme.onSurfaceVariant;
      case '很忙':
        return Colors.yellow;
      case 'Busy':
        return Colors.yellow;
      case '开发中':
        return Colors.red;
      case 'Developing':
        return Colors.red;
      default:
        return colorScheme.primary;
    }
  }

  IconData _getStatusIcon(String? status) {
    if (status == null) return Icons.circle;

    switch (status) {
      case '在线':
      case 'Online':
        return Icons.circle;
      case '离开':
      case 'Away':
        return Icons.schedule;
      case '离线':
      case 'Offline':
        return Icons.circle_outlined;
      case '很忙':
      case 'Busy':
        return Icons.do_not_disturb;
      case '开发中':
      case 'Developing':
        return Icons.code;
      default:
        return Icons.circle;
    }
  }
}
