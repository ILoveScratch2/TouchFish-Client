import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../routes/app_routes.dart';
import '../services/api/tf_api_client.dart';
import '../services/snackbar_service.dart';
import '../utils/talker.dart';

/// 忘记密码
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPwdController = TextEditingController();
  final _confirmPwdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _codeSent = false;
  int _countdown = 0;
  Timer? _countdownTimer;
  bool _obscureNewPwd = true;
  bool _obscureConfirmPwd = true;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdown = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdown--;
        if (_countdown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _sendCode() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      TouchFishSnackbarService.instance.show(l10n.forgotPasswordEmailRequired);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final ok = await TfApiClient.instance.forgotPassword(email);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (ok) {
          _codeSent = true;
          _startCountdown();
        }
      });
      TouchFishSnackbarService.instance.show(
        ok ? l10n.forgotPasswordCodeSent : l10n.forgotPasswordCodeSendFailed,
      );
    } catch (e) {
      talker.error('ForgotPassword: send code failed', e);
      if (mounted) setState(() => _isLoading = false);
      TouchFishSnackbarService.instance.show(l10n.forgotPasswordCodeSendFailed);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final code = int.tryParse(_codeController.text.trim());
    if (code == null) {
      TouchFishSnackbarService.instance.show(l10n.forgotPasswordCodeRequired);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final ok = await TfApiClient.instance.resetPassword(
        _emailController.text.trim(),
        code,
        _newPwdController.text,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (ok) {
        TouchFishSnackbarService.instance.show(l10n.forgotPasswordSuccess);
        context.go(AppRoutes.login);
      } else {
        TouchFishSnackbarService.instance.show(l10n.forgotPasswordFailed);
      }
    } catch (e) {
      talker.error('ForgotPassword: reset failed', e);
      if (mounted) setState(() => _isLoading = false);
      TouchFishSnackbarService.instance.show(l10n.forgotPasswordFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.forgotPasswordTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.lock_reset,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.forgotPasswordTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.forgotPasswordHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: l10n.forgotPasswordEmailLabel,
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? l10n.forgotPasswordEmailRequired
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l10n.forgotPasswordCodeLabel,
                                prefixIcon: const Icon(Icons.verified_outlined),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 56,
                            child: OutlinedButton(
                              onPressed: _isLoading || _countdown > 0
                                  ? null
                                  : _sendCode,
                              child: Text(
                                _countdown > 0
                                    ? '${l10n.forgotPasswordResend} ($_countdown)'
                                    : (_codeSent
                                          ? l10n.forgotPasswordResend
                                          : l10n.forgotPasswordSendCode),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _newPwdController,
                        obscureText: _obscureNewPwd,
                        decoration: InputDecoration(
                          labelText: l10n.changePasswordNewPwd,
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPwd
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _obscureNewPwd = !_obscureNewPwd),
                          ),
                        ),
                        validator: (value) =>
                            (value == null || value.isEmpty)
                            ? l10n.changePasswordNewPwdRequired
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPwdController,
                        obscureText: _obscureConfirmPwd,
                        decoration: InputDecoration(
                          labelText: l10n.changePasswordConfirmPwd,
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPwd
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirmPwd = !_obscureConfirmPwd,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.changePasswordConfirmPwdRequired;
                          }
                          if (value != _newPwdController.text) {
                            return l10n.changePasswordMismatch;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.forgotPasswordSubmit),
                        ),
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
