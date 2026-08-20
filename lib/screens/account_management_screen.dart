import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/snackbar_service.dart';
import '../utils/talker.dart';
import '../widgets/app_alert_dialog.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  List<UserProfile> _users = const [];
  UserManagePagination? _pagination;
  bool _isLoading = true;
  bool _isCreating = false;
  String? _error;
  String _query = '';
  int _currentPage = 1;
  static const _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers({int page = 1}) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;

    if (uid == null || password == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'unauthorized';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await TfApiClient.instance.manageListUsers(
        uid,
        password,
        page: page,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _users = result?.users ?? [];
        _pagination = result?.pagination;
        _currentPage = page;
        _isLoading = false;
      });
    } catch (e) {
      talker.error('AccountManagementScreen: manageListUsers failed', e);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _changeUserStat(UserProfile user, String newStat) async {
    final l10n = AppLocalizations.of(context)!;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final targetUid = int.tryParse(user.uid);
    if (targetUid == null) return;

    try {
      final success = await TfApiClient.instance.manageChangeAuth(
        uid,
        password,
        targetUid,
        newStat,
      );
      if (!mounted) return;

      if (success) {
        TouchFishSnackbarService.instance.show(
          l10n.adminAccountRoleChangeSuccess(
            user.username,
            _statDisplayName(l10n, newStat),
          ),
        );
        await _loadUsers(page: _currentPage);
      } else {
        TouchFishSnackbarService.instance.show(
          _roleChangeFailedMessage(l10n),
        );
      }
    } catch (e) {
      talker.error('AccountManagementScreen: changeUserStat failed', e);
      if (!mounted) return;
      TouchFishSnackbarService.instance.show(
        _roleChangeFailedMessage(l10n),
      );
    }
  }

  Future<void> _banUser(UserProfile user) async {
    final l10n = AppLocalizations.of(context)!;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final targetUid = int.tryParse(user.uid);
    if (targetUid == null) return;

    final isBanned = user.normalizedStat == 'banned';

    final confirmed = await showTouchFishErrorDialog<bool>(
      context,
      title: isBanned ? l10n.adminAccountUnbanTitle : l10n.adminAccountBanTitle,
      message: isBanned
          ? l10n.adminAccountUnbanConfirm(user.username)
          : l10n.adminAccountBanConfirm(user.username),
      icon: isBanned ? Icons.lock_open_outlined : Icons.block_outlined,
      selectableMessage: false,
      actions: [
        TouchFishDialogAction<bool>(label: l10n.cancel, result: false),
        TouchFishDialogAction<bool>(
          label: isBanned
              ? l10n.adminAccountUnbanAction
              : l10n.adminAccountBanAction,
          result: true,
          isPrimary: true,
          isDestructive: !isBanned,
        ),
      ],
    );

    if (confirmed != true || !mounted) return;

    try {
      final success = isBanned
          ? await TfApiClient.instance.manageChangeAuth(
              uid,
              password,
              targetUid,
              'user',
            )
          : await TfApiClient.instance.manageBanUser(uid, password, targetUid);
      if (!mounted) return;

      if (success) {
        TouchFishSnackbarService.instance.show(
          isBanned
              ? l10n.adminAccountUnbanSuccess(user.username)
              : l10n.adminAccountBanSuccess(user.username),
        );
        await _loadUsers(page: _currentPage);
      } else {
        TouchFishSnackbarService.instance.show(
          isBanned
              ? l10n.adminAccountUnbanFailed
              : l10n.adminAccountBanFailed,
        );
      }
    } catch (e) {
      talker.error('AccountManagementScreen: banUser failed', e);
      if (!mounted) return;
      TouchFishSnackbarService.instance.show(
        isBanned
            ? l10n.adminAccountUnbanFailed
            : l10n.adminAccountBanFailed,
      );
    }
  }

  Future<void> _deleteUser(UserProfile user) async {
    final l10n = AppLocalizations.of(context)!;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final targetUid = int.tryParse(user.uid);
    if (targetUid == null) return;

    final confirmed = await showTouchFishErrorDialog<bool>(
      context,
      title: l10n.adminAccountDeleteTitle,
      message: l10n.adminAccountDeleteConfirm(user.username),
      icon: Icons.delete_forever_outlined,
      selectableMessage: false,
      actions: [
        TouchFishDialogAction<bool>(label: l10n.cancel, result: false),
        TouchFishDialogAction<bool>(
          label: l10n.adminAccountDeleteAction,
          result: true,
          isPrimary: true,
          isDestructive: true,
        ),
      ],
    );

    if (confirmed != true || !mounted) return;

    try {
      final success = await TfApiClient.instance.manageDeleteUser(
        uid,
        password,
        targetUid,
      );
      if (!mounted) return;

      if (success) {
        TouchFishSnackbarService.instance.show(
          l10n.adminAccountDeleteSuccess(user.username),
        );
        await _loadUsers(page: _currentPage);
      } else {
        TouchFishSnackbarService.instance.show(
          l10n.adminAccountDeleteFailed,
        );
      }
    } catch (e) {
      talker.error('AccountManagementScreen: deleteUser failed', e);
      if (!mounted) return;
      TouchFishSnackbarService.instance.show(
        l10n.adminAccountDeleteFailed,
      );
    }
  }

  void _showRoleChangeDialog(UserProfile user) {
    final l10n = AppLocalizations.of(context)!;
    final currentStat = user.normalizedStat;
    final availableRoles = AuthState.instance.currentUser?.isRoot == true
        ? const ['user', 'admin', 'root', 'banned']
        : const ['user', 'banned'];

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.adminAccountChangeRoleTitle(user.username),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...availableRoles.map(
              (role) => ListTile(
                leading: Icon(
                  role == currentStat
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: role == currentStat
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(_statDisplayName(l10n, role)),
                subtitle: role == currentStat
                    ? Text(l10n.adminAccountCurrentRole)
                    : null,
                onTap: role == currentStat
                    ? null
                    : () {
                        Navigator.pop(context);
                        _changeUserStat(user, role);
                      },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _statDisplayName(AppLocalizations l10n, String stat) {
    switch (stat) {
      case 'root':
        return l10n.adminAccountRoleRoot;
      case 'admin':
        return l10n.adminAccountRoleAdmin;
      case 'banned':
        return l10n.adminAccountRoleBanned;
      default:
        return l10n.adminAccountRoleUser;
    }
  }

  String _roleChangeFailedMessage(AppLocalizations l10n) {
    return l10n.adminAccountRoleChangeFailed;
  }

  Color _statColor(String stat, ColorScheme cs) {
    switch (stat) {
      case 'root':
        return cs.error;
      case 'admin':
        return cs.primary;
      case 'banned':
        return cs.outline;
      default:
        return cs.secondary;
    }
  }

  String _formatCreateTime(String timestamp) {
    final ms = int.tryParse(timestamp);
    if (ms == null) return timestamp;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _showCreateAccountDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final emailController = TextEditingController();
    final signController = TextEditingController();
    final introductionController = TextEditingController();
    var role = 'user';
    var obscurePassword = true;
    final roles = AuthState.instance.currentUser?.isRoot == true
        ? const ['user', 'admin', 'root', 'banned']
        : const ['user', 'banned'];

    final data = await showDialog<_CreateAccountData>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.person_add_alt_1_outlined),
          title: Text(l10n.adminAccountCreate),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.adminAccountCreateDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: usernameController,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.adminAccountUsername,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? l10n.adminAccountRequired
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.adminAccountPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: l10n.adminAccountPassword,
                          onPressed: () => setDialogState(
                            () => obscurePassword = !obscurePassword,
                          ),
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? l10n.adminAccountRequired
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.adminAccountConfirmPassword,
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                      ),
                      validator: (value) => value != passwordController.text
                          ? l10n.adminAccountPasswordMismatch
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: InputDecoration(
                        labelText: l10n.adminAccountRole,
                        prefixIcon: const Icon(
                          Icons.admin_panel_settings_outlined,
                        ),
                      ),
                      items: roles
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_statDisplayName(l10n, value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) role = value;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.adminAccountEmail,
                        prefixIcon: const Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: signController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.adminAccountSign,
                        prefixIcon: const Icon(Icons.short_text),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: introductionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: l10n.adminAccountIntroduction,
                        prefixIcon: const Icon(Icons.notes_outlined),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton.icon(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(
                  dialogContext,
                  _CreateAccountData(
                    username: usernameController.text.trim(),
                    password: passwordController.text,
                    role: role,
                    email: emailController.text.trim(),
                    sign: signController.text.trim(),
                    introduction: introductionController.text.trim(),
                  ),
                );
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(l10n.adminAccountCreate),
            ),
          ],
        ),
      ),
    );

    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    emailController.dispose();
    signController.dispose();
    introductionController.dispose();
    if (data == null || !mounted) return;

    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    setState(() => _isCreating = true);
    try {
      final success = await TfApiClient.instance.manageCreateUser(
        uid,
        password,
        username: data.username,
        targetPassword: data.password,
        role: data.role,
        email: data.email,
        sign: data.sign,
        introduction: data.introduction,
      );
      if (!mounted) return;
      TouchFishSnackbarService.instance.show(
        success
            ? l10n.adminAccountCreateSuccess
            : l10n.adminAccountCreateFailed,
      );
      if (success) await _loadUsers(page: 1);
    } catch (e) {
      talker.error('AccountManagementScreen: create user failed', e);
      if (mounted) {
        TouchFishSnackbarService.instance.show(
          l10n.adminAccountCreateFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Widget _buildToolbar(AppLocalizations l10n) {
    final total = _pagination?.total ?? _users.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Row(
            children: [
              Expanded(
                child: SearchBar(
                  hintText: l10n.adminAccountSearch,
                  leading: const Icon(Icons.search),
                  constraints: const BoxConstraints(minHeight: 46),
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$total ${l10n.adminAccountTotalUsers}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _isCreating ? null : _showCreateAccountDialog,
                icon: _isCreating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1, size: 18),
                label: Text(l10n.adminAccountCreate),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(UserProfile user, AppLocalizations l10n) {
    final stat = user.normalizedStat;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Material(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: user.avatar == null
                      ? null
                      : NetworkImage(user.avatar!),
                  child: user.avatar == null
                      ? Text(user.username.characters.first.toUpperCase())
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'UID ${user.uid}  ${user.email.isEmpty ? '' : '· ${user.email}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (MediaQuery.sizeOf(context).width >= 620) ...[
                  Expanded(
                    child: Text(
                      l10n.adminAccountCreated(
                        _formatCreateTime(user.createTime),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statColor(stat, scheme).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _statDisplayName(l10n, stat),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _statColor(stat, scheme),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
                  onSelected: (value) {
                    switch (value) {
                      case 'role':
                        _showRoleChangeDialog(user);
                      case 'ban':
                        _banUser(user);
                      case 'delete':
                        _deleteUser(user);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'role',
                      child: ListTile(
                        leading: const Icon(Icons.manage_accounts_outlined),
                        title: Text(l10n.adminAccountChangeRole),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'ban',
                      child: ListTile(
                        leading: Icon(
                          stat == 'banned'
                              ? Icons.lock_open_outlined
                              : Icons.block_outlined,
                        ),
                        title: Text(
                          stat == 'banned'
                              ? l10n.adminAccountUnbanAction
                              : l10n.adminAccountBanAction,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(
                          Icons.delete_outline,
                          color: scheme.error,
                        ),
                        title: Text(
                          l10n.adminAccountDeleteAction,
                          style: TextStyle(color: scheme.error),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasAdminAccess =
        AuthState.instance.currentUser?.hasAdminAccess == true;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.adminAccountManagement),
            Text(
              l10n.adminAccountManagementDescription,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: !hasAdminAccess
          ? Center(child: Text(l10n.adminAccessDenied))
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.adminAccountLoadFailed),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _loadUsers(page: _currentPage),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                _buildToolbar(l10n),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final query = _query.toLowerCase();
                      final visibleUsers = query.isEmpty
                          ? _users
                          : _users
                                .where(
                                  (user) =>
                                      user.username.toLowerCase().contains(
                                        query,
                                      ) ||
                                      user.email.toLowerCase().contains(
                                        query,
                                      ) ||
                                      user.uid.contains(query),
                                )
                                .toList();
                      return RefreshIndicator(
                        onRefresh: () => _loadUsers(page: _currentPage),
                        child: visibleUsers.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height:
                                        MediaQuery.of(context).size.height *
                                        0.2,
                                  ),
                                  Icon(
                                    Icons.people_outline,
                                    size: 56,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: Text(
                                      l10n.adminAccountEmpty,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: visibleUsers.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  return _buildUserCard(
                                    visibleUsers[index],
                                    l10n,
                                  );
                                },
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _pagination != null && _pagination!.totalPages > 1
          ? _buildPaginationBar(l10n)
          : null,
    );
  }

  Widget _buildPaginationBar(AppLocalizations l10n) {
    final p = _pagination!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _currentPage > 1
                  ? () => _loadUsers(page: _currentPage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${p.page} / ${p.totalPages}  (${p.total} ${l10n.adminAccountTotalUsers})',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            IconButton(
              onPressed: p.hasMore
                  ? () => _loadUsers(page: _currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateAccountData {
  final String username;
  final String password;
  final String role;
  final String email;
  final String sign;
  final String introduction;

  const _CreateAccountData({
    required this.username,
    required this.password,
    required this.role,
    required this.email,
    required this.sign,
    required this.introduction,
  });
}
