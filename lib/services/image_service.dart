import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;

class ImageService {
  final ImagePicker _picker = ImagePicker();

  Future<File?> pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      return File(image.path);
    }
    return null;
  }

  Future<File?> cropImageWithUI(File pickedFile) async {
    final CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 100,
      maxWidth: 1000, // 1200,
      maxHeight: 1000, // 900,
    );

    if (croppedFile == null) return null;
    return File(croppedFile.path);
  }

  Future<File> compressImage(File file,
      {int maxWidth = 500, int maxHeight = 500, int quality = 80}) async {

    final bytes = await file.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return file;

    img.Image resized = img.copyResize(image, width: maxWidth, height: maxHeight);
    final compressedBytes = img.encodeJpg(resized, quality: quality);

    final tempDir = Directory.systemTemp;
    final tempFile =
        File('${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');

    await tempFile.writeAsBytes(Uint8List.fromList(compressedBytes));

    return tempFile;
  }
}