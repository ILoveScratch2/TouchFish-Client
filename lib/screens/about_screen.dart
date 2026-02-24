import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../l10n/app_localizations.dart';
import '../constants/app_constants.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'debug/debug_options_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> with TickerProviderStateMixin {
  PackageInfo _packageInfo = PackageInfo(
    appName: AppConstants.appName,
    packageName: AppConstants.packageName,
    version: AppConstants.defaultVersion,
    buildNumber: AppConstants.defaultBuildNumber,
  );
  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  int _easterEggTapCount = 0;
  int _currentLevel = 0;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
    _loadEasterEggProgress();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onLogoTap() {
    final l10n = AppLocalizations.of(context)!;
    _rotationController.forward(from: 0);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.aboutEasterEggFound,
          style: const TextStyle(fontSize: 12),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  Future<void> _loadEasterEggProgress() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _easterEggTapCount = prefs.getInt('easter_egg_tap_count') ?? 0;
        _currentLevel = _calculateLevel(_easterEggTapCount);
      });
    }
  }

  Future<void> _saveEasterEggProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('easter_egg_tap_count', _easterEggTapCount);
  }

  Future<void> _resetEasterEggProgress() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.aboutEasterEggResetConfirmTitle),
        content: Text(l10n.aboutEasterEggResetConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.aboutEasterEggResetCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.aboutEasterEggResetConfirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('easter_egg_tap_count', 0);
      setState(() {
        _easterEggTapCount = 0;
        _currentLevel = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.aboutEasterEggResetSuccess),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16,
              right: 16,
            ),
          ),
        );
      }
    }
  }

  int _calculateLevel(int tapCount) {
    for (int level = 1; level <= 15; level++) {
      if (tapCount < _getRequiredTapsForLevel(level)) {
        return level - 1;
      }
    }
    return 15; // Max level
  }

  int _getRequiredTapsForLevel(int level) {
    switch (level) {
      case 0: return 0;
      case 1: return 1;
      case 2: return 5;
      case 3: return 15;
      case 4: return 30;
      case 5: return 60;
      case 6: return 100;
      case 7: return 180;
      case 8: return 280;
      case 9: return 390;
      case 10: return 600;
      case 11: return 700;
      case 12: return 860;
      case 13: return 1000;
      case 14: return 1100;
      case 15: return 1450;
      default: return 1450;
    }
  }

  String _getLevelName(AppLocalizations l10n, int level) {
    switch (level) {
      case 0: return l10n.aboutEasterEggLevelName0;
      case 1: return l10n.aboutEasterEggLevelName1;
      case 2: return l10n.aboutEasterEggLevelName2;
      case 3: return l10n.aboutEasterEggLevelName3;
      case 4: return l10n.aboutEasterEggLevelName4;
      case 5: return l10n.aboutEasterEggLevelName5;
      case 6: return l10n.aboutEasterEggLevelName6;
      case 7: return l10n.aboutEasterEggLevelName7;
      case 8: return l10n.aboutEasterEggLevelName8;
      case 9: return l10n.aboutEasterEggLevelName9;
      case 10: return l10n.aboutEasterEggLevelName10;
      case 11: return l10n.aboutEasterEggLevelName11;
      case 12: return l10n.aboutEasterEggLevelName12;
      case 13: return l10n.aboutEasterEggLevelName13;
      case 14: return l10n.aboutEasterEggLevelName14;
      case 15: return l10n.aboutEasterEggLevelName15;
      default: return l10n.aboutEasterEggLevelName0;
    }
  }

  void _onAppNameTap() {
    final l10n = AppLocalizations.of(context)!;
    _shakeController.forward(from: 0);
    ScaffoldMessenger.of(context).clearSnackBars();
    
    setState(() {
      _easterEggTapCount++;
      _currentLevel = _calculateLevel(_easterEggTapCount);
    });
    
    _saveEasterEggProgress();
    
    final messageIndex = _random.nextInt(20);
    String message;
    switch (messageIndex) {
      case 0: message = l10n.aboutEasterEggMessage0; break;
      case 1: message = l10n.aboutEasterEggMessage1; break;
      case 2: message = l10n.aboutEasterEggMessage2; break;
      case 3: message = l10n.aboutEasterEggMessage3; break;
      case 4: message = l10n.aboutEasterEggMessage4; break;
      case 5: message = l10n.aboutEasterEggMessage5; break;
      case 6: message = l10n.aboutEasterEggMessage6; break;
      case 7: message = l10n.aboutEasterEggMessage7; break;
      case 8: message = l10n.aboutEasterEggMessage8; break;
      case 9: message = l10n.aboutEasterEggMessage9; break;
      case 10: message = l10n.aboutEasterEggMessage10; break;
      case 11: message = l10n.aboutEasterEggMessage11; break;
      case 12: message = l10n.aboutEasterEggMessage12; break;
      case 13: message = l10n.aboutEasterEggMessage13; break;
      case 14: message = l10n.aboutEasterEggMessage14; break;
      case 15: message = l10n.aboutEasterEggMessage15; break;
      case 16: message = l10n.aboutEasterEggMessage16; break;
      case 17: message = l10n.aboutEasterEggMessage17; break;
      case 18: message = l10n.aboutEasterEggMessage18; break;
      case 19: message = l10n.aboutEasterEggMessage19; break;
      default: message = l10n.aboutEasterEggMessage0;
    }
    
    final levelName = _getLevelName(l10n, _currentLevel);
    final displayMessage = '${l10n.aboutEasterEggLevel} $_currentLevel （$levelName）\n$message';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          displayMessage,
          style: const TextStyle(fontSize: 13),
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  Future<void> _initPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _packageInfo = PackageInfo(
            appName: AppConstants.appName,
            packageName: info.packageName,
            version: info.version,
            buildNumber: info.buildNumber,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load package info: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showLicenseDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    String licenseText = '';
    
    try {
      licenseText = await rootBundle.loadString('LICENSE');
    } catch (e) {
      licenseText = 'Failed to load license file: $e';
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
          child: Column(
            children: [
              // Title bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Symbols.copyright),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.aboutLicenseDialogTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Symbols.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Description
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Row(
                  children: [
                    Icon(
                      Symbols.info,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.aboutLicenseDescription,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // License text
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            l10n.aboutLicenseFullText,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Symbols.content_copy, size: 20),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: licenseText));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.aboutCopiedToClipboard),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            tooltip: l10n.aboutCopyToClipboard,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: SelectableText(
                            licenseText,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Actions
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.aboutLicenseClose),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFontLicenseDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    // Show font selection dialog
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Symbols.font_download),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.aboutFontLicenseDialogTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Symbols.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Font selection list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildFontLicenseOption(
                      context,
                      fontName: 'HarmonyOS Sans SC',
                      licensePath: 'assets/font/LICENSE.txt',
                    ),
                    const SizedBox(height: 12),
                    _buildFontLicenseOption(
                      context,
                      fontName: 'LXGW WenKai',
                      licensePath: 'assets/font-wenkai/LICENSE.txt',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFontLicenseOption(
    BuildContext context, {
    required String fontName,
    required String licensePath,
  }) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          _showLicenseContent(context, fontName, licensePath);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Symbols.description),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  fontName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: fontName,
                  ),
                ),
              ),
              const Icon(Symbols.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLicenseContent(
    BuildContext context,
    String fontName,
    String licensePath,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    String licenseText = '';
    
    try {
      licenseText = await rootBundle.loadString(licensePath);
    } catch (e) {
      licenseText = 'Load license font fail: $e';
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
          child: Column(
            children: [
              // Title bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Symbols.arrow_back),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showFontLicenseDialog(context);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fontName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: fontName,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Symbols.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Description
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Row(
                  children: [
                    Icon(
                      Symbols.info,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.aboutFontLicenseDescription,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // License text
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            l10n.aboutFontLicenseFullText,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Symbols.content_copy, size: 20),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: licenseText));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.aboutCopiedToClipboard),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            tooltip: l10n.aboutCopyToClipboard,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: SelectableText(
                            licenseText,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Actions
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.aboutFontLicenseClose),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aboutTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 24),
                          // App Icon and Name
                          GestureDetector(
                            onTap: _onLogoTap,
                            child: AnimatedBuilder(
                              animation: _rotationAnimation,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _rotationAnimation.value * 2 * 3.14159,
                                  child: child,
                                );
                              },
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor:
                                    theme.colorScheme.primary.withOpacity(0.1),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(50),
                                  child: Image.asset(
                                    'assets/logo.png',
                                    width: 80,
                                    height: 80,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _onAppNameTap,
                            child: AnimatedBuilder(
                              animation: _shakeAnimation,
                              builder: (context, child) {
                                final shake = sin(_shakeAnimation.value * pi * 4) * 10 * (1 - _shakeAnimation.value);
                                return Transform.translate(
                                  offset: Offset(shake, 0),
                                  child: child,
                                );
                              },
                              child: Text(
                                _packageInfo.appName,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            l10n.aboutVersionInfo(
                              _packageInfo.version,
                              _packageInfo.buildNumber,
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                          
                          // Easter egg progress bar
                          if (_easterEggTapCount > 0) ...[
                            const SizedBox(height: 16),
                            _buildEasterEggProgress(context, l10n),
                          ],
                          
                          const SizedBox(height: 32),

                          // App Info Card
                          _buildSection(
                            context,
                            title: l10n.aboutAppInfoSection,
                            children: [
                              _buildInfoItem(
                                context,
                                icon: Symbols.info,
                                label: l10n.aboutPackageName,
                                value: _packageInfo.packageName,
                              ),
                              _buildInfoItem(
                                context,
                                icon: Symbols.update,
                                label: l10n.aboutVersion,
                                value: _packageInfo.version,
                              ),
                              _buildInfoItem(
                                context,
                                icon: Symbols.build,
                                label: l10n.aboutBuildNumber,
                                value: _packageInfo.buildNumber,
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Links Card
                          _buildSection(
                            context,
                            title: l10n.aboutLinksSection,
                            children: [
                              _buildListTile(
                                context,
                                icon: Symbols.description,
                                title: l10n.aboutDocumentation,
                                onTap: () => _launchURL(
                                  AppConstants.documentationUrl,
                                ),
                              ),
                              _buildListTile(
                                context,
                                icon: Symbols.dns,
                                title: l10n.aboutServerRepository,
                                onTap: () => _launchURL(
                                  AppConstants.githubServerRepoUrl,
                                ),
                              ),
                              _buildListTile(
                                context,
                                icon: Symbols.font_download,
                                title: l10n.aboutFontLicense,
                                onTap: () => _showFontLicenseDialog(context),
                              ),
                              _buildListTile(
                                context,
                                icon: Symbols.code,
                                title: l10n.aboutOpenSourceLicenses,
                                onTap: () {
                                  context.push('/licenses');
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Developer Info
                          _buildSection(
                            context,
                            title: l10n.aboutDeveloperSection,
                            children: [
                              _buildListTile(
                                context,
                                icon: Symbols.email,
                                title: l10n.aboutContactUs,
                                subtitle: AppConstants.contactEmail,
                                onTap: () => _launchURL(
                                  AppConstants.contactMailto,
                                ),
                              ),
                              _buildListTile(
                                context,
                                icon: Symbols.code_blocks,
                                title: l10n.aboutSourceCode,
                                subtitle: 'GitHub Repository',
                                onTap: () => _launchURL(
                                  AppConstants.githubRepoUrl,
                                ),
                              ),
                              _buildListTile(
                                context,
                                icon: Symbols.copyright,
                                title: l10n.aboutLicense,
                                subtitle: l10n.aboutLicenseContent,
                                onTap: () => _showLicenseDialog(context),
                              ),
                              _buildListTile(
                                context,
                                icon: Symbols.terminal,
                                title: l10n.accountDebugOptions,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const DebugOptionsScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Copyright
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Text(
                                  l10n.aboutCopyright(
                                    DateTime.now().year.toString(),
                                  ),
                                  style: theme.textTheme.bodySmall,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.aboutMadeWith,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool copyable = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).hintColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: copyable ? 1 : null,
                ),
              ],
            ),
          ),
          if (value.startsWith('http') || value.contains('@') || copyable)
            IconButton(
              icon: const Icon(Symbols.content_copy, size: 16),
              onPressed: () {
                _copyToClipboard(value, l10n.aboutCopiedToClipboard);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: l10n.aboutCopyToClipboard,
            ),
        ],
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final multipleLines = subtitle?.contains('\n') ?? false;
    return ListTile(
      leading: Padding(
        padding: EdgeInsets.only(top: multipleLines ? 8 : 0),
        child: Icon(icon),
      ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      isThreeLine: multipleLines,
      trailing: Padding(
        padding: EdgeInsets.only(top: multipleLines ? 8 : 0),
        child: const Icon(Symbols.chevron_right),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minLeadingWidth: 24,
    );
  }

  Widget _buildEasterEggProgress(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    if (_currentLevel >= 15) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.trophy,
              color: theme.colorScheme.onPrimaryContainer,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l10n.aboutEasterEggCompleted,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }
    final nextLevel = _currentLevel + 1;
    final currentLevelTaps = _getRequiredTapsForLevel(_currentLevel);
    final nextLevelTaps = _getRequiredTapsForLevel(nextLevel);
    final remaining = nextLevelTaps - _easterEggTapCount;
    final progress = (_easterEggTapCount - currentLevelTaps) / (nextLevelTaps - currentLevelTaps);
    final currentLevelName = _getLevelName(l10n, _currentLevel);
    
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${l10n.aboutEasterEggLevel} $_currentLevel （$currentLevelName）',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                l10n.aboutEasterEggProgress(nextLevel, remaining),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Symbols.restart_alt, size: 18),
                onPressed: _resetEasterEggProgress,
                tooltip: l10n.aboutEasterEggReset,
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.errorContainer,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
