import 'package:flutter/material.dart';

import '../core/error/result_extensions.dart';
import '../features/projects/domain/entities/project.dart';
import '../features/projects/domain/usecases/projects_usecases.dart';
import '../shared/themes/app_theme.dart';
import '../shared/ui/root_scaffold_messenger.dart';

/// Exporta TASKBOARD.md al workspace del proyecto (API remota).
Future<void> exportTaskboardMdAction(
  BuildContext context, {
  required ExportTaskboardMd exportTaskboardMd,
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
    final result = await exportTaskboardMd(
      ExportTaskboardMdParams(projectId: project.id),
    ).then((r) => r.require('Exportar TASKBOARD.md'));
    if (!context.mounted) return;
    final path = result.filePath;
    final count = result.taskCountLabel;
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
        content: Text('Error al exportar: $e'),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
