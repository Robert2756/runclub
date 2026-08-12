import 'package:flutter/material.dart';
import 'package:run_club/main_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup_page.dart';
import 'checkEmailPage.dart';
import 'auth_loading_page.dart';
import 'forgot_password_page.dart';

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

  // simple client-side cooldown so we don't hammer Supabase's resend rate limit
  DateTime? _lastResendAttempt;
  static const _resendCooldown = Duration(seconds: 60);

  Future<void> signIn() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await supabase.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // if (response.user != null && mounted) {
      //   Navigator.of(context).pushAndRemoveUntil(
      //     MaterialPageRoute(builder: (_) => const MainPage()),
      //     (route) => false,
      //   );
      // }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthLoadingPage()),
          (route) => false,
        );
      }

    } on AuthException catch (e) {
      debugPrint("Sign in error: ${e.code} — ${e.message}");

      if (e.code == 'email_not_confirmed') {
        await _handleUnconfirmedEmail();
      } else {
        setState(() => error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _handleUnconfirmedEmail() async {
    final now = DateTime.now();
    final onCooldown = _lastResendAttempt != null &&
        now.difference(_lastResendAttempt!) < _resendCooldown;

    if (onCooldown) {
      // Don't call Supabase again — just send them to check their inbox,
      // the earlier email is still valid.
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CheckEmailPage(email: emailController.text.trim()),
        ),
      );
      return;
    }

    try {
      _lastResendAttempt = now;
      await supabase.auth.resend(
        type: OtpType.signup,
        email: emailController.text.trim(),
      );
      debugPrint("RESEND SUCCESS for ${emailController.text.trim()}");

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CheckEmailPage(email: emailController.text.trim()),
        ),
      );
    } on AuthException catch (resendError) {
      debugPrint("RESEND FAILED: ${resendError.code} — ${resendError.message}");

      setState(() {
        error = resendError.statusCode == '429'
            ? "Zu viele Anfragen. Bitte prüfe dein Postfach oder versuche es in ein paar Minuten erneut."
            : "E-Mail konnte nicht erneut gesendet werden.";
      });
    }
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