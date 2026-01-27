import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_form_guard/smart_form_guard.dart';
import '../l10n/app_localizations.dart';
import '../routes/app_routes.dart';

class RegisterStep3Screen extends StatefulWidget {
  final String username;
  final String password;
  final String email;

  const RegisterStep3Screen({
    super.key,
    required this.username,
    required this.password,
    required this.email,
  });

  @override
  State<RegisterStep3Screen> createState() => _RegisterStep3ScreenState();
}

class _RegisterStep3ScreenState extends State<RegisterStep3Screen> {
  final _verificationCodeController = TextEditingController();

  @override
  void dispose() {
    _verificationCodeController.dispose();
    super.dispose();
  }

  void _register() {
    context.go(AppRoutes.registerSuccess);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.registerTitle),
      ),
      body: Center(
        child: SizedBox(
          width: 400,
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SmartForm(
                onValid: _register,
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
                        l10n.registerVerifyInfo,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Verification Code field
                      SmartField(
                        controller: _verificationCodeController,
                        label: l10n.registerVerificationCode,
                        prefixIcon: Icons.verified_user_outlined,
                        keyboardType: TextInputType.number,
                        validator: SmartValidators.compose([
                          SmartValidators.required(l10n.registerErrorVerificationCodeRequired),
                          (value) {
                            if (value == null || value.isEmpty) return null;
                            if (!RegExp(r'^\d{6}$').hasMatch(value)) {
                              return l10n.registerErrorVerificationCodeInvalid;
                            }
                            return null;
                          },
                        ]),
                      ),
                      const SizedBox(height: 24),
                      
                      // Register button
                      SmartSubmitButton(
                        text: l10n.registerComplete,
                        icon: Icons.check_circle,
                      ),
                      const SizedBox(height: 12),
                      
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
