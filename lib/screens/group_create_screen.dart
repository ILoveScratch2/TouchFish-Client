import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
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
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      final gid = await TfApiClient.instance.createGroup(
        _uid, _password,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('创建失败，请检查群组数量限制'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      talker.error('GroupCreate failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
    if (mounted) setState(() => _isCreating = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('创建群组'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '群组名称', prefixIcon: Icon(Icons.group),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _introCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '群组简介', prefixIcon: Icon(Icons.info_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hintCtrl,
            decoration: const InputDecoration(
              labelText: '入群提示', prefixIcon: Icon(Icons.login),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            value: _allowDirectJoin,
            title: const Text('允许直接加入'),
            subtitle: const Text('非群成员可以自行申请加入'),
            onChanged: (v) => setState(() => _allowDirectJoin = v),
          ),
          SwitchListTile.adaptive(
            value: _requireReview,
            title: const Text('需要审核'),
            subtitle: const Text('加入或邀请需群主审核'),
            onChanged: (v) => setState(() => _requireReview = v),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isCreating ? null : _create,
            icon: _isCreating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add),
            label: const Text('创建群组'),
          ),
        ],
      ),
    );
  }
}
