import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/projects_service.dart';
import '../themes/app_theme.dart';
import '../ui/root_scaffold_messenger.dart';

/// Exporta TASKBOARD.md al workspace del proyecto (API remota).
Future<void> exportTaskboardMdAction(
  BuildContext context, {
  required ProjectsService projectsService,
  required Project project,
}) async {
  if (project.workspacePath.isEmpty) {
    kRootScaffoldMessenger.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Este proyecto no tiene carpeta workspace vinculada.'),
        backgroundColor: AppColors.warning,
      ),
    );
    return;
  }

  kRootScaffoldMessenger.currentState?.showSnackBar(
    const SnackBar(
      content: Text('Exportando TASKBOARD.md al repositorio…'),
      duration: Duration(seconds: 3),
    ),
  );

  try {
    final result = await projectsService.exportTaskboardMd(project.id);
    if (!context.mounted) return;
    final path = (result['file_path'] ?? result['filePath'] ?? '').toString();
    final count = result['task_count'] ?? result['taskCount'] ?? '?';
    kRootScaffoldMessenger.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          path.isNotEmpty
              ? 'TASKBOARD.md exportado ($count tareas)\n$path'
              : 'TASKBOARD.md exportado ($count tareas)',
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 6),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    kRootScaffoldMessenger.currentState?.showSnackBar(
      SnackBar(
        content: Text('No se pudo exportar: $e'),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 8),
      ),
    );
  }
}
