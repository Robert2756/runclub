import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main_page.dart';
import 'signin_page.dart';
import 'services/image_service.dart';

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


      final available =
          await checkUsernameAvailable(username);


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
            padding: const EdgeInsets.all(24),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [

                Container(
                  height: 52,
                  width: 52,

                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),

                  child: const Icon(
                    Icons.person_outline,
                    size: 26,
                    color: Colors.black,
                  ),
                ),


                const SizedBox(height: 18),


                const Text(
                  "Profil erstellen abbrechen?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),


                const SizedBox(height: 10),


                Text(
                  "Dein Profil ist noch nicht fertig eingerichtet. "
                  "Du kannst später weitermachen.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),


                const SizedBox(height: 24),


                SizedBox(
                  width: double.infinity,
                  height: 46,

                  child: ElevatedButton(
                    onPressed: () {

                      Navigator.pop(context);

                    },

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,

                      elevation: 0,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),

                    child: const Text(
                      "Weiter einrichten",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),


                const SizedBox(height: 10),


                SizedBox(
                  width: double.infinity,
                  height: 46,

                  child: TextButton(

                    onPressed: () async {

                      await supabase.auth.signOut();

                      if (!mounted) return;

                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const SignInPage(),
                        ),
                        (route) => false,
                      );

                    },


                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),

                    child: const Text(
                      "Abmelden",
                      style: TextStyle(
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


        await supabase.storage
            .from('ProfileImages')
            .upload(
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

            'username':
                usernameController.text.trim(),

            'full_name':
                nameController.text.trim(),

            'bio':
                bioController.text.trim(),

            'town':
                townController.text.trim(),

            if (avatarUrl != null)
              'avatar_url': avatarUrl,


            'onboarding_completed': true,

          })
          .eq('id', user.id);



      if (!mounted) return;


      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainPage(),
        ),
        (_) => false,
      );


    } catch(e) {

      setState(() {
        error = e.toString();
      });

    } finally {

      if(mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

    // upload profile image
  Future<void> uploadProfileImage(String userId, File? compressedImage) async {
    if (compressedImage == null) return;
    final path = '$userId.png'; // lowercase bucket name

    await supabase.storage.from('ProfileImages').upload(
      path,
      compressedImage,
      fileOptions: FileOptions(upsert: true),
    );
    // Get public URL as string
    final url = supabase.storage.from('ProfileImages').getPublicUrl(path);
    // Save URL in profile table
    await supabase.from('profiles').update({'avatar_url': url}).eq('id', userId);
  }

  void pickImage() async {
    File? compressedImage;
    final File? pickedImage = await imageService.pickImage();
    final userId = supabase.auth.currentUser!.id;
    if (pickedImage != null) {
      final File? cropedImage = await imageService.cropImageWithUI(pickedImage);
      if (cropedImage != null) {
        compressedImage = await imageService.compressImage(cropedImage);
      }
      // Upload to Supabase storage then update profile image
      try {
        await uploadProfileImage(userId, compressedImage);
        // update UI
        setState(() {
          profileImage = compressedImage;
        });
      } catch (e) {
        debugPrint('Upload failed: $e');
        // show error message in UI
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload profile image.')),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {


    return Scaffold(

      backgroundColor: Colors.white,


      body: SafeArea(

        child: Column(

          children: [


            Padding(
              padding: const EdgeInsets.only(
                top: 20,
              ),
              child: Text(
                "${currentStep + 1}/3",
                style: TextStyle(
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),



            Expanded(

              child: PageView(

                controller: _pageController,

                physics:
                    const NeverScrollableScrollPhysics(),


                onPageChanged: (index){

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

              padding: const EdgeInsets.all(20),

              child: Row(

                children: [

                  Expanded(

                    child: TextButton(

                      onPressed: previousPage,

                      child: const Text(
                        "Zurück",
                        style: TextStyle(
                          color: Colors.black,
                        ),
                      ),

                    ),

                  ),



                  Expanded(

                    child: ElevatedButton(

                      onPressed:
                          loading ? null : nextPage,


                      style:
                          ElevatedButton.styleFrom(

                        backgroundColor:
                            Colors.black,

                        foregroundColor:
                            Colors.white,

                        shape:
                            RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),

                      ),


                      child:

                      loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                              CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )

                          : Text(
                              currentStep == 2
                                  ? "Profil erstellen"
                                  : "Weiter",
                            ),

                    ),

                  ),

                ],

              ),

            )

          ],

        ),

      ),

    );
  }




  Widget buildIdentityStep(){

    return buildCard(

      title: "Erstelle dein Profil",

      subtitle:
          "Damit andere dich erkennen können.",


      children: [

        modernField(
          "Username",
          usernameController,
          Icons.alternate_email,
        ),


        const SizedBox(height:14),


        modernField(
          "Name",
          nameController,
          Icons.person_outline,
        ),


      ],

    );

  }





  Widget buildAboutStep(){

    return buildCard(

      title:
          "Erzähl etwas über dich",

      subtitle:
          "Hilf anderen, dich kennenzulernen.",


      children: [

        modernField(
          "Beschreibung",
          bioController,
          Icons.notes,
          maxLines: 3,
        ),


        const SizedBox(height:14),


        modernField(
          "Ort",
          townController,
          Icons.location_on_outlined,
        ),

      ],

    );

  }





  Widget buildImageStep(){

    return buildCard(

      title:
          "Zeige dein Gesicht",

      subtitle:
          "Ein Profilbild macht dein Profil persönlicher.",


      children: [

        GestureDetector(

          onTap: pickImage,

          child: CircleAvatar(

            radius: 55,

            backgroundColor:
                Colors.grey[200],


            backgroundImage:
                profileImage != null
                ? FileImage(profileImage!)
                : null,


            child:
                profileImage == null
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

  }){


    return Center(

      child: SingleChildScrollView(

        padding:
            const EdgeInsets.all(20),


        child: Container(

          padding:
              const EdgeInsets.all(24),


          decoration:
              BoxDecoration(

            color:
                Colors.grey[50],


            borderRadius:
                BorderRadius.circular(20),

          ),


          child: Column(

            children: [

              Text(
                title,
                style:
                    const TextStyle(
                      fontSize:24,
                      fontWeight:
                          FontWeight.bold,
                    ),
              ),


              const SizedBox(height:10),


              Text(
                subtitle,
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                      color:
                          Colors.grey[600],
                    ),
              ),


              const SizedBox(height:25),


              ...children,

              if(error != null) ...[

                const SizedBox(height:15),

                Text(
                  error!,
                  style:
                      const TextStyle(
                        color: Colors.red,
                      ),
                )

              ]

            ],

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

  }){


    return TextField(

      controller: controller,

      maxLines: maxLines,


      decoration:

      InputDecoration(

        labelText: label,

        prefixIcon:
            Icon(icon),


        filled:true,

        fillColor:
            Colors.white,


        border:
            OutlineInputBorder(

          borderRadius:
              BorderRadius.circular(14),

          borderSide:
              BorderSide.none,

        ),

      ),

    );

  }

}