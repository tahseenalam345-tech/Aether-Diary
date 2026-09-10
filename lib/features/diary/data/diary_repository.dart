import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/models/diary_entry.dart';

class DiaryRepository {
  static const String _boxName = 'diary_entries';
  Box<DiaryEntry>? _box;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(DiaryEntryAdapter());
    }

    String? encryptionKeyString;

    try {
      encryptionKeyString = await _secureStorage.read(key: 'hive_encryption_key');
    } catch (e) {
      debugPrint("Ghost key detected and destroyed: $e");
      await _secureStorage.deleteAll();
      encryptionKeyString = null;
    }
    
    if (encryptionKeyString == null) {
      final key = Hive.generateSecureKey();
      await _secureStorage.write(
        key: 'hive_encryption_key',
        value: base64UrlEncode(key),
      );
      encryptionKeyString = base64UrlEncode(key);
    }

    final encryptionKeyUint8List = base64Url.decode(encryptionKeyString);

    _box = await Hive.openBox<DiaryEntry>(
      _boxName,
      encryptionCipher: HiveAesCipher(encryptionKeyUint8List),
    );
  }

  Box<DiaryEntry> get _ensureBox {
    if (_box == null || !_box!.isOpen) {
      throw StateError('CRITICAL: DiaryBox is not initialized. Call init() first.');
    }
    return _box!;
  }

  Future<List<DiaryEntry>> getAllEntries() async {
    try {
      final entries = _ensureBox.values.toList();
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return entries;
    } catch (e) {
      throw Exception('Failed to fetch entries from disk: $e');
    }
  }

  Future<void> addEntry(DiaryEntry entry) async {
    try {
      await _ensureBox.put(entry.id, entry);
    } catch (e) {
      throw Exception('Failed to write entry to disk: $e');
    }
  }

  Future<void> updateEntry(DiaryEntry entry) async {
    try {
      if (!_ensureBox.containsKey(entry.id)) {
        throw Exception('Update failed: Entry with ID ${entry.id} does not exist.');
      }
      await _ensureBox.put(entry.id, entry);
    } catch (e) {
      throw Exception('Failed to update entry on disk: $e');
    }
  }

  // SECURE PATCH: Orphaned Media Cleanup
  Future<void> deleteEntry(String id) async {
    try {
      final entry = _ensureBox.get(id);
      if (entry == null) {
        throw Exception('Delete failed: Entry with ID $id does not exist.');
      }

      // 1. Physically delete attached media files from device storage
      if (entry.attachments.isNotEmpty) {
        for (var attachment in entry.attachments) {
          try {
            final file = File(attachment.path);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            debugPrint('Failed to delete orphaned attachment: $e');
          }
        }
      }

      // 2. Delete the database record
      await _ensureBox.delete(id);
    } catch (e) {
      throw Exception('Failed to delete entry from disk: $e');
    }
  }
}