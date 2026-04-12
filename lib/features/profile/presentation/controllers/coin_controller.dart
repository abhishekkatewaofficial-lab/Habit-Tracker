import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/core/services/hive_service.dart';
import 'package:habit_tracker_ios/core/services/cloud_sync_service.dart';

class CoinNotifier extends Notifier<int> {
  static const String _coinKey = 'userCoins';

  @override
  int build() {
    // Re-evaluate whenever external sync brings new profile data
    ref.watch(syncRefreshProvider);
    
    final box = HiveService.settingsBox;
    
    // Safety check for first-time onboarding
    final hasReceived = box.get('hasReceivedWelcomeCoins', defaultValue: false) as bool;
    if (!hasReceived) {
      box.put('hasReceivedWelcomeCoins', true);
      box.put(_coinKey, 1000);
      FirestoreSyncService.pushProfile(null, null, coins: 1000);
      
      // Dispatch async UI ping for Welcome animation
      Future.microtask(() {
        ref.read(welcomeCoinsGrantedProvider.notifier).state = true;
      });
      
      return 1000;
    }

    return box.get(_coinKey, defaultValue: 0) as int;
  }

  void addCoins(int amount) {
    if (amount <= 0) return;
    
    final newBalance = state + amount;
    state = newBalance;
    HiveService.settingsBox.put(_coinKey, newBalance);
    FirestoreSyncService.pushProfile(null, null, coins: newBalance);
  }

  void removeCoins(int amount) {
    if (amount <= 0) return;
    
    final newBalance = state - amount;
    // Prevent negative balance
    state = newBalance < 0 ? 0 : newBalance;
    HiveService.settingsBox.put(_coinKey, state);
    FirestoreSyncService.pushProfile(null, null, coins: state);
  }
}

final coinProvider = NotifierProvider<CoinNotifier, int>(() {
  return CoinNotifier();
});

/// Pulse provider — fires `true` for a brief moment when coins are
/// successfully granted. Home screen listens and shows the +10 animation,
/// then immediately resets to `false`.
final coinRewardedProvider = StateProvider<bool>((ref) => false);

/// Pulse provider — fires `true` when coins are spent (e.g. streak protection).
/// Home screen listens and shows a brief -50 toast, then resets to `false`.
final coinDeductedProvider = StateProvider<bool>((ref) => false);

/// Pulse provider — fires `true` exactly once per lifetime for onboarding users.
final welcomeCoinsGrantedProvider = StateProvider<bool>((ref) => false);
