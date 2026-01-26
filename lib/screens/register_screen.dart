import 'package:flutter/material.dart';
import 'package:smart_form_guard/smart_form_guard.dart';
import '../l10n/app_localizations.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.initialUsername != null) {
      _usernameController.text = widget.initialUsername!;
    }
    if (widget.initialPassword != null) {
      _passwordController.text = widget.initialPassword!;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _nextStep() {
    Navigator.of(context).pushNamed(
      '/register/step2',
      arguments: {
        'username': _usernameController.text,
        'password': _passwordController.text,
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
                      const SizedBox(height: 24),
                      
                      // Next button
                      SmartSubmitButton(
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
}
