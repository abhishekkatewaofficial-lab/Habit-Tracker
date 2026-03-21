import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/core/services/hive_service.dart';

class ProfileState {
  final String name;
  final String? imagePath;

  ProfileState({required this.name, this.imagePath});

  ProfileState copyWith({String? name, String? imagePath}) {
    return ProfileState(
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}

class ProfileNotifier extends Notifier<ProfileState> {
  static const String _nameKey = 'userName';
  static const String _imageKey = 'profileImagePath';

  @override
  ProfileState build() {
    final box = HiveService.settingsBox;
    final name = box.get(_nameKey, defaultValue: '') as String;
    final imagePath = box.get(_imageKey) as String?;
    
    return ProfileState(name: name, imagePath: imagePath);
  }

  void updateName(String newName) {
    state = state.copyWith(name: newName);
    HiveService.settingsBox.put(_nameKey, newName);
  }

  void updateImagePath(String? path) {
    state = state.copyWith(imagePath: path);
    HiveService.settingsBox.put(_imageKey, path);
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(() {
  return ProfileNotifier();
});
