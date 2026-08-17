import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signin_page.dart';
import 'checkEmailPage.dart';
import 'package:go_router/go_router.dart';

final supabase = Supabase.instance.client;

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  String? error;

  Future<void> signUp() async {
    final email = emailController.text;
    final password = passwordController.text;
    final validationError = _validateInput(email, password);

    if (validationError != null) {
      setState(() {
        error = validationError;
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final identities = response.user!.identities;

        if (identities != null && identities.isEmpty) {
          // Email already exists and is confirmed — no new email was sent.
          if (!mounted) return;
          setState(() {
            error = "Diese E-Mail-Adresse ist bereits registriert. "
                "Bitte melde dich an oder setze dein Passwort zurück.";
          });
          return;
        }

        // Genuine new signup.
        if (!mounted) return;
        context.go('/check-email?email=${Uri.encodeComponent(emailController.text.trim())}');
      }
    } on AuthException catch (e) {
      // 👇 THIS is the important part
      debugPrint("Sign up error not mounted: ${e.toString()}");
      if (mounted) {
        debugPrint("Sign up error: ${e.toString()}");
        setState(() {
          error = _mapAuthError(e);
        });
      }
    } on SocketException {
      setState(() {
        error = "Keine Internetverbindung.";
      });
    } catch (e) {
      debugPrint("Sign up error no mounted: ${e.toString()}");
      if (mounted) {
        debugPrint("Sign up error: ${e.toString()}");
        setState(() {
          error = "Unexpected error occurred";
        });
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String? _validateInput(String email, String password) {
    if (email.isEmpty) {
      return "Bitte gib eine E-Mail-Adresse ein.";
    }

    if (email != email.trim()) {
      return "Die E-Mail-Adresse darf keine Leerzeichen enthalten.";
    }

    if (password.isEmpty) {
      return "Bitte gib ein Passwort ein.";
    }

    if (password.contains(' ')) {
      return "Das Passwort darf keine Leerzeichen enthalten.";
    }

    final emailRegex = RegExp(
      r'^[\w\.\+\-]+@[\w\.-]+\.\w+$',
    );

    if (!emailRegex.hasMatch(email)) {
      return "Bitte gib eine gültige E-Mail-Adresse ein.";
    }

    if (password.length < 8) {
      return "Das Passwort muss mindestens 8 Zeichen enthalten.";
    }

    if (password.length > 72) {
      return "Das Passwort darf maximal 72 Zeichen enthalten.";
    }

    return null;
  }

  String _mapAuthError(AuthException e) {
    final lower = e.message.toLowerCase();
    debugPrint("Auth error: ${e.code} — ${e.message}");

    if (e.code == 'over_email_send_rate_limit') {
      final seconds = _extractSeconds(e.message);
      return seconds != null
          ? "Bitte warte noch $seconds Sekunden, bevor du eine neue E-Mail anforderst oder bestätige die vorherige."
          : "Bitte warte kurz, bevor du eine neue E-Mail anforderst.";
    }

    if (lower.contains("already registered") ||
        lower.contains("already exists")) {
      return "Diese E-Mail ist bereits registriert.";
    }

    if (lower.contains("password")) {
      return "Das Passwort erfüllt die Anforderungen nicht.";
    }

    return "Registrierung fehlgeschlagen. Bitte versuche es erneut.";
  }

  int? _extractSeconds(String message) {
    final match = RegExp(r'(\d+)\s*seconds?').firstMatch(message);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
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
                            "Konto erstellen",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: EnduvoColors.text,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            "Registriere dich, und leg los",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
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
                            obscureText: true,
                            decoration: _inputDecoration(
                              label: "Passwort",
                              icon: Icons.lock_outline,
                            ),
                          ),

                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            child: error != null
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          color: Colors.redAccent,
                                          size: 18,
                                        ),
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
                              onPressed: loading ? null : signUp,
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
                                      "Registrieren",
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
                              onPressed: () {
                                context.go('/signin');
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: EnduvoColors.muted,
                              ),
                              child: const Text(
                                "Du hast schon einen Account?",
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