import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signin_page.dart';
import 'feed_page.dart';
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
      final response =  await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),);
        // If signup succeeded, navigate to HomePage
        if (response.user != null) {
            final userId = response.user!.id; // user signed in
            // Create profile row
            await supabase.from('profiles').insert({
              'id': userId,
              'avatar_url': null, // default null avatar
              // optionally: username, bio, etc.
            });
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FeedPage(title: 'Feed'),
              ),
            );
        }
    } on AuthException catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignInPage()),
                );
              },
              child: const Text('Already have an account? Sign In'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: loading ? null : () {
                signUp(); // call your signup function
              },
              icon: const Icon(Icons.login),
              label: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Continue'),
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