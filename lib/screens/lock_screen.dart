// 为了避免 wyf 被 jc，我们需要 lockdown client！
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localizations.dart';
import '../services/lock_service.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlockWithPassword() async {
    if (_busy) return;
    setState(() {
      _error = null;
      _busy = true;
    });
    final l10n = AppLocalizations.of(context)!;
    try {
      final unlocked = await LockService.instance.unlockWithPassword(
        _password.text,
      );
      if (!mounted) return;
      if (!unlocked) {
        setState(() => _error = l10n.lockErrorInvalidPassword);
      }
    } catch (_) {
      if (mounted) setState(() => _error = l10n.lockErrorUnknown);
    } finally {
      if (mounted && !LockService.instance.isLocked) setState(() => _busy = false);
    }
  }

  Future<void> _unlockWithBiometrics() async {
    if (_busy) return;
    setState(() {
      _error = null;
      _busy = true;
    });
    final l10n = AppLocalizations.of(context)!;
    try {
      final unlocked = await LockService.instance.unlockWithBiometrics();
      if (!mounted) return;
      if (!unlocked) {
        setState(() => _error = l10n.lockErrorUnknown);
      }
    } on LockException catch (error) {
      if (mounted) setState(() => _error = _biometricErrorMessage(l10n, error.code));
    } catch (_) {
      if (mounted) setState(() => _error = l10n.lockErrorUnknown);
    } finally {
      if (mounted && !LockService.instance.isLocked) setState(() => _busy = false);
    }
  }

  String _biometricErrorMessage(AppLocalizations l10n, String code) {
    switch (code) {
      case 'biometricUnavailable':
        return l10n.lockErrorBiometricUnavailable;
      case 'biometricCancelled':
        return l10n.lockErrorBiometricCancelled;
      case 'biometricNotEnabled':
        return l10n.lockErrorBiometricNotEnabled;
      default:
        return l10n.lockErrorUnknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final service = LockService.instance;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/logo.png',
                              width: 72,
                              height: 72,
                              errorBuilder: (_, _, _) => Container(
                                width: 72,
                                height: 72,
                                alignment: Alignment.center,
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Symbols.lock,
                                  size: 36,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.lockTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.lockSubtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          autofocus: true,
                          enabled: !_busy,
                          onSubmitted: (_) => _unlockWithPassword(),
                          decoration: InputDecoration(
                            labelText: l10n.lockPasswordLabel,
                            suffixIcon: service.isBiometricEnabled
                                ? IconButton(
                                    icon: const Icon(Symbols.fingerprint),
                                    onPressed: _busy
                                        ? null
                                        : _unlockWithBiometrics,
                                    tooltip: l10n.lockBiometricAction,
                                  )
                                : null,
                          ),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _busy ? null : _unlockWithPassword,
                          child: _busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.lockUnlock),
                        ),
                      ],
                    ),
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
