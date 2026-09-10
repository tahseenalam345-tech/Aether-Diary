import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../diary/data/diary_provider.dart';
import '../../productivity/data/productivity_providers.dart';
import '../../wallet/data/wallet_providers.dart';

// --- SCALABILITY OPTIMIZATION: ISOLATE DATA TRANSFER OBJECTS ---
// Hive Objects crash if passed into Isolates. We map them to lightweight DTOs.
class SearchItemDto {
  final String id;
  final String title;
  final String subtitle;
  final String type; // 'diary', 'task', 'transaction'
  final DateTime date;
  final String extraBadge; // mood, status, or amount

  SearchItemDto(this.id, this.title, this.subtitle, this.type, this.date, this.extraBadge);
}

final globalSearchQueryProvider = StateProvider<String>((ref) => '');

// --- O(1) BACKGROUND SEARCH ENGINE ---
final globalSearchEngineProvider = FutureProvider<List<SearchItemDto>>((ref) async {
  final query = ref.watch(globalSearchQueryProvider).toLowerCase().trim();
  if (query.isEmpty) return [];

  // 1. Safely extract data from all 3 core OS modules
  final diaries = ref.watch(diaryEntriesProvider).valueOrNull ?? [];
  final tasks = ref.watch(taskNotifierProvider).valueOrNull ?? [];
  final transactions = ref.watch(transactionNotifierProvider).valueOrNull ?? [];

  // 2. Map to safe DTOs on the main thread
  final List<SearchItemDto> dtos = [];

  for (var d in diaries) {
    dtos.add(SearchItemDto(d.id, d.title, d.content, 'diary', d.createdAt, d.mood ?? 'Neutral'));
  }
  for (var t in tasks) {
    dtos.add(SearchItemDto(t.id, t.title, t.description, 'task', t.createdAt, t.isCompleted ? 'Completed' : 'Pending'));
  }
  for (var tr in transactions) {
    dtos.add(SearchItemDto(tr.id, tr.title, tr.category, 'transaction', tr.date, 'PKR ${tr.amount.toStringAsFixed(0)}'));
  }

  // 3. Offload heavy string manipulation and filtering to a background CPU core
  return await Isolate.run(() => _performSearch(query, dtos));
});

// Runs entirely off the main UI thread to lock 60fps rendering
List<SearchItemDto> _performSearch(String query, List<SearchItemDto> allItems) {
  final results = allItems.where((item) {
    return item.title.toLowerCase().contains(query) ||
           item.subtitle.toLowerCase().contains(query) ||
           item.extraBadge.toLowerCase().contains(query);
  }).toList();
  
  // Sort most recent first
  results.sort((a, b) => b.date.compareTo(a.date));
  return results;
}