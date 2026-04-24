import 'package:flutter/material.dart';
import 'package:run_club/main_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup_page.dart';
import 'feed_page.dart';
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
    // setState -> rebuild UI so it reflects the new state
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await supabase.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),);
        if (response.user != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MainPage(),
              ),
            );
        }
    } on AuthException catch (e) {
      // If login fails → error message
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign In")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: loading ? null : signIn,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text('Continue'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: loading ? null : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignUpPage()),
                );
              },
              icon: const Icon(Icons.login),
              label: const Text('Sign up'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // Example: Forgot password
                print('Forgot password tapped');
              },
              child: const Text('Forgot password?'),
            ),
          ],
        ),
      ),
    );
  }
}