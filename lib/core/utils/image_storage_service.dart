import 'dart:io';
import 'dart:isolate';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img; // Requires: flutter pub add image

class _ThumbnailPayload {
  final String originalPath;
  final String thumbnailPath;
  _ThumbnailPayload(this.originalPath, this.thumbnailPath);
}

class ImageStorageService {
  final ImagePicker _picker = ImagePicker();

  /// Opens the device gallery and allows the user to pick an image.
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100, 
      );
      
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  /// SCALABILITY OPTIMIZATION: Background Isolate Thumbnail Generation
  /// Generates a lightweight version of the image to prevent OOM memory crashes 
  /// when rendering large lists of diary entries.
  static void _generateThumbnailInIsolate(_ThumbnailPayload payload) {
    try {
      final originalFile = File(payload.originalPath);
      final bytes = originalFile.readAsBytesSync();
      
      // Decode image
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) return;

      // Resize to a memory-safe maximum width (400px), maintaining aspect ratio
      final thumbnail = img.copyResize(decodedImage, width: 400);

      // Encode heavily compressed JPG
      final thumbBytes = img.encodeJpg(thumbnail, quality: 70);
      
      File(payload.thumbnailPath).writeAsBytesSync(thumbBytes);
    } catch (e) {
      print("Thumbnail generation failed silently: $e");
    }
  }

  /// Copies a temporary file into the app's secure, permanent directory,
  /// and spawns a background isolate to generate a lightweight thumbnail.
  Future<String> saveImageToAppStorage(File imageFile) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      
      final fileExtension = path.extension(imageFile.path);
      final uniqueFileName = '${const Uuid().v4()}$fileExtension';
      
      final savedImagePath = path.join(directory.path, uniqueFileName);
      final savedFile = await imageFile.copy(savedImagePath);
      
      // Compute the thumbnail path natively without mutating Hive structure
      final thumbnailPath = getThumbnailPath(savedFile.path);
      
      // Spawn background thread (does not lock the UI)
      await Isolate.run(() => _generateThumbnailInIsolate(_ThumbnailPayload(savedFile.path, thumbnailPath)));
      
      return savedFile.path;
    } catch (e) {
      throw Exception('Failed to save image locally: $e');
    }
  }

  /// Helper to safely retrieve the thumbnail path from the original path
  String getThumbnailPath(String originalPath) {
    return '$originalPath.thumb.jpg';
  }

  /// Deletes both the original image and its cached thumbnail
  Future<void> deleteImageFromStorage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
      
      final thumbFile = File(getThumbnailPath(imagePath));
      if (await thumbFile.exists()) {
        await thumbFile.delete();
      }
    } catch (e) {
      print('Warning: Could not delete image/thumbnail. Error: $e');
    }
  }
}