import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/snackbar_service.dart';
import '../utils/talker.dart';
import '../utils/wide_screen_helper.dart';
import '../widgets/app_alert_dialog.dart';
import '../widgets/code_block.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  static const double _contentMaxWidth = 640;
  static const double _pairBreakpoint = 560;

  final _serverNameController = TextEditingController();
  final _fileLastTimeController = TextEditingController();
  final _groupsLimitController = TextEditingController();
  final _singleGroupMaxPeopleController = TextEditingController();
  final _maxFileSizeController = TextEditingController();
  final _maxMessageLengthController = TextEditingController();
  final _maxStickerPacksController = TextEditingController();
  final _maxStickersPerPackController = TextEditingController();
  final _dailyStickerPackLimitController = TextEditingController();
  final _maxStickerSizeController = TextEditingController();
  final _smtpHostController = TextEditingController();
  final _smtpPortController = TextEditingController();
  final _verifyEmailController = TextEditingController();
  final _emailPasswordController = TextEditingController();
  final _proxyCountController = TextEditingController();
  final _defaultJoinTargetsController = TextEditingController();
  final _jwtExpiresSecondsController = TextEditingController();
  final _jwtRefreshExpiresSecondsController = TextEditingController();
  final _jwtMaxPerUserController = TextEditingController();
  final _captchaSiteKeyController = TextEditingController();
  final _captchaSecretController = TextEditingController();
  final _rateLimitsController = TextEditingController();
  final _minGroupNameLengthController = TextEditingController();
  final _maxGroupNameLengthController = TextEditingController();
  final _minUsernameLengthController = TextEditingController();
  final _minPasswordLengthController = TextEditingController();
  final _maxSignLengthController = TextEditingController();
  final _maxIntroductionLengthController = TextEditingController();
  final _maxPostContentLengthController = TextEditingController();
  final _maxAvatarSizeController = TextEditingController();
  final _userStorageQuotaController = TextEditingController();
  final _maxUserStorageQuotaController = TextEditingController();
  final _maxStickerStorageQuotaController = TextEditingController();

  TfServerConfig? _settings;
  bool _captcha = false;
  String _captchaProvider = 'image';
  String _fileDownloadMode = 'redirect';
  bool _mediaFeatures = true;
  bool _emailEnabled = false;
  bool _smtpUseSsl = true;
  bool _reverseProxyEnabled = false;
  bool _legacyAuthEnabled = true;
  bool _isLoading = true;
  bool _isSaving = false;

  final _searchController = TextEditingController();
  _SettingsSection _selectedSection = _SettingsSection.general;
  final Set<String> _unlimitedOn = {};
  final Map<String, String?> _lastConcrete = {};
  _Baseline? _baseline;
  bool _dirty = false;
  bool _allowPop = false;
  bool _suppressDirtyCheck = false;

  static const _captchaProviders = ['image', 'turnstile', 'hcaptcha', 'recaptcha'];
  static const _fileDownloadModes = ['redirect', 'proxy'];

  List<TextEditingController> get _allControllers => [
    _serverNameController,
    _fileLastTimeController,
    _groupsLimitController,
    _singleGroupMaxPeopleController,
    _maxFileSizeController,
    _maxMessageLengthController,
    _maxStickerPacksController,
    _maxStickersPerPackController,
    _dailyStickerPackLimitController,
    _maxStickerSizeController,
    _smtpHostController,
    _smtpPortController,
    _verifyEmailController,
    _emailPasswordController,
    _proxyCountController,
    _defaultJoinTargetsController,
    _jwtExpiresSecondsController,
    _jwtRefreshExpiresSecondsController,
    _jwtMaxPerUserController,
    _captchaSiteKeyController,
    _captchaSecretController,
    _rateLimitsController,
    _minGroupNameLengthController,
    _maxGroupNameLengthController,
    _minUsernameLengthController,
    _minPasswordLengthController,
    _maxSignLengthController,
    _maxIntroductionLengthController,
    _maxPostContentLengthController,
    _maxAvatarSizeController,
    _userStorageQuotaController,
    _maxUserStorageQuotaController,
    _maxStickerStorageQuotaController,
  ];

  /// 支持 -1（不限）的字段：key -> controller，key 同时是基线/不限开关的稳定标识。
  Map<String, TextEditingController> get _unlimitedControllers => {
    'groupsLimit': _groupsLimitController,
    'singleGroupMaxPeople': _singleGroupMaxPeopleController,
    'maxFileSize': _maxFileSizeController,
    'maxStickerPacks': _maxStickerPacksController,
    'maxStickersPerPack': _maxStickersPerPackController,
    'dailyStickerPackLimit': _dailyStickerPackLimitController,
    'maxStickerSize': _maxStickerSizeController,
    'jwtMaxPerUser': _jwtMaxPerUserController,
    'maxSignLength': _maxSignLengthController,
    'maxIntroductionLength': _maxIntroductionLengthController,
    'maxPostContentLength': _maxPostContentLengthController,
    'maxAvatarSize': _maxAvatarSizeController,
    'userStorageQuota': _userStorageQuotaController,
    'maxUserStorageQuota': _maxUserStorageQuotaController,
    'maxStickerStorageQuota': _maxStickerStorageQuotaController,
  };

  @override
  void initState() {
    super.initState();
    for (final controller in _allControllers) {
      controller.addListener(_handleFieldChanged);
    }
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
    _maxStickerPacksController.dispose();
    _maxStickersPerPackController.dispose();
    _dailyStickerPackLimitController.dispose();
    _maxStickerSizeController.dispose();
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    _verifyEmailController.dispose();
    _emailPasswordController.dispose();
    _proxyCountController.dispose();
    _defaultJoinTargetsController.dispose();
    _jwtExpiresSecondsController.dispose();
    _jwtRefreshExpiresSecondsController.dispose();
    _jwtMaxPerUserController.dispose();
    _captchaSiteKeyController.dispose();
    _captchaSecretController.dispose();
    _rateLimitsController.dispose();
    _minGroupNameLengthController.dispose();
    _maxGroupNameLengthController.dispose();
    _minUsernameLengthController.dispose();
    _minPasswordLengthController.dispose();
    _maxSignLengthController.dispose();
    _maxIntroductionLengthController.dispose();
    _maxPostContentLengthController.dispose();
    _maxAvatarSizeController.dispose();
    _userStorageQuotaController.dispose();
    _maxUserStorageQuotaController.dispose();
    _maxStickerStorageQuotaController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _canManageServer {
    return AuthState.instance.currentUser?.isRoot == true &&
        AuthState.instance.uid != null &&
        (AuthState.instance.password != null || AuthState.instance.isJwtMode);
  }

  void _applySettings(TfServerConfig settings) {
    _suppressDirtyCheck = true;
    _serverNameController.text = settings.serverName;
    _fileLastTimeController.text = (settings.fileLastTime ?? 0).toString();
    _groupsLimitController.text = (settings.groupsLimit ?? -1).toString();
    _singleGroupMaxPeopleController.text = (settings.singleGroupMaxPeople ?? -1)
        .toString();
    _maxFileSizeController.text = (settings.maxFileSize ?? -1).toString();
    _maxMessageLengthController.text = (settings.maxMessageLength ?? 10000)
        .toString();
    _maxStickerPacksController.text = settings.maxStickerPacksPerUser.toString();
    _maxStickersPerPackController.text = settings.maxStickersPerPack.toString();
    _dailyStickerPackLimitController.text =
        settings.dailyStickerPackCreationLimit.toString();
    _maxStickerSizeController.text = settings.maxStickerSize.toString();
    _captcha = settings.captcha;
    _captchaProvider = settings.captchaProvider.isEmpty
        ? 'image'
        : settings.captchaProvider;
    _captchaSiteKeyController.text = settings.captchaSiteKey;
    _captchaSecretController.clear();
    _rateLimitsController.text =
        (settings.rateLimits == null || settings.rateLimits!.isEmpty)
        ? ''
        : const JsonEncoder.withIndent('  ').convert(settings.rateLimits);
    _minGroupNameLengthController.text = settings.minGroupNameLength.toString();
    _maxGroupNameLengthController.text = settings.maxGroupNameLength.toString();
    _minUsernameLengthController.text = settings.minUsernameLength.toString();
    _minPasswordLengthController.text = settings.minPasswordLength.toString();
    _maxSignLengthController.text = (settings.maxSignLength ?? -1).toString();
    _maxIntroductionLengthController.text =
        (settings.maxIntroductionLength ?? -1).toString();
    _maxPostContentLengthController.text =
        (settings.maxPostContentLength ?? -1).toString();
    _maxAvatarSizeController.text = (settings.maxAvatarSize ?? -1).toString();
    _userStorageQuotaController.text = (settings.userStorageQuota ?? -1)
        .toString();
    _maxUserStorageQuotaController.text = (settings.maxUserStorageQuota ?? -1)
        .toString();
    _maxStickerStorageQuotaController.text =
        (settings.maxStickerStorageQuota ?? -1).toString();
    _jwtRefreshExpiresSecondsController.text =
        (settings.jwtRefreshExpiresSeconds ?? 604800).toString();
    _fileDownloadMode = settings.fileDownloadMode ?? 'redirect';
    _mediaFeatures = settings.mediaFeatures;
    _emailEnabled = settings.emailActivate;
    _smtpHostController.text = settings.smtpHost ?? '';
    _smtpPortController.text = (settings.smtpPort ?? 465).toString();
    _smtpUseSsl = settings.smtpUseSsl ?? true;
    _reverseProxyEnabled = settings.reverseProxyEnabled ?? false;
    _proxyCountController.text = (settings.proxyCount ?? 1).toString();
    _verifyEmailController.text = settings.verifyEmail ?? '';
    _emailPasswordController.clear();
    _defaultJoinTargetsController.text = settings.defaultJoinTargets.join(' ');
    _legacyAuthEnabled = settings.legacyAuthEnabled ?? true;
    _jwtExpiresSecondsController.text =
        (settings.jwtExpiresSeconds ?? 604800).toString();
    _jwtMaxPerUserController.text =
        (settings.jwtMaxPerUser ?? 5).toString();

    _unlimitedOn.clear();
    for (final entry in _unlimitedControllers.entries) {
      if (int.tryParse(entry.value.text.trim()) == -1) {
        _unlimitedOn.add(entry.key);
      }
    }
    _captureBaseline();
    _suppressDirtyCheck = false;
  }

  void _captureBaseline() {
    _baseline = _Baseline(
      texts: {
        for (final controller in _allControllers) controller: controller.text,
      },
      unlimitedOn: Set.of(_unlimitedOn),
      scalars: _scalarSnapshot(),
    );
    for (final entry in _unlimitedControllers.entries) {
      _lastConcrete[entry.key] = _unlimitedOn.contains(entry.key)
          ? null
          : entry.value.text.trim();
    }
    _dirty = false;
  }

  void _clearBaseline() {
    _baseline = null;
    _unlimitedOn.clear();
    _lastConcrete.clear();
    _dirty = false;
  }

  Map<String, Object?> _scalarSnapshot() => {
    'captcha': _captcha,
    'captchaProvider': _captchaProvider,
    'fileDownloadMode': _fileDownloadMode,
    'mediaFeatures': _mediaFeatures,
    'emailEnabled': _emailEnabled,
    'smtpUseSsl': _smtpUseSsl,
    'reverseProxyEnabled': _reverseProxyEnabled,
    'legacyAuthEnabled': _legacyAuthEnabled,
  };

  bool _computeDirty() {
    final baseline = _baseline;
    if (baseline == null) return false;
    for (final entry in baseline.texts.entries) {
      if (entry.key.text != entry.value) return true;
    }
    if (baseline.unlimitedOn.length != _unlimitedOn.length ||
        !baseline.unlimitedOn.every(_unlimitedOn.contains)) {
      return true;
    }
    final scalars = _scalarSnapshot();
    for (final entry in baseline.scalars.entries) {
      if (scalars[entry.key] != entry.value) return true;
    }
    return false;
  }

  void _handleFieldChanged() {
    if (_suppressDirtyCheck || _isSaving || !mounted) return;
    final dirty = _computeDirty();
    if (dirty != _dirty) {
      setState(() => _dirty = dirty);
    }
  }

  void _onUnlimitedChanged(String key, bool value) {
    final controller = _unlimitedControllers[key];
    if (controller == null || _isSaving) return;
    _suppressDirtyCheck = true;
    if (value) {
      _lastConcrete[key] = controller.text.trim();
      _unlimitedOn.add(key);
      controller.text = '-1';
    } else {
      _unlimitedOn.remove(key);
      final restored = _lastConcrete[key]?.trim();
      controller.text =
          (restored == null || restored.isEmpty || restored == '-1')
          ? ''
          : restored;
    }
    _suppressDirtyCheck = false;
    setState(() => _dirty = _computeDirty());
  }

  void _undoChanges() {
    final settings = _settings;
    if (settings == null || _isSaving) return;
    _applySettings(settings);
    setState(() {});
  }

  Future<void> _loadSettings({bool showError = false}) async {
    if (!_canManageServer) {
      if (!mounted) {
        return;
      }
      _clearBaseline();
      setState(() {
        _settings = null;
        _isLoading = false;
      });
      return;
    }

    final uid = AuthState.instance.uid!;
    final password = AuthState.instance.password ?? '';

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
        _clearBaseline();
        setState(() {
          _settings = null;
          _isLoading = false;
        });
        if (showError) {
          TouchFishSnackbarService.instance.show(
            AppLocalizations.of(context)!.adminServerSettingsLoadFailed,
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
      _clearBaseline();
      setState(() {
        _settings = null;
        _isLoading = false;
      });
      if (showError) {
        TouchFishSnackbarService.instance.show(
          AppLocalizations.of(context)!.adminServerSettingsLoadFailed,
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
    final maxStickerPacks = _parseIntegerField(
      _maxStickerPacksController.text,
      minimum: 1,
      allowUnlimited: true,
    );
    final maxStickersPerPack = _parseIntegerField(
      _maxStickersPerPackController.text,
      minimum: 1,
      allowUnlimited: true,
    );
    final dailyStickerPackLimit = _parseIntegerField(
      _dailyStickerPackLimitController.text,
      minimum: 1,
      allowUnlimited: true,
    );
    final maxStickerSize = _parseIntegerField(
      _maxStickerSizeController.text,
      minimum: 1,
      allowUnlimited: true,
    );
    final smtpPort = _parseIntegerField(
      _smtpPortController.text,
      minimum: 1,
    );
    final proxyCount = _parseIntegerField(
      _proxyCountController.text,
      minimum: 0,
    );
    final jwtExpiresSeconds = _parseIntegerField(
      _jwtExpiresSecondsController.text,
      minimum: 60,
    );
    final jwtMaxPerUser = _parseIntegerField(
      _jwtMaxPerUserController.text,
      minimum: 0,
      allowUnlimited: true,
    );
    final jwtRefreshExpiresSeconds = _parseIntegerField(
      _jwtRefreshExpiresSecondsController.text,
      minimum: 60,
    );
    final minGroupNameLength = _parseIntegerField(
      _minGroupNameLengthController.text,
      minimum: 1,
    );
    final maxGroupNameLength = _parseIntegerField(
      _maxGroupNameLengthController.text,
      minimum: 1,
    );
    final minUsernameLength = _parseIntegerField(
      _minUsernameLengthController.text,
      minimum: 4,
    );
    final minPasswordLength = _parseIntegerField(
      _minPasswordLengthController.text,
      minimum: 1,
    );
    final maxSignLength = _parseIntegerField(
      _maxSignLengthController.text,
      minimum: 1,
      allowUnlimited: true,
    );
    final maxIntroductionLength = _parseIntegerField(
      _maxIntroductionLengthController.text,
      minimum: 1,
      allowUnlimited: true,
    );
    final maxPostContentLength = _parseIntegerField(
      _maxPostContentLengthController.text,
      minimum: 1,
      allowUnlimited: true,
    );
    final maxAvatarSize = _parseIntegerField(
      _maxAvatarSizeController.text,
      minimum: 0,
      allowUnlimited: true,
    );
    final userStorageQuota = _parseIntegerField(
      _userStorageQuotaController.text,
      minimum: 0,
      allowUnlimited: true,
    );
    final maxUserStorageQuota = _parseIntegerField(
      _maxUserStorageQuotaController.text,
      minimum: 0,
      allowUnlimited: true,
    );
    final maxStickerStorageQuota = _parseIntegerField(
      _maxStickerStorageQuotaController.text,
      minimum: 0,
      allowUnlimited: true,
    );
    final defaultJoinTargets = _parseDefaultJoinTargets(
      _defaultJoinTargetsController.text,
    );

    Map<String, dynamic>? rateLimits;
    var rateLimitsValid = true;
    final rateLimitsRaw = _rateLimitsController.text.trim();
    if (rateLimitsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(rateLimitsRaw);
        if (decoded is Map) {
          rateLimits = Map<String, dynamic>.from(decoded);
        } else {
          rateLimitsValid = false;
        }
      } catch (_) {
        rateLimitsValid = false;
      }
    }

    if (serverName.isEmpty ||
        fileLastTime == null ||
        groupsLimit == null ||
        singleGroupMaxPeople == null ||
        maxFileSize == null ||
        maxMessageLength == null ||
        maxStickerPacks == null ||
        maxStickersPerPack == null ||
        dailyStickerPackLimit == null ||
        maxStickerSize == null ||
        smtpPort == null ||
        jwtExpiresSeconds == null ||
        jwtRefreshExpiresSeconds == null ||
        jwtMaxPerUser == null ||
        minGroupNameLength == null ||
        maxGroupNameLength == null ||
        minUsernameLength == null ||
        minPasswordLength == null ||
        maxSignLength == null ||
        maxIntroductionLength == null ||
        maxPostContentLength == null ||
        maxAvatarSize == null ||
        userStorageQuota == null ||
        maxUserStorageQuota == null ||
        maxStickerStorageQuota == null ||
        !rateLimitsValid ||
        defaultJoinTargets == null ||
        (_reverseProxyEnabled && proxyCount == null)) {
      TouchFishSnackbarService.instance.show(
        rateLimitsValid
            ? l10n.adminServerSettingsInvalidInput
            : l10n.adminServerRateLimitsInvalid,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = AuthState.instance.uid!;
      final password = AuthState.instance.password ?? '';
      final wasEmailEnabled = _settings?.emailActivate ?? false;
      final verifyEmail = _verifyEmailController.text.trim();
      final emailPassword = _emailPasswordController.text;

      // 邮箱验证开关变化或邮箱信息更新时调用 change_email_verify
      if (_emailEnabled != wasEmailEnabled ||
          (_emailEnabled && emailPassword.isNotEmpty)) {
        if (_emailEnabled) {
          if (verifyEmail.isEmpty || emailPassword.isEmpty) {
            setState(() => _isSaving = false);
            TouchFishSnackbarService.instance.show(
              l10n.adminServerEmailPasswordRequired,
            );
            return;
          }
          final emailOk = await TfApiClient.instance.changeEmailVerify(
            uid,
            password,
            changeTo: true,
            verifyEmail: verifyEmail,
            emailPassword: emailPassword,
          );
          if (!emailOk) {
            setState(() => _isSaving = false);
            TouchFishSnackbarService.instance.show(
              l10n.adminServerSettingsSaveFailed,
            );
            return;
          }
        } else {
          final emailOk = await TfApiClient.instance.changeEmailVerify(
            uid,
            password,
            changeTo: false,
          );
          if (!emailOk) {
            setState(() => _isSaving = false);
            TouchFishSnackbarService.instance.show(
              l10n.adminServerSettingsSaveFailed,
            );
            return;
          }
        }
      }

      final updated = await TfApiClient.instance.updateServerSettings(
        uid,
        password,
        serverName: serverName,
        captcha: _captcha,
        fileLastTime: fileLastTime,
        groupsLimit: groupsLimit,
        singleGroupMaxPeople: singleGroupMaxPeople,
        maxFileSize: maxFileSize,
        maxMessageLength: maxMessageLength,
        maxStickerPacksPerUser: maxStickerPacks,
        maxStickersPerPack: maxStickersPerPack,
        dailyStickerPackCreationLimit: dailyStickerPackLimit,
        maxStickerSize: maxStickerSize,
        smtpHost: _smtpHostController.text.trim(),
        smtpPort: smtpPort,
        smtpUseSsl: _smtpUseSsl,
        reverseProxyEnabled: _reverseProxyEnabled,
        proxyCount: _reverseProxyEnabled ? proxyCount : 1,
        defaultJoinTargets: defaultJoinTargets,
        legacyAuthEnabled: _legacyAuthEnabled,
        jwtExpiresSeconds: jwtExpiresSeconds,
        jwtRefreshExpiresSeconds: jwtRefreshExpiresSeconds,
        jwtMaxPerUser: jwtMaxPerUser,
        minGroupNameLength: minGroupNameLength,
        maxGroupNameLength: maxGroupNameLength,
        minUsernameLength: minUsernameLength,
        minPasswordLength: minPasswordLength,
        maxSignLength: maxSignLength,
        maxIntroductionLength: maxIntroductionLength,
        maxPostContentLength: maxPostContentLength,
        maxAvatarSize: maxAvatarSize,
        userStorageQuota: userStorageQuota,
        maxUserStorageQuota: maxUserStorageQuota,
        maxStickerStorageQuota: maxStickerStorageQuota,
        fileDownloadMode: _fileDownloadMode,
        mediaFeatures: _mediaFeatures,
      );

      if (!mounted) {
        return;
      }

      if (updated == null) {
        setState(() => _isSaving = false);
        TouchFishSnackbarService.instance.show(
          l10n.adminServerSettingsSaveFailed,
        );
        return;
      }

      final captchaOk = await TfApiClient.instance.changeCaptcha(
        uid,
        password,
        changeTo: _captcha,
        provider: _captchaProvider,
        siteKey: _captchaSiteKeyController.text.trim().isEmpty
            ? null
            : _captchaSiteKeyController.text.trim(),
        secret: _captchaSecretController.text.isEmpty
            ? null
            : _captchaSecretController.text,
      );
      if (!mounted) return;
      if (!captchaOk) {
        setState(() => _isSaving = false);
        TouchFishSnackbarService.instance.show(
          l10n.adminServerCaptchaSaveFailed,
        );
        return;
      }

      final rateLimitsOk = await TfApiClient.instance.changeRateLimits(
        uid,
        password,
        rateLimits,
      );
      if (!mounted) return;
      if (!rateLimitsOk) {
        setState(() => _isSaving = false);
        TouchFishSnackbarService.instance.show(
          l10n.adminServerRateLimitsSaveFailed,
        );
        return;
      }

      setState(() => _isSaving = false);
      await _loadSettings();
      if (!mounted) return;

      TouchFishSnackbarService.instance.show(
        l10n.adminServerSettingsSaveSuccess,
      );
    } catch (e, stackTrace) {
      talker.error('ServerSettingsScreen._saveSettings failed', e, stackTrace);
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      TouchFishSnackbarService.instance.show(
        l10n.adminServerSettingsSaveFailed,
      );
    }
  }

  List<String>? _parseDefaultJoinTargets(String raw) {
    final targets = <String>[];
    for (final part in raw.split(RegExp(r'[\s,]+'))) {
      final target = part.trim().toUpperCase();
      if (target.isEmpty) continue;
      if (!RegExp(r'^[UG][1-9][0-9]*$').hasMatch(target)) return null;
      if (!targets.contains(target)) targets.add(target);
    }
    return targets;
  }

  Future<bool> _confirmDiscard(String actionLabel) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showTouchFishInfoDialog<bool>(
      context,
      title: l10n.adminServerDiscardConfirmTitle,
      message: l10n.adminServerDiscardConfirmMessage,
      icon: Icons.warning_amber_rounded,
      actions: [
        TouchFishDialogAction<bool>(label: l10n.cancel),
        TouchFishDialogAction<bool>(
          label: actionLabel,
          result: true,
          isPrimary: true,
          isDestructive: true,
        ),
      ],
    );
    return confirmed == true;
  }

  Future<void> _attemptLeave() async {
    if (_dirty && _settings != null) {
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await _confirmDiscard(l10n.adminServerDiscardChanges);
      if (!confirmed || !mounted) return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    context.pop();
  }

  Future<void> _onRefreshRequested() async {
    if (_isLoading) return;
    if (_dirty && _settings != null) {
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await _confirmDiscard(
        l10n.adminServerDiscardAndRefresh,
      );
      if (!confirmed || !mounted) return;
    }
    await _loadSettings(showError: true);
  }

  String _sectionTitle(AppLocalizations l10n, _SettingsSection section) {
    return switch (section) {
      _SettingsSection.general => l10n.adminServerSectionGeneral,
      _SettingsSection.messages => l10n.adminServerSectionMessages,
      _SettingsSection.files => l10n.adminServerSectionFiles,
      _SettingsSection.groups => l10n.adminServerSectionGroups,
      _SettingsSection.stickers => l10n.adminServerSectionStickers,
      _SettingsSection.email => l10n.adminServerSectionEmailService,
      _SettingsSection.proxy => l10n.adminServerSectionReverseProxy,
      _SettingsSection.auth => l10n.adminServerSectionAuth,
      _SettingsSection.rateLimits => l10n.adminServerSectionRateLimits,
      _SettingsSection.limits => l10n.adminServerSectionLimits,
      _SettingsSection.serverInfo => l10n.adminServerSectionServerInfo,
    };
  }

  IconData _sectionIcon(_SettingsSection section) {
    return switch (section) {
      _SettingsSection.general => Icons.tune_rounded,
      _SettingsSection.messages => Icons.forum_outlined,
      _SettingsSection.files => Icons.folder_outlined,
      _SettingsSection.groups => Icons.groups_outlined,
      _SettingsSection.stickers => Icons.emoji_emotions_outlined,
      _SettingsSection.email => Icons.mark_email_read_outlined,
      _SettingsSection.proxy => Icons.hub_outlined,
      _SettingsSection.auth => Icons.security_outlined,
      _SettingsSection.rateLimits => Icons.speed_outlined,
      _SettingsSection.limits => Icons.straighten_outlined,
      _SettingsSection.serverInfo => Icons.info_outline,
    };
  }

  String? _sectionDescription(AppLocalizations l10n, _SettingsSection section) {
    return switch (section) {
      _SettingsSection.general => l10n.adminServerSettingsDescription,
      _SettingsSection.email => l10n.adminServerEmailDescription,
      _SettingsSection.proxy => l10n.adminServerReverseProxyDescription,
      _SettingsSection.auth => l10n.adminServerAuthDescription,
      _SettingsSection.limits => l10n.adminServerLimitsDescription,
      _SettingsSection.serverInfo => l10n.adminServerReadOnlyDescription,
      _ => null,
    };
  }

  Widget _textField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    String? helperText,
    bool obscureText = false,
    int? minLines,
    int? maxLines,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool alignLabelWithHint = false,
    TextStyle? style,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      minLines: minLines,
      maxLines: maxLines ?? 1,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: style,
      decoration: InputDecoration(
        labelText: labelText,
        helperText: helperText,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        isDense: true,
        alignLabelWithHint: alignLabelWithHint,
      ),
    );
  }

  Widget _integerField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    String? helperText,
  }) {
    return _textField(
      controller: controller,
      labelText: labelText,
      icon: icon,
      helperText: helperText,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
    );
  }

  Widget _unlimitedNumberField({
    required String key,
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
  }) {
    return _UnlimitedNumberField(
      controller: controller,
      labelText: labelText,
      icon: icon,
      unlimited: _unlimitedOn.contains(key),
      onUnlimitedChanged: _isSaving
          ? null
          : (value) => _onUnlimitedChanged(key, value),
    );
  }

  Widget _switchField({
    required bool value,
    required String title,
    String? subtitle,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      onChanged: _isSaving ? null : onChanged,
    );
  }

  Widget _captchaProviderField(AppLocalizations l10n) {
    return DropdownButtonFormField<String>(
      key: ValueKey(_captchaProvider),
      initialValue: _captchaProvider,
      decoration: InputDecoration(
        labelText: l10n.adminServerFieldCaptchaProvider,
        helperText: l10n.adminServerCaptchaProviderDescription,
        prefixIcon: const Icon(Icons.verified_outlined),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: _captchaProviders
          .map((value) => DropdownMenuItem(value: value, child: Text(value)))
          .toList(),
      onChanged: _isSaving
          ? null
          : (value) {
              if (value == null) return;
              setState(() => _captchaProvider = value);
              _handleFieldChanged();
            },
    );
  }

  Widget _fileDownloadModeField(AppLocalizations l10n) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: l10n.adminServerFieldFileDownloadMode,
        helperText: l10n.adminServerFileDownloadModeDescription,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [
          for (final mode in _fileDownloadModes)
            ButtonSegment(value: mode, label: Text(mode)),
        ],
        selected: {_fileDownloadMode},
        onSelectionChanged: _isSaving
            ? null
            : (selection) {
                setState(() => _fileDownloadMode = selection.first);
                _handleFieldChanged();
              },
      ),
    );
  }

  Widget _readOnlyTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
      ),
      title: Text(label),
      trailing: Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  bool _isFieldVisible(_SettingField field) => field.visible?.call() ?? true;

  /// 全部设置字段的注册表：分区视图与搜索结果共用，visible 按当前状态求值。
  List<_SettingField> _buildRegistry(AppLocalizations l10n) {
    return [
      // 常规
      _SettingField(
        key: 'serverName',
        section: _SettingsSection.general,
        label: (l10n) => l10n.adminServerFieldServerName,
        keywords: const ['server', 'name', 'dns'],
        build: (context, l10n) => _textField(
          controller: _serverNameController,
          labelText: l10n.adminServerFieldServerName,
          icon: Icons.dns_outlined,
        ),
      ),
      _SettingField(
        key: 'captcha',
        section: _SettingsSection.general,
        label: (l10n) => l10n.adminServerFieldCaptcha,
        keywords: const ['captcha', 'verify'],
        build: (context, l10n) => _switchField(
          value: _captcha,
          title: l10n.adminServerFieldCaptcha,
          subtitle: l10n.adminServerSettingsCaptchaDescription,
          onChanged: (value) {
            setState(() => _captcha = value);
            _handleFieldChanged();
          },
        ),
      ),
      _SettingField(
        key: 'captchaProvider',
        section: _SettingsSection.general,
        label: (l10n) => l10n.adminServerFieldCaptchaProvider,
        keywords: const [
          'captcha',
          'provider',
          'turnstile',
          'hcaptcha',
          'recaptcha',
        ],
        build: (context, l10n) => _captchaProviderField(l10n),
      ),
      _SettingField(
        key: 'captchaSiteKey',
        section: _SettingsSection.general,
        label: (l10n) => l10n.adminServerFieldCaptchaSiteKey,
        keywords: const ['captcha', 'site key'],
        visible: () => _captchaProvider != 'image',
        pairKey: 'captchaKeys',
        build: (context, l10n) => _textField(
          controller: _captchaSiteKeyController,
          labelText: l10n.adminServerFieldCaptchaSiteKey,
          icon: Icons.key_outlined,
        ),
      ),
      _SettingField(
        key: 'captchaSecret',
        section: _SettingsSection.general,
        label: (l10n) => l10n.adminServerFieldCaptchaSecret,
        keywords: const ['captcha', 'secret'],
        visible: () => _captchaProvider != 'image',
        pairKey: 'captchaKeys',
        build: (context, l10n) => _textField(
          controller: _captchaSecretController,
          labelText: l10n.adminServerFieldCaptchaSecret,
          helperText: l10n.adminServerCaptchaSecretHint,
          icon: Icons.lock_outline,
          obscureText: true,
        ),
      ),
      // 消息
      _SettingField(
        key: 'maxMessageLength',
        section: _SettingsSection.messages,
        label: (l10n) => l10n.adminServerFieldMaxMessageLength,
        keywords: const ['message', 'length'],
        build: (context, l10n) => _integerField(
          controller: _maxMessageLengthController,
          labelText: l10n.adminServerFieldMaxMessageLength,
          helperText: l10n.adminServerFieldMaxMessageLengthDescription,
          icon: Icons.message_outlined,
        ),
      ),
      // 文件与媒体
      _SettingField(
        key: 'fileLastTime',
        section: _SettingsSection.files,
        label: (l10n) => l10n.adminServerFieldFileLastTime,
        keywords: const ['file', 'retention', 'time'],
        build: (context, l10n) => _integerField(
          controller: _fileLastTimeController,
          labelText: l10n.adminServerFieldFileLastTime,
          helperText: l10n.adminServerFileLastTimeDescription,
          icon: Icons.schedule_outlined,
        ),
      ),
      _SettingField(
        key: 'maxFileSize',
        section: _SettingsSection.files,
        label: (l10n) => l10n.adminServerFieldMaxFileSize,
        keywords: const ['file', 'size'],
        build: (context, l10n) => _unlimitedNumberField(
          key: 'maxFileSize',
          controller: _maxFileSizeController,
          labelText: l10n.adminServerFieldMaxFileSize,
          icon: Icons.folder_open_outlined,
        ),
      ),
      _SettingField(
        key: 'fileDownloadMode',
        section: _SettingsSection.files,
        label: (l10n) => l10n.adminServerFieldFileDownloadMode,
        keywords: const ['download', 'proxy', 'redirect'],
        build: (context, l10n) => _fileDownloadModeField(l10n),
      ),
      _SettingField(
        key: 'mediaFeatures',
        section: _SettingsSection.files,
        label: (l10n) => l10n.adminServerFieldMediaFeatures,
        keywords: const ['media', 'thumbnail'],
        build: (context, l10n) => _switchField(
          value: _mediaFeatures,
          title: l10n.adminServerFieldMediaFeatures,
          subtitle: l10n.adminServerMediaFeaturesDescription,
          onChanged: (value) {
            setState(() => _mediaFeatures = value);
            _handleFieldChanged();
          },
        ),
      ),
      // 群组
      _SettingField(
        key: 'groupsLimit',
        section: _SettingsSection.groups,
        label: (l10n) => l10n.adminServerFieldGroupsLimit,
        keywords: const ['group', 'limit'],
        pairKey: 'groupLimits',
        build: (context, l10n) => _unlimitedNumberField(
          key: 'groupsLimit',
          controller: _groupsLimitController,
          labelText: l10n.adminServerFieldGroupsLimit,
          icon: Icons.groups_outlined,
        ),
      ),
      _SettingField(
        key: 'singleGroupMaxPeople',
        section: _SettingsSection.groups,
        label: (l10n) => l10n.adminServerFieldSingleGroupMaxPeople,
        keywords: const ['group', 'members', 'people'],
        pairKey: 'groupLimits',
        build: (context, l10n) => _unlimitedNumberField(
          key: 'singleGroupMaxPeople',
          controller: _singleGroupMaxPeopleController,
          labelText: l10n.adminServerFieldSingleGroupMaxPeople,
          icon: Icons.group_outlined,
        ),
      ),
      _SettingField(
        key: 'defaultJoinTargets',
        section: _SettingsSection.groups,
        label: (l10n) => l10n.adminServerFieldDefaultJoinTargets,
        keywords: const ['join', 'friend', 'default'],
        build: (context, l10n) => _textField(
          controller: _defaultJoinTargetsController,
          labelText: l10n.adminServerFieldDefaultJoinTargets,
          helperText: l10n.adminServerFieldDefaultJoinTargetsDescription,
          icon: Icons.person_add_alt_1_outlined,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.characters,
          alignLabelWithHint: true,
        ),
      ),
      // 贴图
      _SettingField(
        key: 'maxStickerPacks',
        section: _SettingsSection.stickers,
        label: (l10n) => l10n.adminServerFieldMaxStickerPacks,
        keywords: const ['sticker', 'pack'],
        pairKey: 'stickerPackLimits',
        build: (context, l10n) => _unlimitedNumberField(
          key: 'maxStickerPacks',
          controller: _maxStickerPacksController,
          labelText: l10n.adminServerFieldMaxStickerPacks,
          icon: Icons.collections_outlined,
        ),
      ),
      _SettingField(
        key: 'maxStickersPerPack',
        section: _SettingsSection.stickers,
        label: (l10n) => l10n.adminServerFieldMaxStickersPerPack,
        keywords: const ['sticker', 'pack'],
        pairKey: 'stickerPackLimits',
        build: (context, l10n) => _unlimitedNumberField(
          key: 'maxStickersPerPack',
          controller: _maxStickersPerPackController,
          labelText: l10n.adminServerFieldMaxStickersPerPack,
          icon: Icons.emoji_emotions_outlined,
        ),
      ),
      _SettingField(
        key: 'dailyStickerPackLimit',
        section: _SettingsSection.stickers,
        label: (l10n) => l10n.adminServerFieldDailyStickerPackLimit,
        keywords: const ['sticker', 'daily'],
        build: (context, l10n) => _unlimitedNumberField(
          key: 'dailyStickerPackLimit',
          controller: _dailyStickerPackLimitController,
          labelText: l10n.adminServerFieldDailyStickerPackLimit,
          icon: Icons.today_outlined,
        ),
      ),
      _SettingField(
        key: 'maxStickerSize',
        section: _SettingsSection.stickers,
        label: (l10n) => l10n.adminServerFieldMaxStickerSize,
        keywords: const ['sticker', 'size'],
        build: (context, l10n) => _unlimitedNumberField(
          key: 'maxStickerSize',
          controller: _maxStickerSizeController,
          labelText: l10n.adminServerFieldMaxStickerSize,
          icon: Icons.storage_outlined,
        ),
      ),
      // 邮件服务
      _SettingField(
        key: 'emailEnabled',
        section: _SettingsSection.email,
        label: (l10n) => l10n.adminServerFieldEmailActivation,
        keywords: const ['email', 'activation'],
        build: (context, l10n) => _switchField(
          value: _emailEnabled,
          title: l10n.adminServerFieldEmailActivation,
          subtitle: l10n.adminServerEmailEnableDescription,
          onChanged: (value) {
            setState(() => _emailEnabled = value);
            _handleFieldChanged();
          },
        ),
      ),
      _SettingField(
        key: 'smtpHost',
        section: _SettingsSection.email,
        label: (l10n) => l10n.adminServerFieldSmtpHost,
        keywords: const ['smtp', 'email', 'host'],
        visible: () => _emailEnabled,
        pairKey: 'smtpServer',
        build: (context, l10n) => _textField(
          controller: _smtpHostController,
          labelText: l10n.adminServerFieldSmtpHost,
          helperText: l10n.adminServerSmtpHostDescription,
          icon: Icons.dns_outlined,
        ),
      ),
      _SettingField(
        key: 'smtpPort',
        section: _SettingsSection.email,
        label: (l10n) => l10n.adminServerFieldSmtpPort,
        keywords: const ['smtp', 'port'],
        visible: () => _emailEnabled,
        pairKey: 'smtpServer',
        build: (context, l10n) => _integerField(
          controller: _smtpPortController,
          labelText: l10n.adminServerFieldSmtpPort,
          helperText: l10n.adminServerSmtpUseSslDescription,
          icon: Icons.settings_ethernet_outlined,
        ),
      ),
      _SettingField(
        key: 'smtpUseSsl',
        section: _SettingsSection.email,
        label: (l10n) => l10n.adminServerFieldSmtpUseSsl,
        keywords: const ['smtp', 'ssl', 'tls'],
        visible: () => _emailEnabled,
        build: (context, l10n) => _switchField(
          value: _smtpUseSsl,
          title: l10n.adminServerFieldSmtpUseSsl,
          subtitle: l10n.adminServerSmtpUseSslDescription,
          onChanged: (value) {
            setState(() => _smtpUseSsl = value);
            _handleFieldChanged();
          },
        ),
      ),
      _SettingField(
        key: 'verifyEmail',
        section: _SettingsSection.email,
        label: (l10n) => l10n.adminServerFieldVerifyEmail,
        keywords: const ['email', 'from'],
        visible: () => _emailEnabled,
        pairKey: 'emailCreds',
        build: (context, l10n) => _textField(
          controller: _verifyEmailController,
          labelText: l10n.adminServerFieldVerifyEmail,
          icon: Icons.alternate_email_outlined,
        ),
      ),
      _SettingField(
        key: 'emailPassword',
        section: _SettingsSection.email,
        label: (l10n) => l10n.adminServerFieldEmailPassword,
        keywords: const ['email', 'password'],
        visible: () => _emailEnabled,
        pairKey: 'emailCreds',
        build: (context, l10n) => _textField(
          controller: _emailPasswordController,
          labelText: l10n.adminServerFieldEmailPassword,
          icon: Icons.lock_outline,
          obscureText: true,
        ),
      ),
      // 反向代理
      _SettingField(
        key: 'reverseProxyEnabled',
        section: _SettingsSection.proxy,
        label: (l10n) => l10n.adminServerFieldReverseProxy,
        keywords: const ['proxy', 'nginx'],
        build: (context, l10n) => _switchField(
          value: _reverseProxyEnabled,
          title: l10n.adminServerFieldReverseProxy,
          subtitle: l10n.adminServerReverseProxyDescription,
          onChanged: (value) {
            setState(() => _reverseProxyEnabled = value);
            _handleFieldChanged();
          },
        ),
      ),
      _SettingField(
        key: 'proxyCount',
        section: _SettingsSection.proxy,
        label: (l10n) => l10n.adminServerFieldProxyCount,
        keywords: const ['proxy', 'count', 'layer'],
        visible: () => _reverseProxyEnabled,
        build: (context, l10n) => _integerField(
          controller: _proxyCountController,
          labelText: l10n.adminServerFieldProxyCount,
          icon: Icons.hub_outlined,
        ),
      ),
      // 认证与令牌
      _SettingField(
        key: 'legacyAuthEnabled',
        section: _SettingsSection.auth,
        label: (l10n) => l10n.adminServerFieldLegacyAuth,
        keywords: const ['legacy', 'auth', 'uid', 'password'],
        build: (context, l10n) => _switchField(
          value: _legacyAuthEnabled,
          title: l10n.adminServerFieldLegacyAuth,
          subtitle: l10n.adminServerLegacyAuthDescription,
          onChanged: (value) {
            setState(() => _legacyAuthEnabled = value);
            _handleFieldChanged();
          },
        ),
      ),
      _SettingField(
        key: 'jwtExpiresSeconds',
        section: _SettingsSection.auth,
        label: (l10n) => l10n.adminServerFieldJwtExpires,
        keywords: const ['jwt', 'token', 'expire'],
        pairKey: 'jwtExpiry',
        build: (context, l10n) => _integerField(
          controller: _jwtExpiresSecondsController,
          labelText: l10n.adminServerFieldJwtExpires,
          helperText: l10n.adminServerJwtExpiresDescription,
          icon: Icons.timer_outlined,
        ),
      ),
      _SettingField(
        key: 'jwtRefreshExpiresSeconds',
        section: _SettingsSection.auth,
        label: (l10n) => l10n.adminServerFieldJwtRefreshExpires,
        keywords: const ['jwt', 'refresh'],
        pairKey: 'jwtExpiry',
        build: (context, l10n) => _integerField(
          controller: _jwtRefreshExpiresSecondsController,
          labelText: l10n.adminServerFieldJwtRefreshExpires,
          helperText: l10n.adminServerJwtExpiresDescription,
          icon: Icons.autorenew_outlined,
        ),
      ),
      _SettingField(
        key: 'jwtMaxPerUser',
        section: _SettingsSection.auth,
        label: (l10n) => l10n.adminServerFieldJwtMaxPerUser,
        keywords: const ['jwt', 'token', 'device'],
        build: (context, l10n) => _unlimitedNumberField(
          key: 'jwtMaxPerUser',
          controller: _jwtMaxPerUserController,
          labelText: l10n.adminServerFieldJwtMaxPerUser,
          icon: Icons.devices_outlined,
        ),
      ),
      // 限流
      _SettingField(
        key: 'rateLimits',
        section: _SettingsSection.rateLimits,
        label: (l10n) => l10n.adminServerFieldRateLimits,
        keywords: const ['rate', 'limit', 'json'],
        build: (context, l10n) => _textField(
          controller: _rateLimitsController,
          labelText: l10n.adminServerFieldRateLimits,
          helperText: l10n.adminServerRateLimitsDescription,
          icon: Icons.speed_outlined,
          minLines: 3,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          alignLabelWithHint: true,
          style: const TextStyle(
            fontFamily: codeFontFamily,
            fontFamilyFallback: codeFontFamilyFallback,
            fontSize: 13,
          ),
        ),
      ),
      // 限制与存储
      _SettingField(
        key: 'minGroupNameLength',
        section: _SettingsSection.limits,
        label: (l10n) => l10n.adminServerFieldMinGroupNameLength,
        keywords: const ['group', 'name', 'min'],
        pairKey: 'groupNameLengths',
        build: (context, l10n) => _integerField(
          controller: _minGroupNameLengthController,
          labelText: l10n.adminServerFieldMinGroupNameLength,
          icon: Icons.group_outlined,
        ),
      ),
      _SettingField(
        key: 'maxGroupNameLength',
        section: _SettingsSection.limits,
        label: (l10n) => l10n.adminServerFieldMaxGroupNameLength,
        keywords: const ['group', 'name', 'max'],
        pairKey: 'groupNameLengths',
        build: (context, l10n) => _integerField(
          controller: _maxGroupNameLengthController,
          labelText: l10n.adminServerFieldMaxGroupNameLength,
          icon: Icons.group_outlined,
        ),
      ),
      _SettingField(
        key: 'minUsernameLength',
        section: _SettingsSection.limits,
        label: (l10n) => l10n.adminServerFieldMinUsernameLength,
        keywords: const ['username', 'min'],
        pairKey: 'credentialLengths',
        build: (context, l10n) => _integerField(
          controller: _minUsernameLengthController,
          labelText: l10n.adminServerFieldMinUsernameLength,
          icon: Icons.person_outline,
        ),
      ),
      _SettingField(
        key: 'minPasswordLength',
        section: _SettingsSection.limits,
        label: (l10n) => l10n.adminServerFieldMinPasswordLength,
        keywords: const ['password', 'min'],
        pairKey: 'credentialLengths',
        build: (context, l10n) => _integerField(
          controller: _minPasswordLengthController,
          labelText: l10n.adminServerFieldMinPasswordLength,
          icon: Icons.lock_outline,
        ),
      ),
      _SettingField(
        key: 'maxSignLength',
        section: _SettingsSection.limits,
        label: (l10n) => l10n.adminServerFieldMaxSignLength,
        keywords: const ['sign', 'signature'],
        build: (context, l10n) => _unlimitedNumberField(
          key: 'maxSignLength',
          controller: _maxSignLengthController,
          labelText: l10n.adminServerFieldMaxSignLength,
          icon: Icons.short_text,
        ),
      ),
      _SettingField(
        key: 'maxIntroductionLength',
        section: _SettingsSection.limits,
        label: (l10n) => l10n.adminServerFieldMaxIntroductionLength,
        keywords: const ['introduction', 'bio'],
        build: (context, l10n) => _unlimitedNumberField(
          key: 'maxIntroductionLength',
          controller: _maxIntroductionLengthController,
          labelText: l10n.adminServerFieldMaxIntroductionLength,
          icon: Icons.notes_outlined,
        ),
      ),
      _SettingField(
        key: 'maxPostContentLength',
        section: _SettingsSection.limits,
        label: (l10n) => l10n.adminServerFieldMaxPostContentLength,
        keywords: const ['post', 'content'],
        build: (context, l10n) => _unlimitedNumberField(
          key: 'maxPostContentLength',
          controller: _maxPostContentLengthController,
          labelText: l10n.adminServerFieldMaxPostContentLength,
          icon: Icons.article_outlined,
        ),
      ),
      _SettingField(
        key: 'maxAvatarSize',
        section: _SettingsSection.limits,
        label: (l10n) => l10n.adminServerFieldMaxAvatarSize,
        keywords: const ['avatar'],
        build: (context, l10n) => _unlimitedNumberField(
          key: 'maxAvatarSize',
          controller: _maxAvatarSizeController,
          labelText: l10n.adminServerFieldMaxAvatarSize,
          icon: Icons.account_circle_outlined,
        ),
      ),
      _SettingField(
        key: 'userStorageQuota',
        section: _SettingsSection.limits,
        label: (l10n) => l10n.adminServerFieldUserStorageQuota,
        keywords: const ['storage', 'quota'],
        pairKey: 'storageQuota',
        build: (context, l10n) => _unlimitedNumberField(
          key: 'userStorageQuota',
          controller: _userStorageQuotaController,
          labelText: l10n.adminServerFieldUserStorageQuota,
          icon: Icons.cloud_outlined,
        ),
      ),
      _SettingField(
        key: 'maxUserStorageQuota',
        section: _SettingsSection.limits,
        label: (l10n) => l10n.adminServerFieldMaxUserStorageQuota,
        keywords: const ['storage', 'upload', 'quota'],
        pairKey: 'storageQuota',
        build: (context, l10n) => _unlimitedNumberField(
          key: 'maxUserStorageQuota',
          controller: _maxUserStorageQuotaController,
          labelText: l10n.adminServerFieldMaxUserStorageQuota,
          icon: Icons.storage_outlined,
        ),
      ),
      _SettingField(
        key: 'maxStickerStorageQuota',
        section: _SettingsSection.limits,
        label: (l10n) => l10n.adminServerFieldMaxStickerStorageQuota,
        keywords: const ['sticker', 'storage', 'quota'],
        build: (context, l10n) => _unlimitedNumberField(
          key: 'maxStickerStorageQuota',
          controller: _maxStickerStorageQuotaController,
          labelText: l10n.adminServerFieldMaxStickerStorageQuota,
          icon: Icons.emoji_emotions_outlined,
        ),
      ),
      // 服务器信息（只读）
      _SettingField(
        key: 'portApi',
        section: _SettingsSection.serverInfo,
        label: (l10n) => l10n.adminServerFieldApiPort,
        keywords: const ['api', 'port'],
        visible: () => _settings != null,
        pairKey: 'serverPorts',
        build: (context, l10n) => _readOnlyTile(
          icon: Icons.api_outlined,
          label: l10n.adminServerFieldApiPort,
          value: '${_settings?.portApi ?? ''}',
        ),
      ),
      _SettingField(
        key: 'portTcp',
        section: _SettingsSection.serverInfo,
        label: (l10n) => l10n.adminServerFieldTcpPort,
        keywords: const ['tcp', 'port'],
        visible: () => _settings != null,
        pairKey: 'serverPorts',
        build: (context, l10n) => _readOnlyTile(
          icon: Icons.settings_ethernet_outlined,
          label: l10n.adminServerFieldTcpPort,
          value: '${_settings?.portTcp ?? ''}',
        ),
      ),
    ];
  }

  Widget _buildSectionNav(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: _SettingsSection.values.map((section) {
          final isSelected = _selectedSection == section;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              leading: Icon(_sectionIcon(section)),
              title: Text(_sectionTitle(l10n, section)),
              selected: isSelected,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              selectedTileColor: colorScheme.primaryContainer.withValues(
                alpha: 0.55,
              ),
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                _searchController.clear();
                setState(() => _selectedSection = section);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionDropdown(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<_SettingsSection>(
              isExpanded: true,
              value: _selectedSection,
              borderRadius: BorderRadius.circular(8),
              items: _SettingsSection.values
                  .map(
                    (section) => DropdownMenuItem(
                      value: section,
                      child: Row(
                        children: [
                          Icon(_sectionIcon(section), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _sectionTitle(l10n, section),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                FocusManager.instance.primaryFocus?.unfocus();
                _searchController.clear();
                setState(() => _selectedSection = value);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentPane(BuildContext context, AppLocalizations l10n) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) {
        final query = value.text.trim();
        final Widget child = query.isEmpty
            ? KeyedSubtree(
                key: ValueKey(_selectedSection),
                child: _buildSectionContent(context, l10n),
              )
            : KeyedSubtree(
                key: const ValueKey('search'),
                child: _buildSearchResults(context, l10n, query),
              );
        final animationsDisabled = MediaQuery.disableAnimationsOf(context);
        return AnimatedSwitcher(
          duration: animationsDisabled
              ? Duration.zero
              : const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: child,
        );
      },
    );
  }

  Widget _buildSectionContent(BuildContext context, AppLocalizations l10n) {
    final fields = [
      for (final field in _buildRegistry(l10n))
        if (field.section == _selectedSection && _isFieldVisible(field)) field,
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
        child: ListView(
          key: PageStorageKey<String>(
            'server-settings-${_selectedSection.name}',
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _buildSectionHeader(context, l10n, _selectedSection),
            const SizedBox(height: 16),
            if (fields.isNotEmpty)
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _buildFieldRows(
                        context,
                        l10n,
                        fields,
                        constraints.maxWidth,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFieldRows(
    BuildContext context,
    AppLocalizations l10n,
    List<_SettingField> fields,
    double width,
  ) {
    final rows = <Widget>[];
    var index = 0;
    while (index < fields.length) {
      final field = fields[index];
      final next = index + 1 < fields.length ? fields[index + 1] : null;
      final canPair =
          width >= _pairBreakpoint &&
          field.pairKey != null &&
          next != null &&
          next.pairKey == field.pairKey;
      if (canPair) {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: field.build(context, l10n)),
                const SizedBox(width: 12),
                Expanded(child: next.build(context, l10n)),
              ],
            ),
          ),
        );
        index += 2;
      } else {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: field.build(context, l10n),
          ),
        );
        index += 1;
      }
    }
    return rows;
  }

  Widget _buildSectionHeader(
    BuildContext context,
    AppLocalizations l10n,
    _SettingsSection section,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final description = _sectionDescription(l10n, section);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            _sectionIcon(section),
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _sectionTitle(l10n, section),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.adminServerSearchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l10n.cancel,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _searchController.clear,
                    ),
              isDense: true,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    AppLocalizations l10n,
    String query,
  ) {
    final q = query.toLowerCase();
    final matches = <_SettingField>[];
    for (final field in _buildRegistry(l10n)) {
      if (!_isFieldVisible(field)) continue;
      final label = field.label(l10n).toLowerCase();
      final sectionTitle = _sectionTitle(l10n, field.section).toLowerCase();
      final hit =
          label.contains(q) ||
          sectionTitle.contains(q) ||
          field.keywords.any((keyword) => keyword.toLowerCase().contains(q));
      if (hit) matches.add(field);
    }

    if (matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.adminServerSearchNoResults,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final field = matches[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionChip(context, l10n, field.section),
                    const SizedBox(height: 12),
                    field.build(context, l10n),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionChip(
    BuildContext context,
    AppLocalizations l10n,
    _SettingsSection section,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _sectionTitle(l10n, section),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSaveBar(BuildContext context, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Row(
            children: [
              if (_dirty) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.adminServerUnsavedChanges,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              TextButton(
                onPressed: _dirty && !_isSaving ? _undoChanges : null,
                child: Text(l10n.adminServerUndoChanges),
              ),
              const SizedBox(width: 8),
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
            ],
          ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = WideScreenHelper.isWideWithWidth(
          constraints.maxWidth,
        );
        if (!isWideScreen) {
          return Column(
            children: [
              _buildSectionDropdown(context),
              Expanded(child: _buildContentPane(context, l10n)),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: 240, child: _buildSectionNav(context)),
            const VerticalDivider(width: 1),
            Expanded(child: _buildContentPane(context, l10n)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showForm = _canManageServer && _settings != null;

    return PopScope(
      canPop: _allowPop || !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (_dirty && _settings != null) {
          final confirmed = await _confirmDiscard(
            l10n.adminServerDiscardChanges,
          );
          if (!confirmed || !mounted) return;
        }
        if (!mounted) return;
        setState(() => _allowPop = true);
        navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.adminServerSettings),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _attemptLeave,
          ),
          actions: [
            IconButton(
              onPressed: _isLoading ? null : _onRefreshRequested,
              tooltip: l10n.retry,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: showForm
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: _buildSearchBar(context),
                )
              : null,
        ),
        body: _buildBody(context),
        bottomNavigationBar: showForm ? _buildSaveBar(context, l10n) : null,
      ),
    );
  }
}

enum _SettingsSection {
  general,
  messages,
  files,
  groups,
  stickers,
  email,
  proxy,
  auth,
  rateLimits,
  limits,
  serverInfo,
}

/// 一条可搜索的设置字段：分区视图与搜索结果共用同一构建闭包。
class _SettingField {
  const _SettingField({
    required this.key,
    required this.section,
    required this.label,
    this.keywords = const [],
    this.pairKey,
    this.visible,
    required this.build,
  });

  final String key;
  final _SettingsSection section;
  final String Function(AppLocalizations) label;
  final List<String> keywords;
  final String? pairKey;
  final bool Function()? visible;
  final Widget Function(BuildContext context, AppLocalizations l10n) build;
}

/// 加载时的表单基线快照，用于脏检测与撤销。
class _Baseline {
  const _Baseline({
    required this.texts,
    required this.unlimitedOn,
    required this.scalars,
  });

  final Map<TextEditingController, String> texts;
  final Set<String> unlimitedOn;
  final Map<String, Object?> scalars;
}

/// 支持「不限」（-1）的数字字段：输入框 + 不限开关。
class _UnlimitedNumberField extends StatelessWidget {
  const _UnlimitedNumberField({
    required this.controller,
    required this.labelText,
    required this.icon,
    required this.unlimited,
    required this.onUnlimitedChanged,
  });

  final TextEditingController controller;
  final String labelText;
  final IconData icon;
  final bool unlimited;
  final ValueChanged<bool>? onUnlimitedChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !unlimited,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: InputDecoration(
              labelText: labelText,
              prefixIcon: Icon(icon),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          l10n.adminServerUnlimited,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Switch.adaptive(
          value: unlimited,
          onChanged: onUnlimitedChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}
