import 'dart:io';
import 'widgets/select_data.dart';
import 'services/map_service.dart';
import 'widgets/form_controls.dart';
import 'services/image_service.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
final supabase = Supabase.instance.client;

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});
  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  File? postImage;
  bool joinRequestActive = false;
  bool visibleForFollowersActive = false;
  bool visibleForFlintaActive = false;
  String? selectedType = "Run";
  bool posted = false;
  DateTime? selectedDate;
  String? selectedTime;
  int? distance;
  int? pace;
  String? postTown;
  bool _canSubmit = false;
  final selectDataCustom = SelectDataCustom();
  final imageService = ImageService();
  final formControls = FormControls();
  final mapService = MapService();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController activityController = TextEditingController();
  final TextEditingController frequencyController = TextEditingController();
  final TextEditingController townController = TextEditingController();
  final TextEditingController streetController = TextEditingController();
  final TextEditingController distanceController = TextEditingController();
  final TextEditingController paceController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController timeController = TextEditingController();
  final MapController mapController = MapController();

  final mapUrl = 'https://api.maptiler.com/maps/basic-v2-light/256/{z}/{x}/{y}.png?key=yH0AJynJV0qzbwHfR3q0';
  LatLng? mapCenter;

  void _checkFormValidity() {
    final valid =
        titleController.text.trim().isNotEmpty &&
        activityController.text.trim().isNotEmpty &&
        frequencyController.text.trim().isNotEmpty &&
        townController.text.trim().isNotEmpty &&
        distanceController.text.trim().isNotEmpty &&
        paceController.text.trim().isNotEmpty &&
        dateController.text.trim().isNotEmpty &&
        timeController.text.trim().isNotEmpty;

        debugPrint("Checking form validity: $valid");

    if (valid != _canSubmit) {
      setState(() {
        _canSubmit = valid;
      });
    }
  }

  Future<bool> addPostToDatabase() async {
    // insert post
    try {
      final response = await supabase
        .from('posts')
        .insert({
          'title': titleController.text,
          'description': descriptionController.text,
          'activity': activityController.text,
          'frequency': frequencyController.text,
          'distance': distance,
          'pace': pace,
          'date': selectedDate?.toIso8601String(),
          'time': selectedTime,
          'image_url': null,
          'joinrequest_active': joinRequestActive,
          'visibleforfollowers_active': visibleForFollowersActive,
          'visibleforflinta_active': visibleForFlintaActive,
          'latitude': mapCenter?.latitude ?? 0.0,
          'longitude': mapCenter?.longitude ?? 0.0,
          'town': postTown,
          'creator_id': supabase.auth.currentUser!.id,
        })
        .select()
        .single();

      // upload image to supabase storage
      debugPrint("result: $response");
      final postId = response['id'].toString();
      final path = '$postId.png';
      if (postImage != null) {
        await supabase.storage.from('PostImages').upload(
          path, 
          postImage!,
          fileOptions: FileOptions(upsert: true),
        );
        // link url in corresponding post
        final url = supabase.storage.from('PostImages').getPublicUrl(path);
        await supabase.from('posts').update({'image_url': url}).eq('id', postId);
      }
      return true;
    } catch (e) {
      debugPrint("Error adding post to database $e");
      return false;
    }
  }

  Future<File?> getImage() async {
    File? result = await imageService.pickImage();
    if (result != null) {
      result = await imageService.cropImageWithUI(result);
      if (result != null) {
        result = await imageService.compressImage(result);
        return result;
      }
      return null;
    }
    return null;
  }

  Widget _buildDetailOption(
      IconData icon,
      String label,
      TextEditingController controller,
      VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity, // stretch over full line
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.black),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                controller.text.isEmpty ? label : controller.text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: controller.text.isEmpty ? FontWeight.normal : FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            if (controller.text.isEmpty) // optional arrow for empty fields
              const Icon(Icons.keyboard_arrow_down, color: Colors.grey)
          ],
        ),
      ),
    );
  }

  Widget _buildMap(){
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: mapCenter ?? LatLng(51.509364, -0.128928),
          initialZoom: 13,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
          onTap: (tapPosition, point) {
            setState(() {
              mapCenter = point;
              debugPrint("New coordinates: ${point.latitude}, ${point.longitude}");
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate:
              mapUrl,
            userAgentPackageName: 'com.robert.app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: mapCenter ?? LatLng(51.509364, -0.128928),
                width: 70,
                height: 70,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    /// Main activity badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 12,
                              color: Colors.black.withOpacity(0.15),
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_run,
                          color: Color.fromARGB(255, 223, 186, 255),
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    titleController.addListener(_checkFormValidity);
    activityController.addListener(_checkFormValidity);
    frequencyController.addListener(_checkFormValidity);
    townController.addListener(_checkFormValidity);
    distanceController.addListener(_checkFormValidity);
    paceController.addListener(_checkFormValidity);
    dateController.addListener(_checkFormValidity);
    timeController.addListener(_checkFormValidity);
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text(
        "Aktivität Planen",
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
    ),
    body: Column(
        children: [
          Expanded(
            child:SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                children: [
                  // const SizedBox(height: 20),
                  TextField(
                    controller: titleController,
                    cursorColor: Colors.black,
                    decoration: InputDecoration(
                      labelText: "Titel deiner geplanten Aktivität",
                      labelStyle: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.black,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    cursorColor: Colors.black,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: "Coffee run oder doch Intervalle?",
                      labelStyle: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.black,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: activityController,
                          readOnly: true,
                          cursorColor: Colors.grey,
                          decoration: InputDecoration(
                            hintText: "Aktivität",
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: const Color.fromARGB(255, 0, 0, 0),
                              fontWeight: FontWeight.w600
                            ),
                            suffixIcon: const Icon(Icons.keyboard_arrow_down),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                          ),
                          onTap: () async {
                            final result = await selectDataCustom.showActivityDialog(context);
                            if (result != null) {
                              setState(() {
                                activityController.text = result;
                              });
                              _checkFormValidity();
                            }
                          }
                        )
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: frequencyController,
                          readOnly: true,
                          cursorColor: Colors.grey,
                          decoration: InputDecoration(
                            hintText: "Häufigkeit",
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: const Color.fromARGB(255, 0, 0, 0),
                              fontWeight: FontWeight.w600
                            ),
                            suffixIcon: const Icon(Icons.keyboard_arrow_down),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                          ),
                          onTap: () async {
                            final result = await selectDataCustom.showFrequencyDialog(context);
                            if (result != null) {
                              setState(() {
                                frequencyController.text = result;
                              });
                              _checkFormValidity();
                            }
                          }
                        ),
                      ),
                    ]
                  ),
                  const SizedBox(height: 25),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      "Aktivitätsdetails",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailOption(
                          Icons.straighten,
                          "Distanz",
                          distanceController,
                          () async {
                            final result = await selectDataCustom.showDistanceDialog(context);
                            if (result != null) {
                              setState(() {
                                distance = result;
                                final selectedDistance = (result / 1000);
                                distanceController.text =
                                    "${selectedDistance.toStringAsFixed(2).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '')} km";
                              });
                              _checkFormValidity();
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildDetailOption(
                          Icons.speed,
                          "Pace",
                          paceController,
                          () async {
                            final result = await selectDataCustom.showPaceDialog(context);
                            if (result != null) {
                              int minutes = result ~/ 60;
                              int seconds = result % 60;
                              setState(() {
                                pace = result;
                                paceController.text = '$minutes:${seconds.toString().padLeft(2, '0')}/km';
                              });
                              _checkFormValidity();
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildDetailOption(
                          Icons.schedule,
                          "Datum",
                          dateController,
                          () async {
                            final DateTime? result = await selectDataCustom.showCalendarDialog(context);
                            if (result != null) {
                              setState(() {
                                selectedDate = result;
                                dateController.text =
                                    "${result.day.toString().padLeft(2,'0')}.${result.month.toString().padLeft(2,'0')}.${result.year}";
                              });
                              _checkFormValidity();
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildDetailOption(
                          Icons.timer,
                          "Zeit",
                          timeController,
                          () async {
                            final DateTime? result = await selectDataCustom.showTimeDialog(context);
                            if (result != null) {
                              setState(() {
                                selectedTime =
                                    "${result.hour.toString().padLeft(2,'0')}:${result.minute.toString().padLeft(2,'0')}:00";
                                timeController.text =
                                    "${result.hour.toString().padLeft(2,'0')}:${result.minute.toString().padLeft(2,'0')} Uhr";
                              });
                              _checkFormValidity();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      "Medien",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () async {
                      final pickedImage = await getImage();
                      if (pickedImage != null) {
                        setState( () {
                          postImage = pickedImage;
                        });
                      }
                    },
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          // color: const Color.fromARGB(255, 0, 0, 0),
                          width: 2,
                        ),
                        color: Colors.white,
                      ),
                      child: postImage != null
                        ? Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(4.0), // padding on all sides
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                                  child: AspectRatio(
                                    aspectRatio: 1 / 1, // 1:1 ratio
                                    child: Image.file(
                                      postImage!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Text(
                              "Bilder hinzufügen",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      "Einschränkungen",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              "Teilnehmen auf Anfrage",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: formControls.buildSwitch(
                              value: joinRequestActive,
                              onChanged: (newValue) {
                                setState(() {
                                  joinRequestActive = newValue;
                                });
                              },
                            ),
                          ),
                        ]
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              "Nur sichtbar für Follower",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: formControls.buildSwitch(
                              value: visibleForFollowersActive,
                              onChanged: (newValue) {
                                setState(() {
                                  visibleForFollowersActive = newValue;
                                });
                              },
                            ),
                          ),
                        ]
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              "Nur sichtbar für Flinta",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: formControls.buildSwitch(
                              value: visibleForFlintaActive,
                              onChanged: (newValue) {
                                setState(() {
                                  visibleForFlintaActive = newValue;
                                });
                              },
                            ),
                          ),
                        ]
                      )
                    ]
                  ),
                  const SizedBox(height: 25),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      "Standort",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: townController,
                    decoration: InputDecoration(
                      labelText: "Stadt eingeben",
                      labelStyle: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                      ),
                      hintText: "z.B. Erfurt",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.black,
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted: (value) async {
                      if (value.isEmpty) return;
                      final coordinates = await mapService.getCoordinatesFromTown(value);
                      if (coordinates != null) {
                        String? townReturned = await mapService.getTownFromCoordinates(coordinates.latitude, coordinates.longitude);
                        setState(() {
                          mapCenter = coordinates; // update map in UI
                          postTown = townReturned;
                        });
                        mapController.move(coordinates, 13);
                        _checkFormValidity();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: streetController,
                    decoration: InputDecoration(
                      labelText: "Adresse eingeben (optional)",
                      labelStyle: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                      ),
                      hintText: "z.B. Drachengasse 2",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.black,
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted: (value) async {
                      if (value.isEmpty) return;
                      final coordinates = await mapService.getCoordinatesFromTown(value);
                      if (coordinates != null) {
                        String? townReturned = await mapService.getTownFromCoordinates(coordinates.latitude, coordinates.longitude);
                        setState(() {
                          mapCenter = coordinates; // update map in UI
                          postTown = townReturned;
                        });
                        mapController.move(coordinates, 13);
                        _checkFormValidity();
                      }
                    },
                  ),
                  const SizedBox(height: 15),
                  // flutter map
                  ClipRRect(
                    child:
                      _buildMap()
                  ),
                ]
              )
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
            child: ElevatedButton(
              onPressed: () async {
                if (!_canSubmit) return; // early exit if not allowed

                bool success = await addPostToDatabase();
                if (!mounted) return;

                if (success) {
                  Navigator.pop(context, true);
                } else {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      title: const Text(
                        "Fehler",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: const Text(
                        "Post konnte nicht erstellt werden",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                        ),
                      ),
                      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      actions: [
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text(
                            "OK",
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _canSubmit
                    ? const Color.fromARGB(255, 165, 62, 255) // enabled violet
                    : const Color.fromARGB(255, 236, 212, 247), // lighter violet
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Post erstellen",
                style: TextStyle(fontSize: 16),
              ),
            ),
          )
        ],
      ),
    );
  }
}
