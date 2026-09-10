import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:record/record.dart'; // Audio Recording Engine

class MediaStorageService {
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  // 1. Hardware Video Picker
  Future<File?> pickVideoFromGallery() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) return File(video.path);
    return null;
  }

  // 2. Secure Local Storage
  Future<String> saveMediaToAppStorage(File mediaFile, String extension) async {
    final directory = await getApplicationDocumentsDirectory();
    final String uniqueFileName = const Uuid().v4();
    final String savedPath = '${directory.path}/$uniqueFileName.$extension';
    
    final File savedFile = await mediaFile.copy(savedPath);
    return savedFile.path;
  }

  // --- AUDIO RECORDING ENGINE ---
  Future<bool> hasRecordPermission() async {
    return await _audioRecorder.hasPermission();
  }

  Future<String> startRecording() async {
    if (await hasRecordPermission()) {
      final directory = await getApplicationDocumentsDirectory();
      final String uniqueFileName = const Uuid().v4();
      final String path = '${directory.path}/$uniqueFileName.m4a';
      
      await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      return path;
    }
    throw Exception('Microphone permission denied');
  }

  Future<String?> stopRecording() async {
    return await _audioRecorder.stop();
  }
}