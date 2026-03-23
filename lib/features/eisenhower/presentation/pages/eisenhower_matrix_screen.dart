import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/eisenhower_task.dart';
import '../controllers/eisenhower_controller.dart';
import '../widgets/matrix_components.dart';
import 'quadrant_detail_screen.dart';

class EisenhowerMatrixScreen extends ConsumerWidget {
  const EisenhowerMatrixScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(eisenhowerControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: _MatrixQuadrant(type: QuadrantType.doNow)),
                            SizedBox(width: 12),
                            Expanded(child: _MatrixQuadrant(type: QuadrantType.schedule)),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: _MatrixQuadrant(type: QuadrantType.delegate)),
                            SizedBox(width: 12),
                            Expanded(child: _MatrixQuadrant(type: QuadrantType.eliminate)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Matrix',
            style: GoogleFonts.greatVibes(
              fontSize: 48,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2D264B),
            ),
          ),
          GestureDetector(
            onTap: () => showUpsertSheet(context),
            child: Theme.of(context).brightness == Brightness.dark
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  )
                : Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded, color: Color(0xFF2D264B), size: 28),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MatrixQuadrant extends ConsumerWidget {
  final QuadrantType type;
  const _MatrixQuadrant({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasks = ref.watch(eisenhowerControllerProvider);
    final tasks = allTasks.where((t) => t.quadrant == type).toList()
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });

    final cfg = getQuadrantConfig(type);

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) => ref.read(eisenhowerControllerProvider.notifier).moveTask(details.data, type),
      builder: (context, candidates, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cfg.color.withValues(alpha: candidates.isNotEmpty ? 0.30 : 0.18),
                cfg.color.withValues(alpha: candidates.isNotEmpty ? 0.15 : 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: candidates.isNotEmpty ? cfg.color : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => QuadrantDetailScreen(type: type),
                      ),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cfg.title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: cfg.titleColor,
                        ),
                      ),
                      Text(
                        cfg.subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: kSubtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Text(
                          'No tasks yet',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: kSubtitleColor.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        itemCount: tasks.length,
                        itemBuilder: (context, i) => MatrixTaskCard(task: tasks[i], accentColor: cfg.color),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
