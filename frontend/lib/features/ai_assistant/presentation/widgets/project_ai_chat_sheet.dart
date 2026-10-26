import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../projects/presentation/bloc/projects_bloc.dart';
import '../../../tasks/domain/entities/task.dart';
import '../../../tasks/presentation/bloc/tasks_bloc.dart';
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
            onTasksApplied: () {
              tasksBloc.add(TasksLoadRequested(projectId: projectId));
            },
          ),
        ),
      );
    },
  );
}

/// Abre el asistente IA para planificar un proyecto nuevo y crearlo con sus tareas.
Future<void> showNewProjectAiChatSheet(
  BuildContext context, {
  required String projectTitle,
  required String projectDescription,
}) {
  final projectsBloc = context.read<ProjectsBloc>();

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
            mode: ProjectAiChatMode.create,
            projectTitle: projectTitle,
            projectDescription: projectDescription,
            onProjectCreated: (_) {
              projectsBloc.add(ProjectsLoadRequested());
              Navigator.of(sheetContext).pop();
            },
          ),
        ),
      );
    },
  );
}
