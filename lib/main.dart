import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'l10n/app_localizations.dart';
import 'models/app_state.dart';
import 'models/settings_service.dart';
import 'routes/app_routes.dart';
import 'utils/talker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  
  final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
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
    final windowOpacity = SettingsService.instance.getValue<double>('windowOpacity', 1.0);
    
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
  
  talker.info('TouchFish Client started!');
  
  runApp(TouchFishApp(isFirstLaunch: isFirstLaunch));
}

class TouchFishApp extends StatefulWidget {
  final bool isFirstLaunch;
  
  const TouchFishApp({super.key, required this.isFirstLaunch});

  @override
  State<TouchFishApp> createState() => _TouchFishAppState();
}

class _TouchFishAppState extends State<TouchFishApp> {
  final _appState = AppState.instance;
  late final _router = AppRoutes.createRouter(isFirstLaunch: widget.isFirstLaunch);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, _) {
        // Determine theme color - only use custom colors if 'custom' is selected
        final isCustomTheme = _appState.themeColorKey == 'custom';
        final seedColor = _appState.themeColor;

        // Build light theme
        var lightColorScheme = ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        );

        // Build dark theme
        var darkColorScheme = ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        );

        // Apply custom colors only if custom theme is selected
        final customColors = _appState.customColors;
        if (isCustomTheme && customColors != null) {
          lightColorScheme = _applyCustomColors(lightColorScheme, customColors);
          darkColorScheme = _applyCustomColors(darkColorScheme, customColors);
        }

        // Get card opacity
        final cardOpacity = _appState.cardOpacity;

        // Get background image path
        final backgroundImagePath = _appState.backgroundImagePath;
        final hasBackgroundImage = backgroundImagePath != null && backgroundImagePath.isNotEmpty;

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
          supportedLocales: const [
            Locale('en'),
            Locale('zh'),
          ],
          locale: _appState.locale,
          theme: ThemeData(
            colorScheme: lightColorScheme,
            useMaterial3: true,
            fontFamily: _appState.fontFamily,
            scaffoldBackgroundColor: hasBackgroundImage ? Colors.transparent : null,
            cardTheme: CardThemeData(
              color: lightColorScheme.surfaceContainer.withOpacity(cardOpacity),
              elevation: cardOpacity < 1 ? 0 : null,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            useMaterial3: true,
            fontFamily: _appState.fontFamily,
            scaffoldBackgroundColor: hasBackgroundImage ? Colors.transparent : null,
            cardTheme: CardThemeData(
              color: darkColorScheme.surfaceContainer.withOpacity(cardOpacity),
              elevation: cardOpacity < 1 ? 0 : null,
            ),
          ),
          themeMode: _appState.themeMode,
          builder: (context, child) {
            if (hasBackgroundImage && !kIsWeb) {
              return Container(
                color: Theme.of(context).colorScheme.surface,
                child: Container(
                  decoration: BoxDecoration(
                    backgroundBlendMode: BlendMode.darken,
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
                    image: DecorationImage(
                      opacity: 0.2,
                      image: FileImage(File(backgroundImagePath)),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: child,
                ),
              );
            }
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }

  ColorScheme _applyCustomColors(ColorScheme scheme, Map<String, int> customColors) {
    return scheme.copyWith(
      primary: customColors['primary'] != null ? Color(customColors['primary']!) : null,
      secondary: customColors['secondary'] != null ? Color(customColors['secondary']!) : null,
      tertiary: customColors['tertiary'] != null ? Color(customColors['tertiary']!) : null,
      surface: customColors['surface'] != null ? Color(customColors['surface']!) : null,
      background: customColors['background'] != null ? Color(customColors['background']!) : null,
      error: customColors['error'] != null ? Color(customColors['error']!) : null,
    );
  }
}
