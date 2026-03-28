import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/core/services/hive_service.dart';

class CoinNotifier extends Notifier<int> {
  static const String _coinKey = 'userCoins';

  @override
  int build() {
    final box = HiveService.settingsBox;
    return box.get(_coinKey, defaultValue: 0) as int;
  }

  void addCoins(int amount) {
    if (amount <= 0) return;
    
    final newBalance = state + amount;
    state = newBalance;
    HiveService.settingsBox.put(_coinKey, newBalance);
  }

  void removeCoins(int amount) {
    if (amount <= 0) return;
    
    final newBalance = state - amount;
    // Prevent negative balance
    state = newBalance < 0 ? 0 : newBalance;
    HiveService.settingsBox.put(_coinKey, state);
  }
}

final coinProvider = NotifierProvider<CoinNotifier, int>(() {
  return CoinNotifier();
});
