import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/diary_entry.dart';
import '../domain/models/aether_attachment.dart';
import 'diary_repository.dart';
import '../../../core/utils/image_storage_service.dart';
import '../../../core/utils/biometric_service.dart';
import '../../../core/utils/media_storage_service.dart';

// 1. Global Repository & Services
final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  return DiaryRepository();
});

final imageStorageProvider = Provider<ImageStorageService>((ref) {
  return ImageStorageService();
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final mediaStorageProvider = Provider<MediaStorageService>((ref) {
  return MediaStorageService();
});

// 2. The AsyncNotifier
final diaryEntriesProvider = AsyncNotifierProvider<DiaryNotifier, List<DiaryEntry>>(() {
  return DiaryNotifier();
});

class DiaryNotifier extends AsyncNotifier<List<DiaryEntry>> {
  @override
  Future<List<DiaryEntry>> build() async {
    final repo = ref.read(diaryRepositoryProvider);
    await repo.init();
    return await repo.getAllEntries();
  }

  Future<void> addEntry({
    required String title,
    required String content,
    String? mood,
    bool isPinned = false,
    List<String>? tags,
    List<AetherAttachment>? attachments,
  }) async {
    final entry = DiaryEntry(
      title: title,
      content: content,
      mood: mood,
      isPinned: isPinned,
      tags: tags,
      attachments: attachments,
    );
    final repo = ref.read(diaryRepositoryProvider);
    await repo.addEntry(entry);
    
    final currentList = state.valueOrNull ?? [];
    state = AsyncValue.data([entry, ...currentList]);
  }

  Future<void> addEntryObject(DiaryEntry entry) async {
    final repo = ref.read(diaryRepositoryProvider);
    await repo.addEntry(entry);
    
    final currentList = state.valueOrNull ?? [];
    state = AsyncValue.data([entry, ...currentList]);
  }

  Future<void> updateEntry(DiaryEntry entry) async {
    final repo = ref.read(diaryRepositoryProvider);
    await repo.updateEntry(entry);
    
    final currentList = state.valueOrNull ?? [];
    final updatedList = currentList.map((e) => e.id == entry.id ? entry : e).toList();
    state = AsyncValue.data(updatedList);
  }

  Future<void> deleteEntry(String id) async {
    final repo = ref.read(diaryRepositoryProvider);
    await repo.deleteEntry(id);
    
    final currentList = state.valueOrNull ?? [];
    final updatedList = currentList.where((e) => e.id != id).toList();
    state = AsyncValue.data(updatedList);
  }

  Future<void> bulkDelete(List<String> ids) async {
    final repo = ref.read(diaryRepositoryProvider);
    for (final id in ids) {
      await repo.deleteEntry(id);
    }
    final currentList = state.valueOrNull ?? [];
    final updatedList = currentList.where((e) => !ids.contains(e.id)).toList();
    state = AsyncValue.data(updatedList);
  }

  Future<void> bulkPin(List<String> ids, bool pinStatus) async {
    final repo = ref.read(diaryRepositoryProvider);
    final currentList = state.valueOrNull ?? [];
    final List<DiaryEntry> updatedList = [];
    for (final entry in currentList) {
      if (ids.contains(entry.id)) {
        final updated = entry.copyWith(isPinned: pinStatus);
        await repo.updateEntry(updated);
        updatedList.add(updated);
      } else {
        updatedList.add(entry);
      }
    }
    state = AsyncValue.data(updatedList);
  }

  Future<void> bulkMoveFolder(List<String> ids, String folder) async {
    final repo = ref.read(diaryRepositoryProvider);
    final currentList = state.valueOrNull ?? [];
    final List<DiaryEntry> updatedList = [];
    for (final entry in currentList) {
      if (ids.contains(entry.id)) {
        final updated = entry.copyWith(tags: [folder]);
        await repo.updateEntry(updated);
        updatedList.add(updated);
      } else {
        updatedList.add(entry);
      }
    }
    state = AsyncValue.data(updatedList);
  }
}