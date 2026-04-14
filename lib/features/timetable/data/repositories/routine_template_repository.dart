import 'package:habit_tracker_ios/core/services/hive_service.dart';
import 'package:habit_tracker_ios/features/timetable/data/models/routine_template.dart';

class RoutineTemplateRepository {
  List<RoutineTemplate> getAllTemplates() {
    final box = HiveService.routineTemplatesBox;
    final mapList = box.values.toList();
    
    return mapList.map((dynamic item) {
      if (item is Map) {
        return RoutineTemplate.fromJson(Map<String, dynamic>.from(item));
      }
      return null;
    }).whereType<RoutineTemplate>().toList();
  }

  Future<void> saveTemplate(RoutineTemplate template) async {
    final box = HiveService.routineTemplatesBox;
    await box.put(template.id, template.toJson());
  }

  Future<void> deleteTemplate(String id) async {
    final box = HiveService.routineTemplatesBox;
    await box.delete(id);
  }
}
