import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_form_guard/smart_form_guard.dart';
import '../l10n/app_localizations.dart';
import '../routes/app_routes.dart';
import '../services/api/tf_api_client.dart';
import '../services/snackbar_service.dart';
import 'register_step3_screen.dart';

class RegisterStep2Screen extends StatefulWidget {
  final String username;
  final String password;
  final bool requiresEmail;
  final String? captchaStamp;
  final String? captchaCode;
  final String? captchaToken;

  const RegisterStep2Screen({
    super.key,
    required this.username,
    required this.password,
    this.requiresEmail = false,
    this.captchaStamp,
    this.captchaCode,
    this.captchaToken,
  });

  @override
  State<RegisterStep2Screen> createState() => _RegisterStep2ScreenState();
}

class _RegisterStep2ScreenState extends State<RegisterStep2Screen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _registered = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (_isLoading) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    try {
      if (!_registered) {
        final result = await TfApiClient.instance.register(
          widget.username,
          widget.password,
          email: widget.requiresEmail ? _emailController.text.trim() : null,
          captchaStamp: widget.captchaStamp,
          captchaCode: widget.captchaCode,
          captchaToken: widget.captchaToken,
        );
        if (!mounted) return;
        if (result == RegisterResult.captchaInvalid) {
          // 验证码错误返回上一步刷新
          TouchFishSnackbarService.instance.show(
            l10n.registerErrorCaptchaInvalid,
          );
          context.pop(true);
          return;
        }
        if (result != RegisterResult.success) {
          TouchFishSnackbarService.instance.show(l10n.registerErrorFailed);
          return;
        }
        if (!widget.requiresEmail) {
          context.go(AppRoutes.registerSuccess);
          return;
        }
        _registered = true;
      }

      final profile = await TfApiClient.instance.getUserByUsername(
        widget.username,
      );
      if (!mounted) return;
      final uid = int.tryParse(profile?.uid ?? '');
      if (uid == null) {
        TouchFishSnackbarService.instance.show(l10n.registerErrorFailed);
        return;
      }
      final password = widget.password;
      RegisterStep3Screen.show(
        context,
        username: widget.username,
        uid: uid,
        resendCode: () => TfApiClient.instance.resendActivation(uid, password),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.registerTitle)),
      body: Center(
        child: SizedBox(
          width: 400,
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SmartForm(
                onValid: () => _nextStep(),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.requiresEmail
                            ? l10n.registerEmailInfo
                            : l10n.registerConfirmInfo,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (widget.requiresEmail) ...[
                        SmartField.email(
                          controller: _emailController,
                          label: l10n.registerEmail,
                          enabled: !_isLoading && !_registered,
                        ),
                        const SizedBox(height: 24),
                      ],

                      _isLoading
                          ? const CircularProgressIndicator()
                          : SmartSubmitButton(
                              text: widget.requiresEmail
                                  ? l10n.registerNextStep
                                  : l10n.registerComplete,
                              icon: widget.requiresEmail
                                  ? Icons.arrow_forward
                                  : Icons.check_circle,
                            ),
                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.registerPreviousStep),
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
}
