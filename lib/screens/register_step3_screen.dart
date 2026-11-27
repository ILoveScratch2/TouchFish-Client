import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../routes/app_routes.dart';
import '../services/api/tf_api_client.dart';
import '../services/snackbar_service.dart';
import '../utils/talker.dart';

class RegisterStep3Screen extends StatefulWidget {
  final String username;
  final int uid;
  final Future<bool> Function()? resendCode;

  const RegisterStep3Screen({
    super.key,
    required this.username,
    required this.uid,
    this.resendCode,
  });

  static Future<void> show(
    BuildContext context, {
    required String username,
    required int uid,
    required Future<bool> Function() resendCode,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RegisterStep3Screen(
          username: username,
          uid: uid,
          resendCode: resendCode,
        ),
      ),
    );
  }

  @override
  State<RegisterStep3Screen> createState() => _RegisterStep3ScreenState();
}

class _RegisterStep3ScreenState extends State<RegisterStep3Screen> {
  final _formKey = GlobalKey<FormState>();
  final _verificationCodeController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _verificationCodeController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (_isLoading || _isResending) return;
    if (_formKey.currentState?.validate() != true) return;
    final l10n = AppLocalizations.of(context)!;
    final code = int.tryParse(_verificationCodeController.text.trim());
    if (code == null) return;
    setState(() => _isLoading = true);
    try {
      final success = await TfApiClient.instance.activateAccount(
        widget.uid,
        code,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (success) {
        context.go(AppRoutes.registerSuccess);
      } else {
        TouchFishSnackbarService.instance.show(l10n.registerActivateFailed);
      }
    } catch (e) {
      talker.error('RegisterStep3: activate failed', e);
      if (mounted) {
        setState(() => _isLoading = false);
        TouchFishSnackbarService.instance.show(l10n.registerActivateFailed);
      }
    }
  }

  Future<void> _resend() async {
    final resendCode = widget.resendCode;
    if (resendCode == null ||
        _isLoading ||
        _isResending ||
        _resendCooldown > 0) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    setState(() => _isResending = true);
    try {
      final sent = await resendCode();
      if (!mounted) return;
      if (sent) {
        _verificationCodeController.clear();
        setState(() => _resendCooldown = 60);
        _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() => _resendCooldown--);
          if (_resendCooldown == 0) timer.cancel();
        });
      }
      TouchFishSnackbarService.instance.show(
        sent ? l10n.registerResendRequested : l10n.registerResendFailed,
      );
    } catch (e) {
      talker.error('RegisterStep3: resend failed', e);
      if (mounted) {
        TouchFishSnackbarService.instance.show(l10n.registerResendFailed);
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
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
              child: Form(
                key: _formKey,
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
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.registerVerifyInfo,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Verification Code field
                      TextFormField(
                        controller: _verificationCodeController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: l10n.registerVerificationCode,
                          prefixIcon: const Icon(Icons.verified_user_outlined),
                          errorMaxLines: 2,
                        ),
                        onFieldSubmitted: (_) => unawaited(_activate()),
                        validator: (value) {
                          final code = value?.trim() ?? '';
                          if (code.isEmpty) {
                            return l10n.registerErrorVerificationCodeRequired;
                          }
                          if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                            return l10n.registerErrorVerificationCodeInvalid;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Register button
                      _isLoading || _isResending
                          ? const CircularProgressIndicator()
                          : FilledButton.icon(
                              onPressed: _activate,
                              icon: const Icon(Icons.check_circle),
                              label: Text(l10n.registerComplete),
                            ),
                      const SizedBox(height: 12),

                      if (widget.resendCode != null)
                        TextButton(
                          onPressed:
                              _isLoading || _isResending || _resendCooldown > 0
                              ? null
                              : _resend,
                          child: Text(
                            _resendCooldown > 0
                                ? l10n.registerResendWait(_resendCooldown)
                                : l10n.registerResendCode,
                          ),
                        ),

                      // Back button
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
