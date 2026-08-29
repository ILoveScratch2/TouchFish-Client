import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FlutterView;
import 'package:flutter/cupertino.dart'
    show CupertinoLocalizations, CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'package:virtual_keypad/virtual_keypad.dart';
import 'l10n/app_localizations.dart';
import 'models/app_state.dart';
import 'models/settings_service.dart';
import 'routes/app_routes.dart';
import 'services/auth_state.dart';
import 'services/font_loader_service.dart';
import 'services/api/tf_api_client.dart';
import 'services/rsa_key_trust_service.dart';
import 'services/app_notification_service.dart';
import 'services/chat_data_service.dart';
import 'services/chat_ws_service.dart';
import 'services/app_update_service.dart';
import 'services/app_update_flow.dart';
import 'services/background_permission_service.dart';
import 'services/desktop_app_lifecycle_service.dart';
import 'services/forum_pending_service.dart';
import 'services/single_instance_service.dart';
import 'services/notification_service.dart';
import 'services/server_connection_status_service.dart';
import 'services/ip_override_service.dart';
import 'services/lock_service.dart';
import 'services/lock_screen_visibility_service.dart';
import 'utils/talker.dart';
import 'widgets/app_alert_dialog.dart';
import 'widgets/rsa_key_prompts.dart';
import 'widgets/app_virtual_keyboard.dart';
import 'widgets/notification_overlay.dart';
import 'widgets/custom_title_bar.dart';
import 'widgets/server_connection_banner.dart';
import 'widgets/snackbar_overlay.dart';
import 'utils/web_splash_stub.dart'
    if (dart.library.js) 'utils/web_splash_web.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    registerTalkerErrorHandlers();
    MediaKit.ensureInitialized();
    initializeKeyboardLayouts();

    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    // 我们只能有一个 xsfx is running!
    if (isDesktop) {
      final isPrimary = await SingleInstanceService.instance
          .tryAcquireSingleInstance();
      if (!isPrimary) {
        talker.info('Exiting secondary TouchFish instance.');
        exit(0);
      }
    }

    final startupRecovery = await _performStartupRecovery(isDesktop: isDesktop);
    await SettingsService.instance.init();
    // 重新加载已配置的字体，避免重启后回退到系统默认字体。
    final configuredFont = AppState.instance.fontFamily;
    if (configuredFont != null && configuredFont.isNotEmpty) {
      await FontLoaderService.instance.loadFont(configuredFont);
    }
    await LockService.instance.init();
    await IpOverrideService.instance.ensureDefaultDomain();
    await IpOverrideService.instance.refreshGlobal();

    if (isDesktop) {
      await windowManager.ensureInitialized();
      // Windows Registry Editor Version 5.00
      // 直接 reg（注册也是 reg tray）
      await DesktopAppLifecycleService.instance.initialize();
      SingleInstanceService.instance.onShowWindowRequested = () {
        unawaited(DesktopAppLifecycleService.instance.showWindow());
      };
    }

    final prefs = await SharedPreferences.getInstance();

    if (isDesktop) {
      const defaultSize = Size(1280, 800);
      const minSize = Size(400, 700);
      final savedWidth = prefs.getDouble('window_width');
      final savedHeight = prefs.getDouble('window_height');
      final savedX = prefs.getDouble('window_x');
      final savedY = prefs.getDouble('window_y');
      final windowOpacity = SettingsService.instance.getValue<double>(
        'windowOpacity',
        1.0,
      );

      final initialSize = (savedWidth != null && savedHeight != null)
          ? Size(
              savedWidth < minSize.width ? defaultSize.width : savedWidth,
              savedHeight < minSize.height ? defaultSize.height : savedHeight,
            )
          : defaultSize;

      WindowOptions windowOptions = WindowOptions(
        size: initialSize,
        center: savedX == null || savedY == null,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
      );

      windowManager.waitUntilReadyToShow(windowOptions, () async {
        if (Platform.isLinux) {
          final env = Platform.environment;
          final isWayland = env.containsKey('WAYLAND_DISPLAY');
          if (isWayland) {
            await windowManager.setAsFrameless();
          }
        }
        if (savedX != null && savedY != null) {
          await windowManager.setPosition(Offset(savedX, savedY));
        }

        await windowManager.setMinimumSize(minSize);
        await windowManager.setOpacity(windowOpacity);
        // reactNATIVE
        await DesktopAppLifecycleService.instance.afterWindowReady();
        await DesktopAppLifecycleService.instance.restoreWindowState();
        // 上次退出时窗口隐藏在托盘里：本次启动直接驻留托盘，不显示窗口
        // （可通过托盘菜单或再次启动唤出）。
        if (!DesktopAppLifecycleService.instance.wasHiddenInTray) {
          await windowManager.show();
          await windowManager.focus();
        }
      });
    }

    final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
    await AuthState.instance.init();
    final hasSavedSession = AuthState.instance.hasStoredCredentials;

    talker.info('TouchFish Client started!');

    runApp(
      TouchFishApp(
        isFirstLaunch: isFirstLaunch,
        hasSavedSession: hasSavedSession,
        didResetLocalSettings: startupRecovery.didResetSharedPreferences,
      ),
    );

    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        removeWebSplash();
      });
    }
  }, logUnhandledAsyncError);
}

