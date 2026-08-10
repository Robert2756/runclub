import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signin_page.dart';
import 'checkEmailPage.dart';

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
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CheckEmailPage(
              email: email,
            ),
          ),
        );
      }

    } on AuthException catch (e) {
      // 👇 THIS is the important part
      debugPrint("Sign up error not mounted: ${e.toString()}");
      if (mounted) {
        debugPrint("Sign up error: ${e.toString()}");
        setState(() {
          error = _mapAuthError(e.message);
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

  String _mapAuthError(String msg) {
    final lower = msg.toLowerCase();
    debugPrint("Auth error: $msg");

    if (lower.contains("already registered") ||
        lower.contains("already exists")) {
      return "Diese E-Mail ist bereits registriert.";
    }

    if (lower.contains("password")) {
      return "Das Passwort erfüllt die Anforderungen nicht.";
    }

    return "Registrierung fehlgeschlagen. Bitte versuche es erneut.";
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
              elevation: 6,
              color: const Color(0xFFF8F9FB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Enduvo Account erstellen",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
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
                        onPressed: loading ? null : signUp,
                        child: loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text("Registrieren"),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignInPage(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                      ),
                      child: const Text(
                        "Du hast schon einen Account")
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