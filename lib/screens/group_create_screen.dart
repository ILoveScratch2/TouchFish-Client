import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/snackbar_service.dart';
import '../utils/talker.dart';

class GroupCreateScreen extends StatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  State<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  final _nameCtrl = TextEditingController();
  final _introCtrl = TextEditingController();
  final _hintCtrl = TextEditingController();
  bool _allowDirectJoin = false;
  bool _requireReview = true;
  bool _isCreating = false;

  int get _uid => AuthState.instance.uid ?? 0;
  String get _password => AuthState.instance.password ?? '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _introCtrl.dispose();
    _hintCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        TouchFishSnackbarService.instance.show(l10n.groupCreateNameEmpty);
      }
      return;
    }
    final config = await TfApiClient.instance.fetchServerInfo();
    if (config != null) {
      final minLen = config.minGroupNameLength;
      final maxLen = config.maxGroupNameLength;
      if (name.length < minLen || name.length > maxLen) {
        if (mounted) {
          TouchFishSnackbarService.instance.show(l10n.groupCreateNameLength(minLen, maxLen));
        }
        return;
      }
    }

    setState(() => _isCreating = true);
    try {
      final gid = await TfApiClient.instance.createGroup(
        _uid,
        _password,
        groupname: name,
        introduction: _introCtrl.text.trim(),
        enterHint: _hintCtrl.text.trim(),
        allowDirectJoin: _allowDirectJoin,
        requireReview: _requireReview,
      );
      if (gid != null && gid > 0 && mounted) {
        context.pop(true);
        return;
      }
      if (mounted) {
        TouchFishSnackbarService.instance.show(l10n.groupCreateFailedLimit);
      }
    } catch (e) {
      talker.error('GroupCreate failed', e);
      if (mounted) {
        TouchFishSnackbarService.instance.show('${l10n.commonFailedOperation}: $e');
      }
    }
    if (mounted) setState(() => _isCreating = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatCreateGroup),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: l10n.groupNameLabel,
              prefixIcon: const Icon(Icons.group),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _introCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.groupIntroLabel,
              prefixIcon: const Icon(Icons.info_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hintCtrl,
            decoration: InputDecoration(
              labelText: l10n.groupEnterHintLabel,
              prefixIcon: const Icon(Icons.login),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            value: _allowDirectJoin,
            title: Text(l10n.groupAllowDirectJoin),
            subtitle: Text(l10n.groupAllowDirectJoinDesc),
            onChanged: (v) => setState(() => _allowDirectJoin = v),
          ),
          SwitchListTile.adaptive(
            value: _requireReview,
            title: Text(l10n.groupRequireReview),
            subtitle: Text(l10n.groupRequireReviewDesc),
            onChanged: (v) => setState(() => _requireReview = v),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isCreating ? null : _create,
            icon: _isCreating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: Text(l10n.chatCreateGroup),
          ),
        ],
      ),
    );
  }
}