Future<_StartupRecoveryResult> _performStartupRecovery({
  required bool isDesktop,
}) async {
  final didResetSharedPreferences = isDesktop
      ? await _repairSharedPreferencesFileIfCorrupted()
      : false;

  final prefs = await SharedPreferences.getInstance();
  final didResetWindowPosition = isDesktop
      ? await _resetWindowPositionIfFarOutsideScreen(prefs)
      : false;

  return _StartupRecoveryResult(
    didResetSharedPreferences: didResetSharedPreferences,
    didResetWindowPosition: didResetWindowPosition,
  );
}

Future<bool> _repairSharedPreferencesFileIfCorrupted() async {
  try {
    final supportDirectory = await getApplicationSupportDirectory();
    final preferencesFile = File(
      '${supportDirectory.path}${Platform.pathSeparator}shared_preferences.json',
    );

    if (!await preferencesFile.exists()) {
      return false;
    }

    final rawText = await preferencesFile.readAsString();
    if (rawText.trim().isEmpty) {
      return false;
    }

    final decoded = jsonDecode(rawText);
    if (decoded is Map) {
      return false;
    }

    await preferencesFile.writeAsString('{}', flush: true);
    talker.warning(
      'Shared preferences file had an invalid root JSON value and was reset.',
    );
    return true;
  } on FormatException catch (error, stackTrace) {
    try {
      final supportDirectory = await getApplicationSupportDirectory();
      final preferencesFile = File(
        '${supportDirectory.path}${Platform.pathSeparator}shared_preferences.json',
      );
      await preferencesFile.writeAsString('{}', flush: true);
    } catch (writeError, writeStackTrace) {
      talker.error(
        'Failed to rewrite corrupted shared preferences file.',
        writeError,
        writeStackTrace,
      );
      return false;
    }

    talker.error(
      'Shared preferences JSON parse failed and the file was reset.',
      error,
      stackTrace,
    );
    return true;
  } catch (error, stackTrace) {
    talker.error(
      'Failed while checking shared preferences file integrity.',
      error,
      stackTrace,
    );
    return false;
  }
}

Future<bool> _resetWindowPositionIfFarOutsideScreen(
  SharedPreferences prefs,
) async {
  final savedX = prefs.getDouble('window_x');
  final savedY = prefs.getDouble('window_y');

  if (savedX == null || savedY == null) {
    return false;
  }

  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) {
    return false;
  }

  final screenBounds = _tryGetPrimaryDisplayLogicalSize(views.first);
  if (screenBounds == null) {
    return false;
  }

  final screenWidth = screenBounds.width;
  final screenHeight = screenBounds.height;
  final savedWidth = prefs.getDouble('window_width') ?? 1280;
  final savedHeight = prefs.getDouble('window_height') ?? 800;

  final allowedBounds = Rect.fromLTWH(
    -screenWidth,
    -screenHeight,
    screenWidth * 3,
    screenHeight * 3,
  );
  final windowBounds = Rect.fromLTWH(savedX, savedY, savedWidth, savedHeight);

  if (windowBounds.overlaps(allowedBounds)) {
    return false;
  }

  await prefs.remove('window_x');
  await prefs.remove('window_y');
  talker.warning(
    'Saved window position was far outside the current screen bounds and was reset.',
  );
  return true;
}

