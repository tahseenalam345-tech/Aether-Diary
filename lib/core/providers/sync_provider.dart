import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SyncState { idle, syncing, synced, offline, error }

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier();
});

class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier() : super(SyncState.synced);

  Future<void> triggerSync() async {
    if (state == SyncState.offline) return;
    
    state = SyncState.syncing;
    await Future.delayed(const Duration(milliseconds: 1500));
    state = SyncState.synced;
  }

  void setOfflineState(bool isOffline) {
    state = isOffline ? SyncState.offline : SyncState.synced;
  }
}