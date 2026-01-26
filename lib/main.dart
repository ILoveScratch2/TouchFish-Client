import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'l10n/app_localizations.dart';
import 'models/app_state.dart';
import 'models/settings_service.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/window_frame.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  
  // Initialize settings service first
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, _) {
        return MaterialApp(
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
          home: WindowFrame(
            child: widget.isFirstLaunch ? const WelcomeScreen() : const LoginScreen(),
          ),
          onGenerateRoute: (settings) {
            Widget page;
            switch (settings.name) {
              case '/welcome':
                page = const WelcomeScreen();
                break;
              case '/login':
                page = const LoginScreen();
                break;
              case '/settings':
                page = const SettingsScreen();
                break;
              default:
                page = const LoginScreen();
            }
            return MaterialPageRoute(
              builder: (context) => WindowFrame(child: page),
              settings: settings,
            );
          },
        );
      },
    );
  }
}
