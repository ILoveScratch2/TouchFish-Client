import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/snackbar_service.dart';
import '../utils/talker.dart';

/// 修改密码：验证旧密码后设置新密码。
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPwdController = TextEditingController();
  final _newPwdController = TextEditingController();
  final _confirmPwdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscureOldPwd = true;
  bool _obscureNewPwd = true;
  bool _obscureConfirmPwd = true;

  @override
  void dispose() {
    _oldPwdController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) {
      TouchFishSnackbarService.instance.show(l10n.storageNotLoggedIn);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final ok = await TfApiClient.instance.changePassword(
        uid,
        _oldPwdController.text,
        _newPwdController.text,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (ok) {
        TouchFishSnackbarService.instance.show(l10n.changePasswordSuccess);
        if (context.canPop()) {
          context.pop();
        }
      } else {
        TouchFishSnackbarService.instance.show(l10n.changePasswordFailed);
      }
    } catch (e) {
      talker.error('ChangePassword: submit failed', e);
      if (mounted) setState(() => _isLoading = false);
      TouchFishSnackbarService.instance.show(l10n.changePasswordFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.changePasswordTitle)),
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
                        Icons.password,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.changePasswordTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _oldPwdController,
                        obscureText: _obscureOldPwd,
                        decoration: InputDecoration(
                          labelText: l10n.changePasswordOldPwd,
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureOldPwd
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _obscureOldPwd = !_obscureOldPwd),
                          ),
                        ),
                        validator: (value) =>
                            (value == null || value.isEmpty)
                            ? l10n.changePasswordOldPwdRequired
                            : null,
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
                              : Text(l10n.changePasswordSubmit),
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
