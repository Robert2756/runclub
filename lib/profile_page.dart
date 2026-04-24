import 'package:flutter/material.dart';
import 'package:run_club/settings_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/app_bar.dart';
import 'dart:io';
import 'services/image_service.dart';
import 'widgets/profile_socialproof.dart';
final imageService = ImageService();

class ProfilePage extends StatefulWidget {
  final String profileId;

  const ProfilePage({
    super.key,
    required this.profileId,
  });
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with RouteAware {
  String? _avatarUrl;
  String? _profileName;
  File? _profileImage;
  final supabase = Supabase.instance.client;

  // upload profile image
  Future<void> uploadProfileImage(String userId, File? compressedImage) async {
    if (compressedImage == null) return;
    final path = '$userId.png'; // lowercase bucket name

    final user = supabase.auth.currentUser;
    debugPrint('User inf: $user');

    await supabase.storage.from('ProfileImages').upload(
      path,
      compressedImage,
      fileOptions: FileOptions(upsert: true),
    );
    // Get public URL as string
    final url = supabase.storage.from('ProfileImages').getPublicUrl(path);
    debugPrint("the url $url");
    // Save URL in profile table
    await supabase.from('profiles').update({'avatar_url': url}).eq('id', userId);
    debugPrint('Test');
  }

  // fetch profile image when loading the page
  Future<void> fetchProfile() async {
    try {
      final response = await supabase
          .from('profiles')
          .select('avatar_url, username')
          .eq('id', widget.profileId)
          .single(); // fetch single row

      setState(() {
        _avatarUrl = response['avatar_url'] as String?;
        _profileName = response['username'] as String?;
        debugPrint("Username $_profileName");
      });
    } catch (e) {
        debugPrint('Error fetching profile image: $e');
    }
  }

  // initial fetch when page is first opened
  @override
  void initState() {
    super.initState();
    fetchProfile(); // fetch avatar from Supabase on page load
  }

  // fetches when coming back to this page
  @override
  void didPopNext() {
    fetchProfile();
  }

  // logic
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppAppBar(
        // title: widget.title,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsPage(title: "Settings"),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Upper section: profile info
          Flexible(
            flex: 1, // 2/5 of height
            child: Container(
              color: Colors.white,
              width: double.infinity,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GestureDetector(
                      onTap: () async {
                        File? compressedImage;
                        final userId = supabase.auth.currentUser!.id;
                        // pick the image and get it as a return value
                        final File? pickedImage = await imageService.pickImage();
                        if (pickedImage != null) {
                          // apply image cropping and compression
                          final File? cropedImage = await imageService.cropImageWithUI(pickedImage);
                          if (cropedImage != null) {
                              compressedImage = await imageService.compressImage(cropedImage);
                          }
                          // Upload to Supabase storage then update profile image
                          try {
                            await uploadProfileImage(userId, compressedImage);
                            // update UI
                            setState(() {
                              _profileImage = compressedImage;
                            });
                          } catch (e) {
                            debugPrint('Upload failed: $e');
                            // show error message in UI
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to upload profile image.')),
                            );
                          }
                        }
                      },
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!) // local picked image
                            : (_avatarUrl != null
                                ? NetworkImage(_avatarUrl!) // online image
                                : const NetworkImage("https://media.istockphoto.com/id/2221502929/de/vektor/flache-abbildung-in-graustufen-avatar-benutzerprofil-personensymbol-geschlechtsneutrale.jpg?s=1024x1024&w=is&k=20&c=HPtiDlnRhYCCokIwroinbU-dl9hQWtucr7xefhM8Y6g=")),
                      )
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center, // center vertically
                    crossAxisAlignment: CrossAxisAlignment.start,  // left-align text
                    children: [
                      // Text(_profileName ?? "Username",
                      Text(_profileName ?? "Username",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4), // small spacing between username and bio
                      Text("Bio goes here", style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ],
            ),
            ),
          ),

          // Lower section: posts
          Flexible(
            child:
              SocialProofCard(togetherCount: 3, lastTogether: DateTime(2026, 4, 8), username: "Auren")
          ),
          Flexible(
            child:
              MiniEndorsement(text: "test", author: "test")
          )
        ],
      ),
    );
  }
}