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
      await windowManager.show();
      await windowManager.focus();
    });
  }
  
  final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
  
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
            colorScheme: ColorScheme.fromSeed(
              seedColor: _appState.themeColor,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _appState.themeColor,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: _appState.themeMode,
        );
      },
    );
  }
}
