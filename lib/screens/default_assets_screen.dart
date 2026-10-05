import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/snackbar_service.dart';
import '../utils/talker.dart';
import '../widgets/admin_ui.dart';
import '../widgets/optimized_image.dart';

class DefaultAssetsScreen extends StatefulWidget {
  const DefaultAssetsScreen({super.key});

  @override
  State<DefaultAssetsScreen> createState() => _DefaultAssetsScreenState();
}

class _DefaultAssetsScreenState extends State<DefaultAssetsScreen> {
  static const _assetTypes = ['logo', 'forum', 'user', 'group'];

  TfServerConfig? _serverInfo;
  String? _baseUrl;
  String _cacheBustToken = DateTime.now().millisecondsSinceEpoch.toString();
  bool _isLoading = true;
  String? _uploadingAssetType;

  @override
  void initState() {
    super.initState();
    _loadServerInfo();
  }

  bool get _canManageAssets {
    return AuthState.instance.currentUser?.hasAdminAccess == true &&
        AuthState.instance.uid != null &&
        AuthState.instance.password != null;
  }

  Future<void> _loadServerInfo({bool showError = false}) async {
    if (!_canManageAssets) {
      if (!mounted) {
        return;
      }
      setState(() {
        _serverInfo = null;
        _baseUrl = null;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final baseUrl = await TfApiClient.instance.getBaseUrl();
      final serverInfo = await TfApiClient.instance.fetchServerInfo();

      if (!mounted) {
        return;
      }

      setState(() {
        _baseUrl = baseUrl;
        _serverInfo = serverInfo;
        _isLoading = false;
      });

      if (serverInfo == null && showError) {
        TouchFishSnackbarService.instance
            .show(AppLocalizations.of(context)!.adminDefaultAssetsLoadFailed);
      }
    } catch (e, stackTrace) {
      talker.error('DefaultAssetsScreen._loadServerInfo failed', e, stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _serverInfo = null;
        _baseUrl = null;
        _isLoading = false;
      });
      if (showError) {
        TouchFishSnackbarService.instance
            .show(AppLocalizations.of(context)!.adminDefaultAssetsLoadFailed);
      }
    }
  }

  Future<Uint8List?> _pickPngBytes() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png'],
      allowMultiple: false,
      withData: true,
    );

    if (result == null) {
      return null;
    }

    return result.files.single.bytes;
  }

  String _assetLabel(AppLocalizations l10n, String assetType) {
    switch (assetType) {
      case 'logo':
        return l10n.adminDefaultAssetLogo;
      case 'forum':
        return l10n.adminDefaultAssetForum;
      case 'user':
        return l10n.adminDefaultAssetUser;
      case 'group':
        return l10n.adminDefaultAssetGroup;
      default:
        return assetType;
    }
  }

  String _assetDescription(AppLocalizations l10n, String assetType) {
    switch (assetType) {
      case 'logo':
        return l10n.adminDefaultAssetLogoDescription;
      case 'forum':
        return l10n.adminDefaultAssetForumDescription;
      case 'user':
        return l10n.adminDefaultAssetUserDescription;
      case 'group':
        return l10n.adminDefaultAssetGroupDescription;
      default:
        return '';
    }
  }

  IconData _assetIcon(String assetType) {
    switch (assetType) {
      case 'logo':
        return Icons.verified_outlined;
      case 'forum':
        return Icons.forum_outlined;
      case 'user':
        return Icons.person_outline_rounded;
      case 'group':
        return Icons.groups_outlined;
      default:
        return Icons.image_outlined;
    }
  }

  String? _resolveAssetUrl(String assetType) {
    final path = _serverInfo?.defaultAssetUrls[assetType];
    final baseUrl = _baseUrl;

    if (path == null || path.trim().isEmpty || baseUrl == null) {
      return null;
    }

    final rawUrl = path.startsWith('http') ? path : '$baseUrl$path';
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return rawUrl;
    }

    final queryParameters = Map<String, String>.from(uri.queryParameters);
    queryParameters['v'] = _cacheBustToken;
    return uri.replace(queryParameters: queryParameters).toString();
  }

  Future<void> _uploadAsset(String assetType) async {
    final l10n = AppLocalizations.of(context)!;
    if (!_canManageAssets || _uploadingAssetType != null) {
      return;
    }

    final bytes = await _pickPngBytes();
    if (!mounted || bytes == null) {
      return;
    }

    setState(() => _uploadingAssetType = assetType);

    try {
      final success = await TfApiClient.instance.uploadDefaultAvatar(
        AuthState.instance.uid!,
        AuthState.instance.password ?? '',
        assetType,
        base64.encode(bytes),
      );

      if (!mounted) {
        return;
      }

      setState(() => _uploadingAssetType = null);

      if (!success) {
        TouchFishSnackbarService.instance
            .show(l10n.adminDefaultAssetUploadFailed(_assetLabel(l10n, assetType)));
        return;
      }

      setState(
        () =>
            _cacheBustToken = DateTime.now().millisecondsSinceEpoch.toString(),
      );
      await _loadServerInfo();
      if (!mounted) {
        return;
      }

      TouchFishSnackbarService.instance
          .show(l10n.adminDefaultAssetUploadSuccess(_assetLabel(l10n, assetType)));
    } catch (e, stackTrace) {
      talker.error('DefaultAssetsScreen._uploadAsset failed', e, stackTrace);
      if (!mounted) {
        return;
      }
      setState(() => _uploadingAssetType = null);
      TouchFishSnackbarService.instance
          .show(l10n.adminDefaultAssetUploadFailed(_assetLabel(l10n, assetType)));
    }
  }

  Widget _buildPreview(String assetType, AppLocalizations l10n) {
    final assetUrl = _resolveAssetUrl(assetType);
    if (assetUrl == null) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Text(l10n.adminDefaultAssetPreviewUnavailable),
      );
    }

    return OptimizedImage(
      provider: NetworkImage(assetUrl),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Text(l10n.adminDefaultAssetPreviewUnavailable),
        );
      },
    );
  }

  Widget _buildAssetCard(
    BuildContext context, {
    required String assetType,
    required AppLocalizations l10n,
  }) {
    final isUploading = _uploadingAssetType == assetType;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_assetIcon(assetType)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _assetLabel(l10n, assetType),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _assetDescription(l10n, assetType),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _buildPreview(assetType, l10n),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.adminDefaultAssetPngHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isUploading ? null : () => _uploadAsset(assetType),
              icon: isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_outlined),
              label: Text(l10n.adminDefaultAssetChangeAction),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (!_canManageAssets) {
      return AdminEmptyState(
        message: l10n.adminAccessDenied,
        icon: Icons.lock_outline_rounded,
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_serverInfo == null) {
      return AdminErrorState(
        message: l10n.adminDefaultAssetsLoadFailed,
        onRetry: () => _loadServerInfo(showError: true),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdminSectionHeader(
          icon: Icons.image_outlined,
          title: l10n.adminDefaultAssets,
          description: l10n.adminDefaultAssetsDescription,
        ),
        const SizedBox(height: 16),
        for (final assetType in _assetTypes)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildAssetCard(context, assetType: assetType, l10n: l10n),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AdminPageScaffold(
      title: l10n.adminDefaultAssets,
      maxWidth: 640,
      actions: [
        IconButton(
          onPressed: _isLoading ? null : () => _loadServerInfo(showError: true),
          tooltip: l10n.retry,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: _buildBody(context),
    );
  }
}
