import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Brand palette, pulled from the Enduvo logo gradient.
class EnduvoColors {
  static const navy = Color(0xFF0A2647);
  static const deepBlue = Color(0xFF12406B);
  static const teal = Color(0xFF2E9DC0);
  static const gold = Color(0xFFF6C567);
  static const white = Color(0xFFFFFFFF);
  static const background = Color(0xFFF9FAFB);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E7EB);
  static const muted = Color(0xFF6B7280);
  static const text = Color(0xFF111827);
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  bool _sending = false;
  String? _message;
  bool _isError = false;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _message = 'Bitte gib eine gültige E-Mail-Adresse ein.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _sending = true;
      _message = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'com.enduvo.app://login-callback',
      );

      if (!mounted) return;
      setState(() {
        // Always neutral — never confirm/deny whether the email exists.
        _message =
            'Falls ein Konto mit dieser E-Mail existiert, haben wir einen Link zum Zurücksetzen gesendet.';
        _isError = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      final isRateLimited = e.code == 'over_email_send_rate_limit';
      setState(() {
        _isError = true;
        _message = isRateLimited
            ? 'Bitte warte kurz, bevor du es erneut versuchst.'
            : 'Etwas ist schiefgelaufen. Bitte versuche es später erneut.';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      labelText: 'E-Mail',
      prefixIcon: const Icon(
        Icons.email_outlined,
        color: Colors.black54,
        size: 20,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: EnduvoColors.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: EnduvoColors.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: EnduvoColors.deepBlue,
          width: 1.4,
        ),
      ),
      labelStyle: const TextStyle(
        color: EnduvoColors.muted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: 46,
                  bottom: 64,
                ),
                child: Image.asset(
                  'assets/EnduvoInAppLogo1152x1152-2.png',
                  height: 104,
                  fit: BoxFit.contain,
                ),
              ),

              Transform.translate(
                offset: const Offset(0, -32),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Passwort zurücksetzen',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: EnduvoColors.text,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            'Wir senden dir einen Link zum Zurücksetzen.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),

                          const SizedBox(height: 26),

                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: _inputDecoration(),
                          ),

                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            child: _message != null
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          _isError
                                              ? Icons.error_outline
                                              : Icons.check_circle_outline,
                                          color: _isError
                                              ? Colors.redAccent
                                              : Colors.black54,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _message!,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              color: _isError
                                                  ? Colors.redAccent
                                                  : EnduvoColors.muted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          const SizedBox(height: 22),

                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _sending ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: EnduvoColors.text,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    EnduvoColors.text.withOpacity(0.65),
                                disabledForegroundColor: Colors.white,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Link senden',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          Align(
                            alignment: Alignment.center,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: EnduvoColors.muted,
                              ),
                              child: const Text(
                                'Zurück zur Anmeldung',
                                style: TextStyle(
                                  color: EnduvoColors.muted,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}