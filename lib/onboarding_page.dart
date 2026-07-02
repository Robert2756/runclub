import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_page.dart';

final supabase = Supabase.instance.client;

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final usernameController = TextEditingController();
  final nameController = TextEditingController();

  bool loading = false;
  String? error;
  bool usernameValid = true;

  Future<bool> checkUsernameAvailable(String username) async {
    if (username.isEmpty) return false;

    final res = await supabase
        .from('profiles')
        .select('id')
        .eq('username', username);

    return (res as List).isEmpty;
  }

  Future<void> saveProfile() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception("Not authenticated");
      }

      final username = usernameController.text.trim();
      final name = nameController.text.trim();

      final available = await checkUsernameAvailable(username);

      if (!available) {
        setState(() {
          usernameValid = false;
          loading = false;
        });
        return;
      }

      await supabase.from('profiles').update({
        'username': username,
        'full_name': name,
        'onboarding_completed': true,
        // 'avatar_url': "assets/defaultAvatar.jpeg",
      }).eq('id', user.id);

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainPage(),
        ),
        (route) => false,
      );
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
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
                      "Lass uns dein Profil einrichten",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        labelText: "Username",
                        prefixIcon: const Icon(Icons.alternate_email),
                        errorText: usernameValid ? null : "Username schon vorhanden",
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: "Name",
                        prefixIcon: Icon(Icons.person_outline),
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
                        onPressed: loading ? null : saveProfile,
                        child: loading
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : const Text("Weiter"),
                      ),
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