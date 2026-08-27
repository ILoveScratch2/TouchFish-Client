import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../services/api/tf_api_client.dart';
import '../services/api/tf_crypto.dart';
import '../services/rsa_key_trust_service.dart';
import '../services/snackbar_service.dart';
import '../widgets/app_alert_dialog.dart';
import '../widgets/code_block.dart';
import '../utils/talker.dart';

/// 保护 wyf 数据安全，从 rsa_key_management 做起
class RsaKeyManagementScreen extends StatefulWidget {
  const RsaKeyManagementScreen({super.key});

  @override
  State<RsaKeyManagementScreen> createState() => _RsaKeyManagementScreenState();
}

class _RsaKeyManagementScreenState extends State<RsaKeyManagementScreen> {
  static const double _contentMaxWidth = 640;

  Map<String, String> _savedKeys = {};
  String? _currentAuthority;
  bool _loading = true;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    RsaKeyTrustService.instance.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    RsaKeyTrustService.instance.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final saved = await RsaKeyTrustService.instance.savedKeys();
    String? authority;
    try {
      authority = await RsaKeyTrustService.currentAuthority();
    } catch (e, stackTrace) {
      talker.warning('RsaKeyManagementScreen failed to resolve authority', e, stackTrace);
    }
    if (!mounted) return;
    setState(() {
      _savedKeys = saved;
      _currentAuthority = authority;
      _loading = false;
    });
  }

  Future<String?> _fetchLivePem() async {
    setState(() => _fetching = true);
    try {
      return await TfApiClient.instance.fetchRsaPublicKeyPem();
    } finally {
      if (mounted) {
        setState(() => _fetching = false);
      }
    }
  }

  Future<void> _viewCurrentServerSha() async {
    final l10n = AppLocalizations.of(context)!;
    final livePem = await _fetchLivePem();
    if (!mounted) return;
    if (livePem == null) {
      TouchFishSnackbarService.instance.show(l10n.rsaFetchFailed);
      return;
    }
    await _showKeyDialog(
      context,
      title: l10n.rsaViewCurrentSha,
      sha: TfCrypto.rsaPublicKeyFingerprint(livePem),
      pem: TfCrypto.normalizePem(livePem),
    );
  }

  Future<void> _saveCurrentKey() async {
    final l10n = AppLocalizations.of(context)!;
    final livePem = await _fetchLivePem();
    if (!mounted) return;
    if (livePem == null) {
      TouchFishSnackbarService.instance.show(l10n.rsaFetchFailed);
      return;
    }
    await RsaKeyTrustService.instance.saveKey(livePem);
    if (!mounted) return;
    final sha = TfCrypto.rsaPublicKeyFingerprint(livePem);
    TouchFishSnackbarService.instance.show(l10n.rsaSaveCurrentKeySuccess(sha));
  }

  Future<void> _deleteKey(String authority) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showTouchFishErrorDialog<bool>(
      context,
      title: l10n.rsaDeleteKey,
      message: l10n.rsaDeleteKeyConfirm(authority),
      icon: Icons.delete_outline_rounded,
      actions: [
        TouchFishDialogAction<bool>(label: l10n.cancel, result: false),
        TouchFishDialogAction<bool>(
          label: l10n.rsaDeleteKey,
          result: true,
          isPrimary: true,
          isDestructive: true,
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    await RsaKeyTrustService.instance.deleteKey(authority);
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      TouchFishSnackbarService.instance
          .show(AppLocalizations.of(context)!.rsaCopied);
    }
  }

  Future<void> _showKeyDialog(
    BuildContext context, {
    required String title,
    required String sha,
    required String pem,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.rsaKeySha,
                style: Theme.of(dialogContext).textTheme.labelMedium?.copyWith(
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              CodeBlock(text: sha, fontSize: 11),
              const SizedBox(height: 16),
              Text(
                l10n.rsaPublicKey,
                style: Theme.of(dialogContext).textTheme.labelMedium?.copyWith(
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              CodeBlock(text: pem, fontSize: 11),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _copyText(sha),
            child: Text(l10n.rsaCopySha),
          ),
          TextButton(
            onPressed: () => _copyText(pem),
            child: Text(l10n.rsaCopyPublicKey),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCurrentServerCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authority = _currentAuthority;
    final savedSha = authority == null
        ? null
        : _savedKeys[authority] == null
        ? null
        : TfCrypto.rsaPublicKeyFingerprint(_savedKeys[authority]!);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.dns_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.rsaCurrentServerSection,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              authority ?? l10n.rsaUnknownServer,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontFamily: codeFontFamily,
                fontFamilyFallback: codeFontFamilyFallback,
              ),
            ),
            if (savedSha != null) ...[
              const SizedBox(height: 12),
              Text(
                l10n.rsaSavedKeySha,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              CodeBlock(text: savedSha, fontSize: 11),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _fetching ? null : _viewCurrentServerSha,
                    icon: _fetching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fingerprint, size: 18),
                    label: Text(l10n.rsaViewCurrentSha),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _fetching ? null : _saveCurrentKey,
                    icon: _fetching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(l10n.rsaSaveCurrentKey),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedKeysCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_savedKeys.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            l10n.rsaNoSavedKeys,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final entries = _savedKeys.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _buildSavedKeyTile(context, l10n, entries[i].key, entries[i].value),
          ],
        ],
      ),
    );
  }

  Widget _buildSavedKeyTile(
    BuildContext context,
    AppLocalizations l10n,
    String authority,
    String pem,
  ) {
    final sha = TfCrypto.rsaPublicKeyFingerprint(pem);
    return ListTile(
      leading: const Icon(Icons.key_outlined),
      title: Text(
        authority,
        style: const TextStyle(
          fontFamily: codeFontFamily,
          fontFamilyFallback: codeFontFamilyFallback,
          fontSize: 13,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: CodeBlock(text: sha, fontSize: 11),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.rsaViewPublicKey,
            icon: const Icon(Icons.visibility_outlined, size: 20),
            onPressed: () => _showKeyDialog(
              context,
              title: l10n.rsaViewPublicKey,
              sha: sha,
              pem: TfCrypto.normalizePem(pem),
            ),
          ),
          IconButton(
            tooltip: l10n.rsaCopySha,
            icon: const Icon(Icons.copy_outlined, size: 20),
            onPressed: () => _copyText(sha),
          ),
          IconButton(
            tooltip: l10n.rsaDeleteKey,
            icon: const Icon(Icons.delete_outline, size: 20),
            color: Theme.of(context).colorScheme.error,
            onPressed: () => _deleteKey(authority),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.rsaKeyManagement,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.rsaKeyManagementDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            _buildSectionHeader(context, l10n.rsaCurrentServerSection),
            _buildCurrentServerCard(context),
            _buildSectionHeader(context, l10n.rsaSavedKeysSection),
            _buildSavedKeysCard(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.rsaKeyManagement),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(context),
    );
  }
}
