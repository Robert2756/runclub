import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class ResetPasswordPage extends StatefulWidget {
  final VoidCallback onRecoveryFinished;

  const ResetPasswordPage({
    super.key,
    required this.onRecoveryFinished
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;
  String? _error;
  // bool _recoveryCompleted = false;

  Future<void> _submit() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 8) {
      setState(() => _error = 'Das Passwort muss mindestens 8 Zeichen lang sein.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Die Passwörter stimmen nicht überein.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;
      context.go('/signin');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwort wurde aktualisiert. Bitte melde dich an.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.code == 'same_password'
            ? 'Das neue Passwort muss sich vom alten unterscheiden.'
            : 'Das Passwort konnte nicht aktualisiert werden. Bitte versuche es erneut.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Etwas ist schiefgelaufen. Bitte versuche es erneut.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // No back button — a partially-completed recovery session
      // shouldn't be abandoned back into a stale screen.
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Neues Passwort festlegen',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                hintText: 'Neues Passwort',
                filled: true,
                fillColor: const Color(0xFFF3F3F3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Passwort bestätigen',
                filled: true,
                fillColor: const Color(0xFFF3F3F3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(fontSize: 13, color: Colors.redAccent)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Passwort speichern'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
