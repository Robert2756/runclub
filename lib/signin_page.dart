import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';
import 'package:go_router/go_router.dart';

final supabase = Supabase.instance.client;

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

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;
  String? error;

  Future<void> signIn() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await supabase.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
    } on AuthException catch (e) {
      debugPrint("Sign in error: ${e.code} — ${e.message}");

      if (e.code == 'email_not_confirmed') {
        await _handleUnconfirmedEmail();
      } else {
        setState(() => error = _germanSignInError(e));
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String _germanSignInError(AuthException e) {
    switch (e.code) {
      case 'invalid_credentials':
        return "E-Mail oder Passwort ist falsch.";
      case 'user_not_found':
        return "Für diese E-Mail-Adresse existiert kein Konto.";
      case 'user_banned':
        return "Dieses Konto wurde gesperrt. Bitte kontaktiere den Support.";
      case 'over_request_rate_limit':
        return "Zu viele Anfragen. Bitte versuche es in ein paar Minuten erneut.";
      case 'over_email_send_rate_limit':
        final seconds = _extractSeconds(e.message);
        return seconds != null
            ? "Bitte warte noch $seconds Sekunden."
            : "Bitte warte kurz und versuche es erneut.";
      case 'weak_password':
        return "Das Passwort ist zu schwach.";
      case 'validation_failed':
        return "Bitte überprüfe deine Eingaben.";
      default:
        debugPrint("Unmapped AuthException code: ${e.code} — ${e.message}");
        return "Anmeldung fehlgeschlagen. Bitte versuche es erneut.";
    }
  }

  Future<void> _handleUnconfirmedEmail() async {
    try {
      await supabase.auth.resend(
        type: OtpType.signup,
        email: emailController.text.trim(),
      );
      debugPrint("RESEND SUCCESS for ${emailController.text.trim()}");

      if (!mounted) return;
      context.go('/check-email?email=${Uri.encodeComponent(emailController.text.trim())}');
    } on AuthException catch (resendError) {
      debugPrint("RESEND FAILED: ${resendError.code} — ${resendError.message}");
      if (!mounted) return;

      setState(() {
        error = _germanResendError(resendError);
      });
    }
  }

  String _germanResendError(AuthException e) {
    if (e.code == 'over_email_send_rate_limit') {
      final seconds = _extractSeconds(e.message);
      return seconds != null
          ? "Bitte warte noch $seconds Sekunden, bevor du eine neue E-Mail anforderst oder bestätige die vorherige."
          : "Bitte warte kurz, bevor du eine neue E-Mail anforderst.";
    }

    if (e.code == 'over_request_rate_limit' || e.statusCode == '429') {
      return "Zu viele Anfragen. Bitte versuche es in ein paar Minuten erneut.";
    }

    return "E-Mail konnte nicht erneut gesendet werden. Bitte versuche es später erneut.";
  }

  int? _extractSeconds(String message) {
    final match = RegExp(r'(\d+)\s*seconds?').firstMatch(message);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: Colors.black54,
        size: 20,
      ),
      suffixIcon: suffixIcon,
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

              // Card overlaps the header slightly for a layered, modern feel.
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
                            "Bereit?",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: EnduvoColors.text,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Melde dich an, und leg los",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 26),

                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration(
                              label: "Email",
                              icon: Icons.email_outlined,
                            ),
                          ),

                          const SizedBox(height: 14),

                          TextField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            decoration: _inputDecoration(
                              label: "Passwort",
                              icon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: EnduvoColors.muted.withOpacity(0.5),
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => obscurePassword = !obscurePassword,
                                ),
                              ),
                            ),
                          ),

                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            child: error != null
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.error_outline,
                                            color: Colors.redAccent, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            error!,
                                            style: const TextStyle(
                                              color: Colors.redAccent,
                                              fontSize: 13.5,
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
                              onPressed: loading ? null : signIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: EnduvoColors.text,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: EnduvoColors.text.withOpacity(0.65),
                                disabledForegroundColor: Colors.white,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: loading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      "Anmelden",
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
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordPage(),
                                ),
                              ),
                              child: const Text(
                                "Passwort vergessen?",
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

              // Sign-up prompt — dark text now, since the background here
              // is light, not the gradient.
              Transform.translate(
                offset: const Offset(0, -20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Noch kein Konto?",
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpPage()),
                      ),
                      child: const Text(
                        "Registrieren",
                        style: TextStyle(
                          color: EnduvoColors.deepBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
