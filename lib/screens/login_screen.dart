import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../l10n/app_localizations.dart';
import '../routes/app_routes.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/external_auth_service.dart';
import '../services/rsa_key_trust_service.dart';
import '../services/server_branding_service.dart';
import '../services/snackbar_service.dart';
import '../widgets/external_auth_sheet.dart';
import '../widgets/rsa_key_prompts.dart';
import '../widgets/server_selector.dart';
import '../widgets/network_indicator.dart';
import '../widgets/provider_mark.dart';
import '../utils/talker.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  RsaKeyCheckResult? _pendingFirstConnectResult;
  bool? _allowRegister;

  @override
  void initState() {
    super.initState();
    _usernameController.text =
        AuthState.instance.rememberedUsername ??
        AuthState.instance.currentUser?.username ??
        '';
    _passwordController.text = AuthState.instance.rememberedPassword ?? '';
    _initConnectivity();
    _subscribeToConnectivityChanges();
    unawaited(ServerBrandingService.instance.refresh());
    unawaited(ExternalAuthService.instance.load());
    unawaited(
      TfApiClient.instance.fetchServerInfo().then((config) {
        if (!mounted || config == null) return;
        setState(() => _allowRegister = config.allowRegister);
      }).catchError((_) {}),
    );
  }

  /// 切服务器后重拉与新服务器相关的可见性数据
  void _onServerChanged() {
    unawaited(_refreshServerDependent());
  }

  Future<void> _refreshServerDependent() async {
    await ExternalAuthService.instance.load(force: true);
    final config = await TfApiClient.instance.fetchServerInfo();
    if (!mounted) return;
    setState(() => _allowRegister = config?.allowRegister ?? _allowRegister);
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (!mounted) return;
      setState(() {
        _connectionStatus = result;
      });
    } catch (e) {
      talker.error('Failed to check connectivity', e);
    }
  }

  void _subscribeToConnectivityChanges() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      if (!mounted) return;
      setState(() {
        _connectionStatus = result;
      });
    });
  }

  bool get _isConnectedToInternet {
    return _connectionStatus.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet,
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final l10n = AppLocalizations.of(context)!;

    if (username.isEmpty || password.isEmpty) {
      TouchFishSnackbarService.instance.show(l10n.loginErrorEmptyFields);
      return;
    }

    setState(() => _isLoading = true);

    final keyOk = await _verifyRsaKeyBeforeLogin();
    if (!mounted) return;
    if (!keyOk) {
      setState(() => _isLoading = false);
      return;
    }

    final error = await AuthState.instance.login(username, password);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      // 自动降级为旧版认证时提示一次
      if (AuthState.instance.degradedToLegacy) {
        TouchFishSnackbarService.instance.show(l10n.loginDegradedToLegacy);
      }
      final shouldContinue = await _maybePromptFirstConnect();
      if (!mounted || !shouldContinue) return;
      context.go(AppRoutes.main);
    } else {
      final msg = switch (error) {
        'userNotFound' => l10n.loginErrorUserNotFound,
        'invalidCredentials' => l10n.loginErrorInvalidCredentials,
        'sessionLimitReached' => l10n.loginErrorSessionLimit,
        'duplicateLogin' => l10n.loginErrorDuplicateInstance,
        'networkError' => l10n.loginErrorNetwork,
        _ => l10n.loginErrorNetwork,
      };
      TouchFishSnackbarService.instance.show(msg);
    }
  }

  /// 通过外部登录平台（TouchFish Auth）登录。
  Future<void> _loginWithExternalAuth({String? providerId}) async {
    final l10n = AppLocalizations.of(context)!;
    final service = ExternalAuthService.instance;
    final config = await service.load(force: true);
    if (!mounted) return;
    if (config == null || config.methods.isEmpty) {
      TouchFishSnackbarService.instance.show(l10n.loginErrorNetwork);
      return;
    }

    final keyOk = await _verifyRsaKeyBeforeLogin();
    if (!mounted) return;
    if (!keyOk) return;

    final state = _randomStateToken();
    final baseUrl = await TfApiClient.instance.getBaseUrl();
    final uri = providerId == null
        ? service.buildAuthorizeUri(state: state, target: baseUrl)
        : service.buildProviderStartUri(
            providerId: providerId,
            state: state,
            target: baseUrl,
          );
    if (uri == null || !mounted) {
      TouchFishSnackbarService.instance.show(l10n.loginErrorNetwork);
      return;
    }

    final providerName = providerId == null
        ? 'TouchFish Auth'
        : config.methodById(providerId)?.displayName ?? providerId;
    final result = await ExternalAuthSheet.show(
      context,
      uri,
      title: providerName,
      allowedHosts: providerId == null
          ? const []
          : service.allowedHostsFor(providerId),
    );
    if (!mounted) return;
    if (result == null) return; // 用户关闭了授权页

    if (result.state == null || result.state != state) {
      // 严格要求回传的 state 与本机生成的一致
      TouchFishSnackbarService.instance.show(l10n.loginErrorNetwork);
      return;
    }

    setState(() => _isLoading = true);
    final externalToken = await service.exchangeTicket(result.ticket);
    if (!mounted) return;
    if (externalToken == null) {
      setState(() => _isLoading = false);
      TouchFishSnackbarService.instance.show(l10n.loginErrorTicketExchange);
      return;
    }

    final error = await AuthState.instance.loginWithExternalSession(externalToken);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      final shouldContinue = await _maybePromptFirstConnect();
      if (!mounted || !shouldContinue) return;
      context.go(AppRoutes.main);
      return;
    }

    final msg = switch (error) {
      'externalNotLinked' => l10n.loginErrorExternalNotLinked,
      'externalTokenInvalid' => l10n.loginErrorExternalTokenInvalid,
      'userBanned' => l10n.loginErrorInvalidCredentials,
      'sessionLimitReached' => l10n.loginErrorSessionLimit,
      'duplicateLogin' => l10n.loginErrorDuplicateInstance,
      _ => l10n.loginErrorNetwork,
    };
    TouchFishSnackbarService.instance.show(msg);
  }

  Widget _providerIconButton(
    BuildContext context,
    TfExternalAuthProvider provider,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 44,
      height: 44,
      child: OutlinedButton(
        onPressed: _isLoading
            ? null
            : () => _loginWithExternalAuth(providerId: provider.id),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          // 默认 tap target 会把按钮撑到 48 高，与外面的 44 方块打架
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const CircleBorder(),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: ProviderMark(
          providerId: provider.id,
          size: 20,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _providerNameButton(
    BuildContext context,
    TfExternalAuthProvider provider,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: SizedBox(
        height: 44,
        child: OutlinedButton(
          onPressed: _isLoading
              ? null
              : () => _loginWithExternalAuth(providerId: provider.id),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            minimumSize: const Size(0, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const StadiumBorder(),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Text(
            provider.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  String _randomStateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// 登录前校验 RSA 密钥
  Future<bool> _verifyRsaKeyBeforeLogin() async {
    try {
      final livePem = await TfApiClient.instance.fetchRsaPublicKeyPem();
      final result = await RsaKeyTrustService.instance.checkKey(livePem);
      result.log();
      if (result.kind == RsaKeyCheckKind.changed) {
        return _promptKeyChanged(result);
      }
      if (result.kind == RsaKeyCheckKind.firstTime) {
        _pendingFirstConnectResult = result;
      }
      return true;
    } catch (e, stackTrace) {
      talker.warning('RSA key verification before login failed', e, stackTrace);
      return true;
    }
  }

  Future<bool> _maybePromptFirstConnect() async {
    final result = _pendingFirstConnectResult;
    _pendingFirstConnectResult = null;
    if (result == null ||
        result.kind != RsaKeyCheckKind.firstTime ||
        result.dismissed ||
        result.livePem == null) {
      return true;
    }

    final choice = await promptRsaFirstConnect(
      context,
      sha: result.liveFingerprint!,
    );
    if (!mounted) return false;

    switch (choice) {
      case RsaFirstConnectChoice.save:
        await RsaKeyTrustService.instance.saveKey(result.livePem!);
        return true;
      case RsaFirstConnectChoice.dontSave:
        await RsaKeyTrustService.instance.dismissKey();
        return true;
      case RsaFirstConnectChoice.disconnect:
        await AuthState.instance.logout();
        return false;
    }
  }

  /// 密钥变更警告
  Future<bool> _promptKeyChanged(RsaKeyCheckResult result) async {
    final replaced = await promptRsaKeyChanged(
      context,
      newSha: result.liveFingerprint!,
      oldSha: result.savedFingerprint ?? '',
    );
    if (!mounted) return false;
    if (replaced) {
      await RsaKeyTrustService.instance.saveKey(result.livePem!);
      return true;
    }
    return false;
  }

  Widget _buildLoginLogo() {
    final branding = ServerBrandingService.instance;
    final logoUrl = branding.logoUrl;
    if (logoUrl == null || logoUrl.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/logo.png',
          width: 64,
          height: 64,
          fit: BoxFit.contain,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 64,
        height: 64,
        color: Colors.white,
        padding: const EdgeInsets.all(6),
        child: Image.network(
          logoUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            'assets/logo.png',
            width: 64,
            height: 64,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  void _register() {
    context.push(
      AppRoutes.register,
      extra: {
        'username': _usernameController.text.trim().isEmpty
            ? null
            : _usernameController.text,
        'password': _passwordController.text.trim().isEmpty
            ? null
            : _passwordController.text,
      },
    );
  }

  void _openSettings() {
    context.push(AppRoutes.settings);
  }

  void _showNetworkStatus() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildNetworkStatusSheet(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
  }

  Widget _buildNetworkStatusSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _isConnectedToInternet
                  ? colorScheme.primaryContainer
                  : colorScheme.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: NetworkIndicator(
                size: 48,
                isConnected: _isConnectedToInternet,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.networkStatusTitle,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _isConnectedToInternet
                ? l10n.networkStatusConnected
                : l10n.networkStatusDisconnected,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _isConnectedToInternet
                  ? colorScheme.primary
                  : colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: Center(
              child: Text(
                _isConnectedToInternet
                    ? l10n.networkStatusConnectedDesc
                    : l10n.networkStatusDisconnectedDesc,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: ServerBrandingService.instance,
          builder: (context, _) {
            final branding = ServerBrandingService.instance;
            return Text(
              branding.serverName ?? AppLocalizations.of(context)!.appName,
            );
          },
        ),
        actions: [
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppLocalizations.of(context)!.settingsTooltip,
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: SizedBox(
              width: 400,
              child: Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo + 服务器品牌标题
                      ListenableBuilder(
                        listenable: ServerBrandingService.instance,
                        builder: (context, _) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildLoginLogo(),
                              const SizedBox(height: 16),
                              Text(
                                ServerBrandingService.instance.serverName ??
                                    AppLocalizations.of(context)!.appName,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Server selector
                      ServerSelector(onServerChanged: _onServerChanged),
                      const SizedBox(height: 24),

                      // Username field
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          )!.loginUsername,
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),

                      // Password field
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          )!.loginPassword,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _isLoading ? null : _login(),
                      ),
                      const SizedBox(height: 24),

                      // Login button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(AppLocalizations.of(context)!.loginLogin),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 外部登录平台
                      ListenableBuilder(
                        listenable: ExternalAuthService.instance,
                        builder: (context, _) {
                          final service = ExternalAuthService.instance;
                          if (!service.isAvailable && !service.isConfigured) {
                            return const SizedBox.shrink();
                          }
                          final providers = service.providers;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: _isLoading
                                        ? null
                                        : () => _loginWithExternalAuth(),
                                    icon: const Icon(
                                      Icons.verified_user_outlined,
                                    ),
                                    label: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.loginExternalAuth,
                                    ),
                                  ),
                                ),
                                if (providers.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const Expanded(child: Divider()),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Text(
                                          AppLocalizations.of(context)!.loginOr,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ),
                                      const Expanded(child: Divider()),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      for (final provider in providers)
                                        Tooltip(
                                          message: provider.name,
                                          child: hasProviderIcon(provider.id)
                                              ? _providerIconButton(
                                                  context,
                                                  provider,
                                                )
                                              : _providerNameButton(
                                                  context,
                                                  provider,
                                                ),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),

                      // Register button（服务器关闭注册时不显示）
                      if (_allowRegister != false) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _register,
                            child: Text(
                              AppLocalizations.of(context)!.loginRegister,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],

                      // Forgot password
                      TextButton(
                        onPressed: () =>
                            context.push(AppRoutes.forgotPassword),
                        child: Text(
                          AppLocalizations.of(context)!.loginForgotPassword,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            right: 24,
            bottom: 24,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showNetworkStatus,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: NetworkIndicator(
                    size: 24,
                    isConnected: _isConnectedToInternet,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
