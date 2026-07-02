import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signin_page.dart';
import 'feed_page.dart';
import 'checkEmailPage.dart';

final supabase = Supabase.instance.client;

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  String? error;

  Future<void> signUp() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      debugPrint("USER: ${response.user}");
      debugPrint("SESSION: ${response.session}");

      if (response.user == null) {
        setState(() {
          error = "Diese E-Mail ist bereits registriert.";
        });
        return;
      }
      else {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CheckEmailPage(),
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

  String _mapAuthError(String msg) {
    final lower = msg.toLowerCase();

    if (lower.contains("already")) {
      return "Diese E-Mail ist bereits registriert.";
    }

    if (lower.contains("password")) {
      return "Passwort ist zu schwach.";
    }

    if (lower.contains("invalid")) {
      return "Ungültige E-Mail-Adresse.";
    }

    return msg;
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
                            : const Text("Regestrieren"),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: () {
                        Navigator.push(
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