import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_page.dart';
import 'signin_page.dart';
import 'services/image_service.dart';
import 'package:go_router/go_router.dart';

final imageService = ImageService();
final supabase = Supabase.instance.client;

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();

  int currentStep = 0;

  final usernameController = TextEditingController();
  final nameController = TextEditingController();
  final bioController = TextEditingController();
  final townController = TextEditingController();

  File? profileImage;

  bool loading = false;
  bool usernameValid = true;
  String? error;

  @override
  void dispose() {
    _pageController.dispose();
    usernameController.dispose();
    nameController.dispose();
    bioController.dispose();
    townController.dispose();
    super.dispose();
  }

  Future<bool> checkUsernameAvailable(String username) async {
    if (username.isEmpty) return false;

    final result = await supabase
        .from('profiles')
        .select('id')
        .eq('username', username);

    return (result as List).isEmpty;
  }

  void nextPage() async {
    if (currentStep == 0) {
      final username = usernameController.text.trim();
      final name = nameController.text.trim();

      if (username.isEmpty || name.isEmpty) {
        setState(() {
          error = "Bitte fülle alle Felder aus.";
        });
        return;
      }

      final available = await checkUsernameAvailable(username);

      if (!available) {
        setState(() {
          usernameValid = false;
          error = "Dieser Username ist bereits vergeben.";
        });
        return;
      }

      setState(() {
        error = null;
      });
    }

    if (currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      await finishOnboarding();
    }
  }

  void _showExitSetupDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.25),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Subtle brand accent
                Container(
                  height: 54,
                  width: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3F7),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    size: 27,
                    color: EnduvoColors.deepBlue,
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  "Profil erstellen abbrechen?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: EnduvoColors.text,
                    letterSpacing: -0.2,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "Dein Profil ist noch nicht fertig. \n"
                  "Du kannst später weitermachen.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: 200, // double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EnduvoColors.text,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Weiter einrichten",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: () async {
                      await supabase.auth.signOut();
                      if (!mounted) return;
                      context.go('/signin');
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Abmelden",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void previousPage() {
    if (currentStep == 0) {
      _showExitSetupDialog();
    } else {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> finishOnboarding() async {
    setState(() {
      loading = true;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception("Nicht eingeloggt");
      }

      String? avatarUrl;

      if (profileImage != null) {
        final path = "${user.id}.png";

        await supabase.storage.from('ProfileImages').upload(
          path,
          profileImage!,
          fileOptions: const FileOptions(
            upsert: true,
          ),
        );

        avatarUrl = supabase.storage
            .from('ProfileImages')
            .getPublicUrl(path);
      }

      await supabase
          .from('profiles')
          .update({
            'username': usernameController.text.trim(),
            'full_name': nameController.text.trim(),
            'bio': bioController.text.trim(),
            'town': townController.text.trim(),
            if (avatarUrl != null) 'avatar_url': avatarUrl,
            'onboarding_completed': true,
          })
          .eq('id', user.id);

      if (!mounted) return;
      context.go('/main');
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // upload profile image
  Future<void> uploadProfileImage(
    String userId,
    File? compressedImage,
  ) async {
    if (compressedImage == null) return;

    final path = '$userId.png';

    await supabase.storage.from('ProfileImages').upload(
      path,
      compressedImage,
      fileOptions: FileOptions(upsert: true),
    );

    final url = supabase.storage
        .from('ProfileImages')
        .getPublicUrl(path);

    await supabase
        .from('profiles')
        .update({'avatar_url': url})
        .eq('id', userId);
  }

  void pickImage() async {
    File? compressedImage;

    final File? pickedImage = await imageService.pickImage();
    final userId = supabase.auth.currentUser!.id;

    if (pickedImage != null) {
      final File? cropedImage =
          await imageService.cropImageWithUI(pickedImage);

      if (cropedImage != null) {
        compressedImage =
            await imageService.compressImage(cropedImage);
      }

      try {
        await uploadProfileImage(userId, compressedImage);

        setState(() {
          profileImage = compressedImage;
        });
      } catch (e) {
        debugPrint('Upload failed: $e');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload profile image.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SafeArea(
        child: Column(
          children: [
            // Minimal progress indicator.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                children: List.generate(
                  3,
                  (index) {
                    final active = index <= currentStep;

                    return Expanded(
                      child: Container(
                        height: 3,
                        margin: EdgeInsets.only(
                          right: index < 2 ? 6 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? EnduvoColors.deepBlue
                              : EnduvoColors.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    currentStep = index;
                  });
                },
                children: [
                  buildIdentityStep(),
                  buildAboutStep(),
                  buildImageStep(),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: previousPage,
                      style: TextButton.styleFrom(
                        foregroundColor: EnduvoColors.text,
                        minimumSize: const Size(0, 50),
                      ),
                      child: const Text(
                        "Zurück",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: loading ? null : nextPage,
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
                            : Text(
                                currentStep == 2
                                    ? "Profil erstellen"
                                    : "Weiter",
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildIdentityStep() {
    return buildCard(
      title: "Erstelle dein Profil",
      subtitle: "Damit andere dich erkennen können.",
      children: [
        modernField(
          "Username",
          usernameController,
          Icons.alternate_email,
        ),
        const SizedBox(height: 14),
        modernField(
          "Name",
          nameController,
          Icons.person_outline,
        ),
      ],
    );
  }

  Widget buildAboutStep() {
    return buildCard(
      title: "Erzähl etwas über dich",
      subtitle: "Hilf anderen, dich kennenzulernen.",
      children: [
        modernField(
          "Beschreibung",
          bioController,
          Icons.notes,
          maxLines: 3,
        ),
        const SizedBox(height: 14),
        modernField(
          "Ort",
          townController,
          Icons.location_on_outlined,
        ),
      ],
    );
  }

  Widget buildImageStep() {
    return buildCard(
      title: "Zeige dein Gesicht",
      subtitle: "Ein Profilbild macht dein Profil persönlicher.",
      children: [
        GestureDetector(
          onTap: pickImage,
          child: CircleAvatar(
            radius: 55,
            backgroundColor: Colors.grey[200],
            backgroundImage: profileImage != null
                ? FileImage(profileImage!)
                : null,
            child: profileImage == null
                ? const Icon(
                    Icons.add_a_photo_outlined,
                    size: 32,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget buildCard({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Center(
      child: SingleChildScrollView(
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
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: EnduvoColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 26),
                ...children,
                if (error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget modernField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
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
      ),
    );
  }
}