Size? _tryGetPrimaryDisplayLogicalSize(FlutterView view) {
  try {
    final display = view.display;
    final devicePixelRatio = display.devicePixelRatio == 0
        ? 1.0
        : display.devicePixelRatio;
    return Size(
      display.size.width / devicePixelRatio,
      display.size.height / devicePixelRatio,
    );
  } on AssertionError {
    talker.debug(
      'Skipping saved window position recovery because display information is not ready yet.',
    );
    return null;
  }
}

class _StartupRecoveryResult {
  final bool didResetSharedPreferences;
  final bool didResetWindowPosition;

  const _StartupRecoveryResult({
    required this.didResetSharedPreferences,
    required this.didResetWindowPosition,
  });
}

/// Provides Material localizations for the [och] language code by proxying
/// to Simplified Chinese, since [GlobalMaterialLocalizations] does not support
/// ISO 639-3 codes like [och].
class _OchMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _OchMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'och';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('zh'));

  @override
  bool shouldReload(_OchMaterialLocalizationsDelegate old) => false;
}

/// Provides Cupertino localizations for the [och] language code by proxying
/// to Simplified Chinese, for the same reason as [_OchMaterialLocalizationsDelegate].
class _OchCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _OchCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'och';

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('zh'));

  @override
  bool shouldReload(_OchCupertinoLocalizationsDelegate old) => false;
}

class TouchFishApp extends StatefulWidget {
  final bool isFirstLaunch;
  final bool hasSavedSession;
  final bool didResetLocalSettings;

  const TouchFishApp({
    super.key,
    required this.isFirstLaunch,
    required this.hasSavedSession,
    this.didResetLocalSettings = false,
  });

  @override
  State<TouchFishApp> createState() => _TouchFishAppState();
}

