import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_form_guard/smart_form_guard.dart';
import '../l10n/app_localizations.dart';
import '../routes/app_routes.dart';
import '../services/api/tf_api_client.dart';
import '../utils/talker.dart';

class RegisterScreen extends StatefulWidget {
  final String? initialUsername;
  final String? initialPassword;

  const RegisterScreen({
    super.key,
    this.initialUsername,
    this.initialPassword,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _captchaController = TextEditingController();

  bool _isLoadingServerInfo = true;
  bool _requiresEmail = false;
  bool _requiresCaptcha = false;
  TfCaptchaInfo? _captchaInfo;
  bool _isLoadingCaptcha = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialUsername != null) {
      _usernameController.text = widget.initialUsername!;
    }
    if (widget.initialPassword != null) {
      _passwordController.text = widget.initialPassword!;
    }
    _fetchServerInfo();
  }

  Future<void> _fetchServerInfo() async {
    try {
      final info = await TfApiClient.instance.fetchServerInfo();
      if (!mounted) return;
      setState(() {
        _requiresEmail = info?.emailActivate ?? false;
        _requiresCaptcha = info?.captcha ?? false;
        _isLoadingServerInfo = false;
      });
      if (_requiresCaptcha) await _refreshCaptcha();
    } catch (e) {
      talker.error('RegisterScreen: fetchServerInfo failed', e);
      if (mounted) setState(() => _isLoadingServerInfo = false);
    }
  }

  Future<void> _refreshCaptcha() async {
    setState(() => _isLoadingCaptcha = true);
    try {
      final info = await TfApiClient.instance.getCaptcha();
      if (mounted) {
        setState(() {
          _captchaInfo = info;
          _captchaController.clear();
          _isLoadingCaptcha = false;
        });
      }
    } catch (e) {
      talker.error('RegisterScreen: getCaptcha failed', e);
      if (mounted) setState(() => _isLoadingCaptcha = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  void _nextStep() {
    context.push(
      AppRoutes.registerStep2,
      extra: {
        'username': _usernameController.text,
        'password': _passwordController.text,
        'requiresEmail': _requiresEmail,
        'captchaStamp': _captchaInfo?.stamp,
        'captchaCode': _requiresCaptcha ? _captchaController.text : null,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.registerTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SizedBox(
          width: 400,
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SmartForm(
                onValid: _nextStep,
                child: SingleChildScrollView(
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
                        l10n.registerCreateAccount,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.registerAccountInfo,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Username field
                      SmartField(
                        controller: _usernameController,
                        label: l10n.registerUsername,
                        prefixIcon: Icons.person_outline,
                        validator: SmartValidators.compose([
                          SmartValidators.required(l10n.registerErrorUsernameRequired),
                          SmartValidators.minLength(3, l10n.registerErrorUsernameMinLength),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      
                      // Password field
                      SmartField(
                        controller: _passwordController,
                        label: l10n.registerPassword,
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                        validator: SmartValidators.required(l10n.registerErrorPasswordRequired),
                      ),
                      const SizedBox(height: 16),
                      
                      // Confirm Password field
                      SmartField(
                        controller: _confirmPasswordController,
                        label: l10n.registerConfirmPassword,
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                        validator: SmartValidators.compose([
                          SmartValidators.required(l10n.registerErrorConfirmPasswordRequired),
                          (value) {
                            if (value != _passwordController.text) {
                              return l10n.registerErrorPasswordMismatch;
                            }
                            return null;
                          },
                        ]),
                      ),

                      // 验证码（服务器要求时显示）
                      if (_requiresCaptcha) ...[                        
                        const SizedBox(height: 16),
                        _buildCaptchaSection(l10n),
                      ],

                      const SizedBox(height: 24),
                      
                      // Next button
                      _isLoadingServerInfo
                          ? const CircularProgressIndicator()
                          : SmartSubmitButton(
                              text: l10n.registerNextStep,
                              icon: Icons.arrow_forward,
                            ),
                      const SizedBox(height: 12),
                      
                      // Back to login button
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.registerHaveAccount),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptchaSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _captchaInfo == null
                  ? Container(
                      height: 56,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Theme.of(context).colorScheme.outline),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _isLoadingCaptcha
                          ? const Center(
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)))
                          : Center(
                              child: Text(l10n.registerCaptchaLoad,
                                  style: Theme.of(context).textTheme.bodySmall)),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64.decode(_captchaInfo!.pic),
                        height: 56,
                        fit: BoxFit.contain,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isLoadingCaptcha ? null : _refreshCaptcha,
              icon: const Icon(Icons.refresh),
              tooltip: l10n.registerCaptchaRefresh,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SmartField(
          controller: _captchaController,
          label: l10n.registerCaptchaCode,
          prefixIcon: Icons.security_outlined,
          validator: SmartValidators.required(l10n.registerErrorCaptchaRequired),
        ),
      ],
    );
  }
}
