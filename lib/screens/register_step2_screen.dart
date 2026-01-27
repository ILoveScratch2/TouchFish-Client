import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_form_guard/smart_form_guard.dart';
import '../l10n/app_localizations.dart';
import '../routes/app_routes.dart';

class RegisterStep2Screen extends StatefulWidget {
  final String username;
  final String password;

  const RegisterStep2Screen({
    super.key,
    required this.username,
    required this.password,
  });

  @override
  State<RegisterStep2Screen> createState() => _RegisterStep2ScreenState();
}

class _RegisterStep2ScreenState extends State<RegisterStep2Screen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _nextStep() {
    context.push(
      AppRoutes.registerStep3,
      extra: {
        'username': widget.username,
        'password': widget.password,
        'email': _emailController.text,
      },
    );
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
                        l10n.registerEmailInfo,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Email field
                      SmartField.email(
                        controller: _emailController,
                        label: l10n.registerEmail,
                      ),
                      const SizedBox(height: 24),
                      
                      // Next button
                      SmartSubmitButton(
                        text: l10n.registerNextStep,
                        icon: Icons.arrow_forward,
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
