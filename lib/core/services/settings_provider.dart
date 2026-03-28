import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundsNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadFromPrefs();
    return true; 
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('sounds_enabled') ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sounds_enabled', enabled);
  }
}

class HapticsNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadFromPrefs();
    return true; 
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('haptics_enabled') ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('haptics_enabled', enabled);
  }
}

final soundsProvider = NotifierProvider<SoundsNotifier, bool>(SoundsNotifier.new);
final hapticsProvider = NotifierProvider<HapticsNotifier, bool>(HapticsNotifier.new);

class SmartNudgesNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadFromPrefs();
    return true;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('smart_nudges_enabled') ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('smart_nudges_enabled', enabled);
  }
}

final smartNudgesProvider =
    NotifierProvider<SmartNudgesNotifier, bool>(SmartNudgesNotifier.new);
