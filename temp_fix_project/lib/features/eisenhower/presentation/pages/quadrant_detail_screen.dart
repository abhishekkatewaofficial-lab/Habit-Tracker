import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/eisenhower_task.dart';
import '../controllers/eisenhower_controller.dart';
import '../widgets/matrix_components.dart';

class QuadrantDetailScreen extends ConsumerWidget {
  final QuadrantType type;

  const QuadrantDetailScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasks = ref.watch(eisenhowerControllerProvider);
    final tasks = allTasks.where((t) => t.quadrant == type).toList()
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });

    final cfg = getQuadrantConfig(type);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
          child: Column(
            children: [
              _buildHeader(context, cfg),
              Expanded(
                child: tasks.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        itemCount: tasks.length,
                        itemBuilder: (context, i) => MatrixTaskCard(
                          task: tasks[i],
                          accentColor: cfg.color,
                          enableDrag: false,
                        ),
                      ),
              ),
            ],
          ),
        ),
      floatingActionButton: GestureDetector(
        onTap: () => showUpsertSheet(context, preselected: type, hideSelector: true),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Color(0xFF3A3A3C), size: 32),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, QuadrantCfg cfg) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 24, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2D264B), size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cfg.title,
              style: GoogleFonts.greatVibes(
                fontSize: 42,
                fontWeight: FontWeight.w600,
                color: cfg.titleColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 64,
            color: kSubtitleColor.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Keep it up!',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kSubtitleColor.withValues(alpha: 0.5),
            ),
          ),
          Text(
            'Your quadrant is clear.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: kSubtitleColor.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
