import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker_ios/core/services/auth_service.dart';
import 'package:habit_tracker_ios/core/services/firestore_sync_service.dart';
import 'package:habit_tracker_ios/features/timetable/data/models/routine_template.dart';
import 'package:habit_tracker_ios/features/timetable/data/models/time_block.dart';
import 'package:habit_tracker_ios/features/timetable/data/repositories/routine_template_repository.dart';
import 'package:habit_tracker_ios/features/timetable/presentation/controllers/timetable_controller.dart';

final routineTemplateRepositoryProvider = Provider<RoutineTemplateRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return RoutineTemplateRepository();
});

final routineTemplateControllerProvider = StateNotifierProvider<RoutineTemplateController, List<RoutineTemplate>>((ref) {
  final repository = ref.watch(routineTemplateRepositoryProvider);
  if (repository == null) return RoutineTemplateController._empty();

  final controller = RoutineTemplateController(repository, ref);

  ref.listen(syncRefreshProvider, (_, __) {
    controller.reloadFromHive();
  });

  return controller;
});

class RoutineTemplateController extends StateNotifier<List<RoutineTemplate>> {
  final RoutineTemplateRepository? _repository;
  final Ref? _ref;

  RoutineTemplateController(RoutineTemplateRepository repository, Ref ref)
      : _repository = repository,
        _ref = ref,
        super([]) {
    _load();
  }

  RoutineTemplateController._empty()
      : _repository = null,
        _ref = null,
        super([]);

  void _load() {
    if (_repository == null) return;
    state = _repository.getAllTemplates();
  }

  void reloadFromHive() => _load();

  Future<void> saveCurrentDayAsTemplate(String name, String emoji, String colorHex, DateTime date) async {
    if (_repository == null || _ref == null) return;
    
    // Get all current day blocks
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final currentBlocks = _ref.read(timetableRepositoryProvider)?.getBlocksForDate(dateKey) ?? [];
    
    if (currentBlocks.isEmpty) return;
    
    // Create clones with a 'TEMPLATE' date
    final templateBlocks = currentBlocks.map((b) => b.copyWith(
      id: 'template_block_${DateTime.now().microsecondsSinceEpoch}_${b.id}',
      date: 'TEMPLATE',
      isCompleted: false, // Reset completion for templates
    )).toList();

    final template = RoutineTemplate(
      id: 'template_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      emoji: emoji,
      colorHex: colorHex,
      blocks: templateBlocks,
    );

    // Optimistic
    state = [...state, template];
    
    // Save
    await _repository.saveTemplate(template);
    await FirestoreSyncService.pushRoutineTemplate(template);
    _load();
  }

  Future<void> createEmptyTemplate(String name, String emoji, String colorHex) async {
    if (_repository == null) return;
    
    final template = RoutineTemplate(
      id: 'template_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      emoji: emoji,
      colorHex: colorHex,
      blocks: [],
    );

    // Optimistic
    state = [...state, template];
    
    // Save
    await _repository.saveTemplate(template);
    await FirestoreSyncService.pushRoutineTemplate(template);
    _load();
  }

  Future<void> updateTemplateBlocks(String templateId, List<TimeBlock> newBlocks) async {
    if (_repository == null) return;

    final targetIndex = state.indexWhere((t) => t.id == templateId);
    if (targetIndex == -1) return;

    final updatedTemplate = state[targetIndex].copyWith(blocks: newBlocks);
    
    // Optimistic
    final newState = [...state];
    newState[targetIndex] = updatedTemplate;
    state = newState;

    // Save
    await _repository.saveTemplate(updatedTemplate);
    await FirestoreSyncService.pushRoutineTemplate(updatedTemplate);
  }

  Future<void> deleteTemplate(String id) async {
    if (_repository == null) return;
    
    // Optimistic
    state = state.where((t) => t.id != id).toList();
    
    // Save
    await _repository.deleteTemplate(id);
    await FirestoreSyncService.deleteRoutineTemplate(id);
    _load();
  }

  Future<void> applyTemplateToDate(RoutineTemplate template, DateTime targetDate) async {
    if (_ref == null) return;
    
    final dateKey = DateFormat('yyyy-MM-dd').format(targetDate);
    final timetableNotifier = _ref.read(timetableControllerProvider.notifier);

    // Clear the current day's blocks completely
    await timetableNotifier.clearCurrentDate();

    for (final block in template.blocks) {
      // Create a brand new ID for the instantiated block
      final newId = 'tb_${DateTime.now().microsecondsSinceEpoch}_${block.id}';
      
      // Shift timestamps to target day
      final newStartTime = DateTime(
        targetDate.year, targetDate.month, targetDate.day,
        block.startTime.hour, block.startTime.minute,
      );
      
      final newEndTime = DateTime(
        targetDate.year, targetDate.month, targetDate.day,
        block.endTime.hour, block.endTime.minute,
      );
      
      final instantiatedBlock = block.copyWith(
        id: newId,
        date: dateKey,
        startTime: newStartTime,
        endTime: newEndTime,
      );

      // Add to timetable completely seamlessly
      await timetableNotifier.addBlock(instantiatedBlock);
    }
  }
}
