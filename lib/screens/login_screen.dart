import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../l10n/app_localizations.dart';
import '../routes/app_routes.dart';
import '../widgets/server_selector.dart';
import '../widgets/network_indicator.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _subscribeToConnectivityChanges();
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (!mounted) return;
      setState(() {
        _connectionStatus = result;
      });
    } catch (e) {
    }
  }

  void _subscribeToConnectivityChanges() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      if (!mounted) return;
      setState(() {
        _connectionStatus = result;
      });
    });
  }

  bool get _isConnectedToInternet {
    return _connectionStatus.any((result) => 
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    context.go(AppRoutes.main);
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
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
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
        title: Text(AppLocalizations.of(context)!.appName),
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
                      // Logo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 64,
                          height: 64,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Text(
                        AppLocalizations.of(context)!.appName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Server selector
                      const ServerSelector(),
                      const SizedBox(height: 24),
                      
                      // Username field
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.loginUsername,
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
                          labelText: AppLocalizations.of(context)!.loginPassword,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 24),
                      
                      // Login button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _login,
                          child: Text(AppLocalizations.of(context)!.loginLogin),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Register button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _register,
                          child: Text(AppLocalizations.of(context)!.loginRegister),
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