class _TouchFishAppState extends State<TouchFishApp>
    with WidgetsBindingObserver {
  final _appState = AppState.instance;
  late final _appListenable = Listenable.merge([
    _appState,
    AuthState.instance.sessionListenable,
  ]);
  late final _router = AppRoutes.createRouter(
    isFirstLaunch: widget.isFirstLaunch,
    hasSavedSession: widget.hasSavedSession,
  );
  bool _didShowStartupResetNotice = false;
  bool _didStartSavedSessionRestore = false;
  late bool _wasLoggedIn;
  RsaKeyCheckResult? _pendingRestoreKeyCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wasLoggedIn = AuthState.instance.isLoggedIn;
    AuthState.instance.sessionListenable.addListener(_onAuthStateChanged);
    unawaited(AppNotificationService.instance.initialize(_router));
    BackgroundPermissionService.instance.installNotificationRouteHandler();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_openPendingNotificationRoute());
      _startSavedSessionRestoreIfNeeded();
      _startNotificationPollingIfLoggedIn();
      unawaited(_runStartupChecks());
      if (!kIsWeb && Platform.isAndroid) {
        unawaited(LockScreenVisibilityService.instance.applyFromSettings());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !kIsWeb && Platform.isAndroid) {
      unawaited(LockScreenVisibilityService.instance.applyFromSettings());
    }
  }

  Future<void> _runStartupChecks() async {
    // Android: request background (battery-optimization) permission.
    if (!kIsWeb && Platform.isAndroid) {
      unawaited(
        BackgroundPermissionService.instance.requestBackgroundPermissions(),
      );
    }

    // Non-web: check for updates once per launch.
    if (!kIsWeb) {
      final result = await AppUpdateService.instance.checkForUpdate();
      if (!mounted || !result.hasUpdate) return;
      final navigatorContext =
          _router.routerDelegate.navigatorKey.currentContext;
      if (navigatorContext == null || !navigatorContext.mounted) return;
      await AppUpdateFlow.instance.promptIfNeeded(
        navigatorContext,
        remoteVersion: result.remoteVersion,
        currentVersion: result.currentVersion,
      );
    }
  }

  void _startNotificationPollingIfLoggedIn() {
    if (AuthState.instance.isLoggedIn) {
      unawaited(ChatDataService.instance.init());
      unawaited(ChatWsService.instance.connect());
      NotificationService.instance.startPolling();
      ForumPendingService.instance.startPolling();
      _startAndroidBackgroundServiceIfNeeded();
    }
  }

  void _startAndroidBackgroundServiceIfNeeded() {
    if (kIsWeb || !Platform.isAndroid) return;
    unawaited(_configureAndStartAndroidBackgroundService());
  }

  Future<void> _openPendingNotificationRoute() async {
    final route = await BackgroundPermissionService.instance
        .takePendingNotificationRoute();
    if (route != null && route.startsWith('/')) {
      AppNotificationService.instance.openRoute(route, replace: true);
    }
  }

  Future<void> _configureAndStartAndroidBackgroundService() async {
    final configured = await BackgroundPermissionService.instance
        .syncBackgroundServiceConfig();
    if (!configured) return;
    await BackgroundPermissionService.instance.startBackgroundService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AuthState.instance.sessionListenable.removeListener(_onAuthStateChanged);
    NotificationService.instance.stopPolling();
    ForumPendingService.instance.stopPolling();
    super.dispose();
  }

  void _onAuthStateChanged() {
    final isLoggedIn = AuthState.instance.isLoggedIn;
    if (isLoggedIn == _wasLoggedIn) return;
    _wasLoggedIn = isLoggedIn;

    if (isLoggedIn) {
      _startNotificationPollingIfLoggedIn();
    } else {
      NotificationService.instance.stopPolling();
      ForumPendingService.instance.stopPolling();
      AppNotificationService.instance.clear();
      unawaited(ChatWsService.instance.disconnect());
      unawaited(ChatDataService.instance.reset());
      unawaited(_stopAndroidBackgroundService());
    }
  }

  Future<void> _stopAndroidBackgroundService() async {
    await BackgroundPermissionService.instance.stopBackgroundService();
    await BackgroundPermissionService.instance.clearBackgroundServiceConfig();
  }

  Future<void> _startSavedSessionRestoreIfNeeded() async {
    if (!widget.hasSavedSession || _didStartSavedSessionRestore) {
      return;
    }

    _didStartSavedSessionRestore = true;

    final navigatorContext = _router.routerDelegate.navigatorKey.currentContext;
    if (navigatorContext == null || !navigatorContext.mounted) {
      unawaited(AuthState.instance.restoreSavedSession());
      return;
    }

    // RSA 密钥变更时先让用户决策，避免用旧密钥登录失败后无法提示。
    final canRestore = await _verifyRsaKeyForSessionRestore(navigatorContext);
    if (!canRestore) return;

    final restored = await AuthState.instance.restoreSavedSession();
    if (!restored || !mounted) return;

    _maybePromptFirstConnectAfterRestore(navigatorContext);
  }

  /// 已保存会话恢复前的 RSA 密钥校验；返回 false 表示用户选择断开。
  Future<bool> _verifyRsaKeyForSessionRestore(BuildContext context) async {
    try {
      final livePem = await TfApiClient.instance.fetchRsaPublicKeyPem();
      final result = await RsaKeyTrustService.instance.checkKey(livePem);
      result.log();
      if (result.kind == RsaKeyCheckKind.changed) {
        final replaced = await promptRsaKeyChanged(
          context,
          newSha: result.liveFingerprint!,
          oldSha: result.savedFingerprint ?? '',
        );
        if (replaced) {
          await RsaKeyTrustService.instance.saveKey(result.livePem!);
          return true;
        }
        return false;
      }
      if (result.kind == RsaKeyCheckKind.firstTime) {
        _pendingRestoreKeyCheck = result;
      }
      return true;
    } catch (e, stackTrace) {
      talker.warning(
        'RSA key verification before session restore failed',
        e,
        stackTrace,
      );
      return true;
    }
  }

  /// 恢复成功后若为首次连接，提示保存 RSA 密钥。
  void _maybePromptFirstConnectAfterRestore(BuildContext context) {
    final result = _pendingRestoreKeyCheck;
    _pendingRestoreKeyCheck = null;
    if (result == null ||
        result.kind != RsaKeyCheckKind.firstTime ||
        result.dismissed ||
        result.livePem == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final choice = await promptRsaFirstConnect(
        context,
        sha: result.liveFingerprint!,
      );
      switch (choice) {
        case RsaFirstConnectChoice.save:
          await RsaKeyTrustService.instance.saveKey(result.livePem!);
        case RsaFirstConnectChoice.dontSave:
          await RsaKeyTrustService.instance.dismissKey();
        case RsaFirstConnectChoice.disconnect:
          await AuthState.instance.logout();
      }
    });
  }

  void _showStartupResetNoticeIfNeeded(BuildContext context) {
    final restoreStatus = AuthState.instance.savedSessionRestoreStatus;
    if (_didShowStartupResetNotice ||
        !widget.didResetLocalSettings ||
        restoreStatus == SavedSessionRestoreStatus.restoring ||
        restoreStatus == SavedSessionRestoreStatus.failed) {
      return;
    }

    _didShowStartupResetNotice = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final l10n = AppLocalizations.of(context);
      if (l10n == null) return;

      showTouchFishInfoDialog<void>(
        context,
        message: l10n.settingsCorruptedResetNotice,
        icon: Icons.settings_suggest_rounded,
      );
    });
  }

  Widget _buildSavedSessionRestoreOverlay(BuildContext context, Widget child) {
    final status = AuthState.instance.savedSessionRestoreStatus;
    if (!widget.hasSavedSession ||
        (status != SavedSessionRestoreStatus.restoring &&
            status != SavedSessionRestoreStatus.failed)) {
      return child;
    }

    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return child;
    }

    final dialog = status == SavedSessionRestoreStatus.restoring
        ? _buildSavedSessionLoadingDialog(context, l10n)
        : _buildSavedSessionFailureDialog(context, l10n);

    return Stack(
      children: [
        child,
        const ModalBarrier(dismissible: false, color: Colors.black54),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: dialog,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedSessionLoadingDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return buildTouchFishInfoDialog(
      context,
      title: l10n.savedSessionRestoreConnectingTitle,
      icon: Icons.cloud_sync_rounded,
      addDefaultActionWhenEmpty: false,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.savedSessionRestoreConnectingMessage,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSavedSessionFailureDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return buildTouchFishErrorDialog(
      context,
      title: l10n.savedSessionRestoreFailedTitle,
      message: l10n.savedSessionRestoreFailedMessage,
      icon: Icons.cloud_off_rounded,
      selectableMessage: false,
      addDefaultActionWhenEmpty: false,
      actionWidgets: [
        TextButton(
          onPressed: () {
            AuthState.instance.clearSavedSessionRestoreFailure();
            _router.go(AppRoutes.login);
          },
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
        FilledButton(
          onPressed: () {
            unawaited(AuthState.instance.restoreSavedSession());
          },
          child: Text(l10n.retry),
        ),
      ],
    );
  }

  Widget _buildServerConnectionOverlay(BuildContext context, Widget child) {
    final hasDesktopWindowFrame =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    return ListenableBuilder(
      listenable: Listenable.merge([
        ServerConnectionStatusService.instance,
        AppVirtualKeyboard.keyboardInset,
      ]),
      builder: (context, _) {
        final service = ServerConnectionStatusService.instance;
        final keyboardInset = AppVirtualKeyboard.keyboardInset.value;
        final resizedChild = keyboardInset > 0
            ? MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  viewInsets: MediaQuery.of(context).viewInsets.copyWith(
                    bottom:
                        MediaQuery.of(context).viewInsets.bottom +
                        keyboardInset,
                  ),
                ),
                child: child,
              )
            : child;

        return Stack(
          children: [
            resizedChild,
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    (hasDesktopWindowFrame ? CustomTitleBar.height : 0) + 12,
                    16,
                    12,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                        reverseCurve: Curves.easeInCubic,
                      );
                      return FadeTransition(
                        opacity: curved,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, -0.2),
                            end: Offset.zero,
                          ).animate(curved),
                          child: child,
                        ),
                      );
                    },
                    child: service.isVisible && AuthState.instance.isLoggedIn
                        ? ServerConnectionBanner(
                            key: ValueKey(service.phase),
                            phase: service.phase,
                            onTap:
                                service.phase ==
                                    ServerConnectionBannerPhase.disconnected
                                ? () {
                                    unawaited(
                                      ServerConnectionStatusService.instance
                                          .retryConnection(),
                                    );
                                  }
                                : null,
                          )
                        : const SizedBox.shrink(key: ValueKey('hidden')),
                  ),
                ),
              ),
            ),
            const AppNotificationOverlay(),
            const AppVirtualKeyboard(),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appListenable,
      builder: (context, _) {
        final isCustomTheme = _appState.themeColorKey == 'custom';
        final seedColor = _appState.themeColor;
        var lightColorScheme = ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        );
        var darkColorScheme = ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        );
        final customColors = _appState.customColors;
        if (isCustomTheme && customColors != null) {
          lightColorScheme = _applyCustomColors(lightColorScheme, customColors);
          darkColorScheme = _applyCustomColors(darkColorScheme, customColors);
        }
        final cardOpacity = _appState.cardOpacity;
        final backgroundImagePath = _appState.backgroundImagePath;
        final hasBackgroundImage =
            backgroundImagePath != null && backgroundImagePath.isNotEmpty;

        return MaterialApp.router(
          routerConfig: _router,
          onGenerateTitle: (context) =>
              AppLocalizations.of(context)?.appName ?? '',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            _OchMaterialLocalizationsDelegate(),
            _OchCupertinoLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('zh'), Locale('och')],
          locale: _appState.locale,
          theme: ThemeData(
            colorScheme: lightColorScheme,
            useMaterial3: true,
            fontFamily: _appState.fontFamily,
            scaffoldBackgroundColor: hasBackgroundImage
                ? Colors.transparent
                : null,
            cardTheme: CardThemeData(
              color: lightColorScheme.surfaceContainer.withValues(
                alpha: cardOpacity,
              ),
              elevation: cardOpacity < 1 ? 0 : null,
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: ZoomPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
              },
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            useMaterial3: true,
            fontFamily: _appState.fontFamily,
            scaffoldBackgroundColor: hasBackgroundImage
                ? Colors.transparent
                : null,
            cardTheme: CardThemeData(
              color: darkColorScheme.surfaceContainer.withValues(
                alpha: cardOpacity,
              ),
              elevation: cardOpacity < 1 ? 0 : null,
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: ZoomPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
              },
            ),
          ),
          themeMode: _appState.themeMode,
          builder: (context, child) {
            _showStartupResetNoticeIfNeeded(context);
            final content = _buildServerConnectionOverlay(
              context,
              child ?? const SizedBox.shrink(),
            );
            if (hasBackgroundImage && !kIsWeb) {
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: !_appState.animationsEnabled),
                child: TouchFishSnackbarOverlay(
                  child: _buildSavedSessionRestoreOverlay(
                    context,
                    Container(
                      color: Theme.of(context).colorScheme.surface,
                      child: Container(
                        decoration: BoxDecoration(
                          backgroundBlendMode: BlendMode.darken,
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.85),
                          image: DecorationImage(
                            opacity: 0.2,
                            image: FileImage(File(backgroundImagePath)),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: content,
                      ),
                    ),
                  ),
                ),
              );
            }
            final animationsEnabled = _appState.animationsEnabled;
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: !animationsEnabled),
              child: TouchFishSnackbarOverlay(
                child: _buildSavedSessionRestoreOverlay(context, content),
              ),
            );
          },
        );
      },
    );
  }

  ColorScheme _applyCustomColors(
    ColorScheme scheme,
    Map<String, int> customColors,
  ) {
    final surfaceColor = customColors['surface'] ?? customColors['background'];

    return scheme.copyWith(
      primary: customColors['primary'] != null
          ? Color(customColors['primary']!)
          : null,
      secondary: customColors['secondary'] != null
          ? Color(customColors['secondary']!)
          : null,
      tertiary: customColors['tertiary'] != null
          ? Color(customColors['tertiary']!)
          : null,
      surface: surfaceColor != null ? Color(surfaceColor) : null,
      error: customColors['error'] != null
          ? Color(customColors['error']!)
          : null,
    );
  }
}
