import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FlutterView;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'l10n/app_localizations.dart';
import 'models/app_state.dart';
import 'models/settings_service.dart';
import 'routes/app_routes.dart';
import 'services/auth_state.dart';
import 'services/server_connection_status_service.dart';
import 'utils/talker.dart';
import 'widgets/app_alert_dialog.dart';
import 'widgets/custom_title_bar.dart';
import 'widgets/server_connection_banner.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    registerTalkerErrorHandlers();
    MediaKit.ensureInitialized();

    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final startupRecovery = await _performStartupRecovery(isDesktop: isDesktop);
    await SettingsService.instance.init();

    if (isDesktop) {
      await windowManager.ensureInitialized();
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
          ? Size(savedWidth, savedHeight)
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
        await windowManager.show();
        await windowManager.focus();
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

class _TouchFishAppState extends State<TouchFishApp> {
  final _appState = AppState.instance;
  late final _appListenable = Listenable.merge([_appState, AuthState.instance]);
  late final _router = AppRoutes.createRouter(
    isFirstLaunch: widget.isFirstLaunch,
    hasSavedSession: widget.hasSavedSession,
  );
  bool _didShowStartupResetNotice = false;
  bool _didStartSavedSessionRestore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startSavedSessionRestoreIfNeeded();
    });
  }

  void _startSavedSessionRestoreIfNeeded() {
    if (!widget.hasSavedSession || _didStartSavedSessionRestore) {
      return;
    }

    _didStartSavedSessionRestore = true;
    unawaited(AuthState.instance.restoreSavedSession());
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
      listenable: ServerConnectionStatusService.instance,
      builder: (context, _) {
        final service = ServerConnectionStatusService.instance;

        return Stack(
          children: [
            child,
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
                    child: service.isVisible
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
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('zh')],
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
          ),
          themeMode: _appState.themeMode,
          builder: (context, child) {
            _showStartupResetNoticeIfNeeded(context);
            final content = _buildServerConnectionOverlay(
              context,
              child ?? const SizedBox.shrink(),
            );
            if (hasBackgroundImage && !kIsWeb) {
              return _buildSavedSessionRestoreOverlay(
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
              );
            }
            return _buildSavedSessionRestoreOverlay(context, content);
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
        surface: surfaceColor != null
          ? Color(surfaceColor)
          : null,
      error: customColors['error'] != null
          ? Color(customColors['error']!)
          : null,
    );
  }
}
