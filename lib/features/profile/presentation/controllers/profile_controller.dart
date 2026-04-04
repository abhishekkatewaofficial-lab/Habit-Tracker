import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/core/services/hive_service.dart';
import 'package:habit_tracker_ios/core/services/auth_service.dart';
import 'package:habit_tracker_ios/core/services/cloud_sync_service.dart';

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

class ProfileNotifier extends AutoDisposeNotifier<ProfileState> {
  static const String _nameKey = 'userName';
  static const String _imageKey = 'profileImagePath';

  @override
  ProfileState build() {
    // Watch UID so this provider rebuilds on every user switch.
    final uid = ref.watch(currentUidProvider);
    
    // Watch syncRefreshProvider so it instantly updates when cloud push/pull changes name/avatar
    ref.watch(syncRefreshProvider);

    // If no user is logged in, return an empty state immediately.
    if (uid == null) return ProfileState(name: '', imagePath: null);

    final box = HiveService.settingsBox;
    String name = box.get(_nameKey, defaultValue: '') as String;
    String? imagePath = box.get(_imageKey) as String?;

    // On first login for this UID, seed display name from Firebase.
    if (name.isEmpty) {
      final firebaseName = ref.read(currentUserProvider)?.displayName;
      if (firebaseName != null && firebaseName.isNotEmpty) {
        name = firebaseName;
        box.put(_nameKey, name);
      }
    }

    // Migrate from legacy absolute file paths seamlessly.
    if (imagePath != null && !imagePath.startsWith('assets/images/avatars/')) {
      imagePath = null;
      box.delete(_imageKey);
    }

    return ProfileState(name: name, imagePath: imagePath);
  }

  void updateName(String newName) {
    state = state.copyWith(name: newName);
    HiveService.settingsBox.put(_nameKey, newName);
    FirestoreSyncService.pushProfile(newName, state.imagePath);
  }

  void updateImagePath(String? path) {
    state = state.copyWith(imagePath: path);
    HiveService.settingsBox.put(_imageKey, path);
    FirestoreSyncService.pushProfile(state.name, path);
  }
}

final profileProvider =
    AutoDisposeNotifierProvider<ProfileNotifier, ProfileState>(() {
  return ProfileNotifier();
});
