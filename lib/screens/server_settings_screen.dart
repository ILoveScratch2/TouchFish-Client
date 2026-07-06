import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../utils/talker.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  static const double _contentMaxWidth = 640;

  final _serverNameController = TextEditingController();
  final _fileLastTimeController = TextEditingController();
  final _groupsLimitController = TextEditingController();
  final _singleGroupMaxPeopleController = TextEditingController();
  final _maxFileSizeController = TextEditingController();
  final _maxMessageLengthController = TextEditingController();

  TfServerConfig? _settings;
  bool _captcha = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _serverNameController.dispose();
    _fileLastTimeController.dispose();
    _groupsLimitController.dispose();
    _singleGroupMaxPeopleController.dispose();
    _maxFileSizeController.dispose();
    _maxMessageLengthController.dispose();
    super.dispose();
  }

  bool get _canManageServer {
    return AuthState.instance.currentUser?.isRoot == true &&
        AuthState.instance.uid != null &&
        AuthState.instance.password != null;
  }

  void _applySettings(TfServerConfig settings) {
    _serverNameController.text = settings.serverName;
    _fileLastTimeController.text = (settings.fileLastTime ?? 0).toString();
    _groupsLimitController.text = (settings.groupsLimit ?? -1).toString();
    _singleGroupMaxPeopleController.text =
        (settings.singleGroupMaxPeople ?? -1).toString();
    _maxFileSizeController.text = (settings.maxFileSize ?? -1).toString();
    _maxMessageLengthController.text = (settings.maxMessageLength ?? 10000).toString();
    _captcha = settings.captcha;
  }

  Future<void> _loadSettings({bool showError = false}) async {
    if (!_canManageServer) {
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = null;
        _isLoading = false;
      });
      return;
    }

    final uid = AuthState.instance.uid!;
    final password = AuthState.instance.password!;

    setState(() => _isLoading = true);

    try {
      final settings = await TfApiClient.instance.queryServerSettings(
        uid,
        password,
      );

      if (!mounted) {
        return;
      }

      if (settings == null) {
        setState(() {
          _settings = null;
          _isLoading = false;
        });
        if (showError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.adminServerSettingsLoadFailed,
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      _applySettings(settings);
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      talker.error('ServerSettingsScreen._loadSettings failed', e, stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = null;
        _isLoading = false;
      });
      if (showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.adminServerSettingsLoadFailed,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  int? _parseIntegerField(
    String value, {
    required int minimum,
    bool allowUnlimited = false,
  }) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return null;
    }
    if (allowUnlimited && parsed == -1) {
      return parsed;
    }
    if (parsed < minimum) {
      return null;
    }
    return parsed;
  }

  Future<void> _saveSettings() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_canManageServer) {
      return;
    }

    final serverName = _serverNameController.text.trim();
    final fileLastTime = _parseIntegerField(
      _fileLastTimeController.text,
      minimum: 0,
    );
    final groupsLimit = _parseIntegerField(
      _groupsLimitController.text,
      minimum: 1,
      allowUnlimited: true,
    );
    final singleGroupMaxPeople = _parseIntegerField(
      _singleGroupMaxPeopleController.text,
      minimum: 1,
      allowUnlimited: true,
    );
    final maxFileSize = _parseIntegerField(
      _maxFileSizeController.text,
      minimum: 0,
      allowUnlimited: true,
    );
    final maxMessageLength = _parseIntegerField(
      _maxMessageLengthController.text,
      minimum: 1,
    );

    if (serverName.isEmpty ||
        fileLastTime == null ||
        groupsLimit == null ||
        singleGroupMaxPeople == null ||
        maxFileSize == null ||
        maxMessageLength == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.adminServerSettingsInvalidInput),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = await TfApiClient.instance.updateServerSettings(
        AuthState.instance.uid!,
        AuthState.instance.password!,
        serverName: serverName,
        captcha: _captcha,
        fileLastTime: fileLastTime,
        groupsLimit: groupsLimit,
        singleGroupMaxPeople: singleGroupMaxPeople,
        maxFileSize: maxFileSize,
        maxMessageLength: maxMessageLength,
      );

      if (!mounted) {
        return;
      }

      if (updated == null) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.adminServerSettingsSaveFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      _applySettings(updated);
      setState(() {
        _settings = updated;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.adminServerSettingsSaveSuccess),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, stackTrace) {
      talker.error('ServerSettingsScreen._saveSettings failed', e, stackTrace);
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.adminServerSettingsSaveFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatBool(BuildContext context, bool value) {
    return value ? 'true' : 'false';
  }

  Widget _buildFormCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.adminServerSettings,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.adminServerSettingsDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _serverNameController,
              decoration: InputDecoration(
                labelText: l10n.adminServerFieldServerName,
                prefixIcon: const Icon(Icons.dns_outlined),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _captcha,
              title: Text(l10n.adminServerFieldCaptcha),
              subtitle: Text(l10n.adminServerSettingsCaptchaDescription),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() => _captcha = value);
                    },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _fileLastTimeController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: InputDecoration(
                labelText: l10n.adminServerFieldFileLastTime,
                helperText: l10n.adminServerFileLastTimeDescription,
                prefixIcon: const Icon(Icons.schedule_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _groupsLimitController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: InputDecoration(
                labelText: l10n.adminServerFieldGroupsLimit,
                helperText: l10n.adminServerUnlimitedHint,
                prefixIcon: const Icon(Icons.groups_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _singleGroupMaxPeopleController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: InputDecoration(
                labelText: l10n.adminServerFieldSingleGroupMaxPeople,
                helperText: l10n.adminServerUnlimitedHint,
                prefixIcon: const Icon(Icons.group_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _maxFileSizeController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: InputDecoration(
                labelText: l10n.adminServerFieldMaxFileSize,
                helperText: l10n.adminServerUnlimitedHint,
                prefixIcon: const Icon(Icons.folder_open_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _maxMessageLengthController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: InputDecoration(
                labelText: l10n.adminServerFieldMaxMessageLength,
                helperText: l10n.adminServerFieldMaxMessageLengthDescription,
                prefixIcon: const Icon(Icons.message_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
    );
  }

  Widget _buildReadOnlyInfoCard(BuildContext context, AppLocalizations l10n) {
    final settings = _settings;
    if (settings == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.adminTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.adminServerReadOnlyDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoTile(
              context,
              icon: Icons.api_outlined,
              title: l10n.adminServerFieldApiPort,
              value: settings.portApi.toString(),
            ),
            _buildInfoTile(
              context,
              icon: Icons.settings_ethernet_outlined,
              title: l10n.adminServerFieldTcpPort,
              value: settings.portTcp.toString(),
            ),
            _buildInfoTile(
              context,
              icon: Icons.mark_email_unread_outlined,
              title: l10n.adminServerFieldEmailActivation,
              value: _formatBool(context, settings.emailActivate),
            ),
            _buildInfoTile(
              context,
              icon: Icons.alternate_email_outlined,
              title: l10n.adminServerFieldVerifyEmail,
              value: settings.verifyEmail?.trim().isNotEmpty == true
                  ? settings.verifyEmail!
                  : '-',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (!_canManageServer) {
      return Center(child: Text(l10n.adminRootOnly));
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_settings == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.adminServerSettingsLoadFailed),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _loadSettings(showError: true),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFormCard(context, l10n),
              const SizedBox(height: 16),
              _buildReadOnlyInfoCard(context, l10n),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isLoading || _isSaving ? null : _saveSettings,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(l10n.save),
              ),
              SizedBox(
                height: MediaQuery.of(context).padding.bottom + 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminServerSettings),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : () => _loadSettings(showError: true),
            tooltip: l10n.retry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }
}