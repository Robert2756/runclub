import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';
import 'package:go_router/go_router.dart';

final supabase = Supabase.instance.client;

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
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

  Future<void> resendConfirmationEmail() async {
    try {
      await supabase.auth.resend(
        type: OtpType.signup,
        email: emailController.text.trim(),
      );
      debugPrint("RESEND SUCCESS for ${emailController.text.trim()}");
    } catch (e) {
      debugPrint("RESEND FAILED: $e");
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              color: Colors.white,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Bei Enduvo anmelden",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Password",
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (error != null)
                      Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),

                    const SizedBox(height: 8),

                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: loading ? null : signIn,
                        child: loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text("Anmelden"),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignUpPage(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                      ),
                      child: const Text("Neuen Account anlegen"),
                    ),

                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                      ),
                      style: TextButton.styleFrom(foregroundColor: Colors.black),
                      child: const Text("Passwort vergessen"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}