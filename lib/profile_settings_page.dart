import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_page.dart'; // for EnduvoColors

class ProfileSettingsPage extends StatefulWidget {
  final String title;

  const ProfileSettingsPage({super.key, required this.title});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final supabase = Supabase.instance.client;
  bool _signingOut = false;
  bool _deletingAccount = false;

  // --- Sign out: identical to the dialog/flow that used to live on
  // the profile page's app bar icon. ---
  Future<void> _handleSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Abmelden?',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Möchtest du dich wirklich von deinem Konto abmelden?',
            style: TextStyle(
              color: Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Abmelden'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true) return;
    setState(() => _signingOut = true);

    try {
      await supabase.auth.signOut();
      // Pop back out of Settings; whatever listens for
      // currentUser == null (as ProfilePage's build() already does)
      // will take it from there.
      // if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Logout failed: $e');

      if (!mounted) return;
      setState(() => _signingOut = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Abmelden fehlgeschlagen. Bitte erneut versuchen.'),
        ),
      );
    }
  }

  // --- Delete account: new. Requires a server-side Edge Function
  // (service-role key) — see the companion snippet below. ---
  Future<void> _handleDeleteAccount() async {
    final confirmController = TextEditingController();
    bool canConfirm = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Konto löschen',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Diese Aktion kann nicht rückgängig gemacht werden. Dein Profil, '
                      'deine Aktivitäten und alle zugehörigen Daten werden dauerhaft gelöscht.\n\n'
                      'Gib "LÖSCHEN" ein, um zu bestätigen.',
                      style: TextStyle(fontSize: 14, height: 1.3, color: Colors.black87),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmController,
                      onChanged: (val) {
                        setModalState(() => canConfirm = val.trim() == 'LÖSCHEN');
                      },
                      decoration: InputDecoration(
                        hintText: 'LÖSCHEN',
                        filled: true,
                        fillColor: EnduvoColors.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: EnduvoColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            style: TextButton.styleFrom(foregroundColor: Colors.black),
                            child: const Text('Abbrechen'),
                          ),
                        ),
                        Expanded(
                          child: FilledButton(
                            onPressed: canConfirm ? () => Navigator.pop(dialogContext, true) : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.red.withOpacity(0.3),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Löschen'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _deletingAccount = true);
    try {
      // Runs server-side with the service-role key and deletes the
      // caller's own row from auth.users. Everything FK'd to it
      // (profiles, posts, activity_participants, notifications, ...)
      // cascades automatically, as long as those FKs are declared
      // ON DELETE CASCADE.
      final res = await supabase.functions.invoke('delete_function');

      if (res.status != 200) {
        throw Exception('Edge function returned status ${res.status}: ${res.data}');
      }

      // Belt-and-suspenders: clear the local session too.
      await supabase.auth.signOut();

      //if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Delete account failed: $e');
      if (!mounted) return;
      setState(() => _deletingAccount = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konto konnte nicht gelöscht werden. Bitte erneut versuchen.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnduvoColors.background,
      appBar: AppBar(
        backgroundColor: EnduvoColors.background,
        elevation: 0,
        foregroundColor: EnduvoColors.text,
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SettingsTile(
              icon: Icons.logout,
              label: 'Abmelden',
              loading: _signingOut,
              onTap: _signingOut ? null : _handleSignOut,
            ),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.delete_outline,
              label: 'Konto löschen',
              destructive: true,
              loading: _deletingAccount,
              onTap: _deletingAccount ? null : _handleDeleteAccount,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;
  final bool loading;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.destructive = false,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.red : EnduvoColors.text;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: EnduvoColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}