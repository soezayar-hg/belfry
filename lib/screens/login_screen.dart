import 'package:flutter/material.dart';

import '../api/client.dart';
import '../controller/belfry_controller.dart';
import '../theme/belfry_theme.dart';
import '../widgets/belfry_button.dart';

/// Sign-in against the shared Sozy Gateway. Mirrors the sibling apps' auth
/// flow; the gateway additionally checks that the account has Belfry access.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final BelfryController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.login(email, password);
      // On success the root widget swaps to the home screen.
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      // Surface the real error — login succeeded on the wire if you see this,
      // so it's a local failure (e.g. secure storage / keychain).
      setState(() => _error = 'Something went wrong: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: BelfryColors.primary,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        color: BelfryColors.onPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Belfry',
                          style: BelfryText.sans(
                            size: 22,
                            weight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'SIGN IN TO YOUR REMINDERS',
                          style: BelfryText.sans(
                            size: 11,
                            weight: FontWeight.w500,
                            color: BelfryColors.ink2,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Container(
                  decoration: BoxDecoration(
                    color: BelfryColors.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: BelfryColors.line),
                  ),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FieldLabel('Email'),
                      const SizedBox(height: 6),
                      _BelfryField(
                        controller: _email,
                        hint: 'you@example.com',
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 14),
                      _FieldLabel('Password'),
                      const SizedBox(height: 6),
                      _BelfryField(
                        controller: _password,
                        hint: '••••••••',
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: BelfryColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: BelfryColors.danger.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Text(
                            _error!,
                            style: BelfryText.sans(
                              size: 13,
                              color: BelfryColors.danger,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      BelfryButton(
                        label: 'Sign in',
                        variant: BelfryButtonVariant.primary,
                        expand: true,
                        busy: _busy,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Belfry uses your Sozy Gateway account. Access is granted '
                  'by an admin.',
                  textAlign: TextAlign.center,
                  style: BelfryText.sans(size: 12, color: BelfryColors.ink3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: BelfryText.label());
  }
}

class _BelfryField extends StatelessWidget {
  const _BelfryField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      style: BelfryText.sans(size: 15),
      cursorColor: BelfryColors.primary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: BelfryText.sans(size: 15, color: BelfryColors.ink3),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        filled: true,
        fillColor: BelfryColors.panel,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: BelfryColors.line2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: BelfryColors.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
