import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/tasks_bloc.dart';
import '../models/models.dart';
import 'project_ai_chat_panel.dart';

/// Abre el asistente IA como hoja modal para un proyecto ya creado.
Future<void> showProjectAiChatSheet(
  BuildContext context, {
  required int projectId,
  required String projectTitle,
  required String projectDescription,
  required List<Task> existingTasks,
}) {
  final tasksBloc = context.read<TasksBloc>();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final maxH = MediaQuery.sizeOf(sheetContext).height * 0.92;

      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SizedBox(
          height: maxH,
          child: ProjectAiChatPanel(
            mode: ProjectAiChatMode.existing,
            projectId: projectId,
            projectTitle: projectTitle,
            projectDescription: projectDescription,
            existingTasks: existingTasks,
            tasksService: tasksBloc.tasksService,
            onTasksApplied: () {
              tasksBloc.add(TasksLoadRequested(projectId: projectId));
            },
          ),
        ),
      );
    },
  );
}
