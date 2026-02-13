import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../constants/app_constants.dart';
import 'package:flutter/services.dart' show rootBundle;

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
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
                          Text(
                            _packageInfo.appName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
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
}
