import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/projects_bloc.dart';
import '../../blocs/tasks_bloc.dart';
import '../../models/models.dart';
import '../../themes/app_theme.dart';
import '../forms/task_form.dart';
import '../../widgets/project_ai_chat_sheet.dart';
import '../../widgets/project_screen_title.dart';
import '../../widgets/open_in_cursor_button.dart';
import '../../widgets/task_detail_sheet.dart';
import '../../utils/export_taskboard_md.dart';
import '../../widgets/ide_cursor_session_sheet.dart';

class KanbanBoard extends StatefulWidget {
  final int projectId;

  const KanbanBoard({
    super.key,
    required this.projectId,
  });

  @override
  State<KanbanBoard> createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<KanbanBoard> {
  Task? _draggingTask;
  int? _dropTargetIndex;
  TaskStatus? _dropTargetStatus;
  bool _isProcessingDrop = false;

  @override
  void initState() {
    super.initState();
    context.read<TasksBloc>().add(
      TasksLoadRequested(projectId: widget.projectId),
    );
    final projectsState = context.read<ProjectsBloc>().state;
    if (projectsState is! ProjectsLoaded) {
      context.read<ProjectsBloc>().add(ProjectsLoadRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: ProjectScreenTitle(
          projectId: widget.projectId,
          viewLabel: 'Tablero Kanban',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/projects'),
        ),
        actions: [
          BlocBuilder<ProjectsBloc, ProjectsState>(
            builder: (context, state) {
              if (state is! ProjectsLoaded) {
                return const SizedBox.shrink();
              }
              Project? project;
              for (final p in state.projects) {
                if (p.id == widget.projectId) {
                  project = p;
                  break;
                }
              }
              if (project == null || project.workspacePath.isEmpty) {
                return const SizedBox.shrink();
              }
              return OpenInCursorIconButton(
                workspacePath: project.workspacePath,
                projectTitle: project.title,
              );
            },
          ),
          BlocBuilder<ProjectsBloc, ProjectsState>(
            builder: (context, state) {
              if (state is! ProjectsLoaded) {
                return const SizedBox.shrink();
              }
              Project? project;
              for (final p in state.projects) {
                if (p.id == widget.projectId) {
                  project = p;
                  break;
                }
              }
              if (project == null ||
                  project.workspacePath.isEmpty ||
                  !project.canEdit) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.content_paste_go),
                tooltip: 'Prompt IDE (export + copiar)',
                onPressed: () => showIdeCursorSessionSheet(
                  context,
                  projectsService: context.read<ProjectsBloc>().projectsService,
                  project: project!,
                ),
              );
            },
          ),
          BlocBuilder<ProjectsBloc, ProjectsState>(
            builder: (context, state) {
              if (state is! ProjectsLoaded) {
                return const SizedBox.shrink();
              }
              Project? project;
              for (final p in state.projects) {
                if (p.id == widget.projectId) {
                  project = p;
                  break;
                }
              }
              if (project == null ||
                  project.workspacePath.isEmpty ||
                  !project.canEdit) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.description_outlined),
                tooltip: 'Exportar TASKBOARD.md al repo',
                onPressed: () => exportTaskboardMdAction(
                  context,
                  projectsService: context.read<ProjectsBloc>().projectsService,
                  project: project!,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Asistente IA del proyecto',
            onPressed: _openProjectAiChat,
          ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => context.go('/projects/${widget.projectId}/tasks'),
            tooltip: 'Ver como lista',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<TasksBloc>().add(
              TasksLoadRequested(projectId: widget.projectId),
            ),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: BlocConsumer<TasksBloc, TasksState>(
        listener: (context, state) {
          if (state is TasksFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          } else if (state is TaskOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is TasksLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is TasksLoaded) {
            return _buildKanbanBoard(state.tasks);
          }

          return Center(
            child: Text(
              'No hay tareas',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTask,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildKanbanBoard(List<Task> allTasks) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: TaskStatus.values.map((status) {
        return Expanded(child: _buildColumn(status, allTasks));
      }).toList(),
    );
  }

  Widget _buildColumn(TaskStatus status, List<Task> tasks) {
    final columnTasks = tasks.where((task) => task.status == status).toList();
    columnTasks.sort(
      (a, b) => a.kanbanPosition.compareTo(b.kanbanPosition),
    );

    final columnTitle = status.displayName;
    final headerColor = KanbanColors.getHeaderColor(status.dbValue);
    final bgColor = KanbanColors.getBackgroundColor(status.dbValue);

    return DragTarget<Task>(
      onAcceptWithDetails: (details) {
        if (_dropTargetIndex == null && !_isProcessingDrop) {
          final task = details.data;
          final targetIndex = task.status == status
              ? columnTasks.length - 1
              : columnTasks.length;
          _handleTaskDrop(task, status, targetIndex);
        }
      },
      onWillAcceptWithDetails: (details) {
        return _dropTargetIndex == null;
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;

        return Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHighlighted ? headerColor : AppColors.textSecondary.withValues(alpha: 0.2),
              width: isHighlighted ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header de la columna
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: headerColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    topRight: Radius.circular(11),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      columnTitle,
                      style: const TextStyle(
                        color: AppColors.textOnDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${columnTasks.length}',
                        style: const TextStyle(
                          color: AppColors.textOnDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Lista de tareas con scroll
              Expanded(
                child: _buildTaskList(columnTasks, status),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskList(List<Task> tasks, TaskStatus columnStatus) {
    if (tasks.isEmpty) {
      return DragTarget<Task>(
        onWillAcceptWithDetails: (details) {
          if (_draggingTask == null) return false;
          setState(() {
            _dropTargetIndex = 0;
            _dropTargetStatus = columnStatus;
          });
          return true;
        },
        onLeave: (_) {
          setState(() {
            _dropTargetIndex = null;
            _dropTargetStatus = null;
          });
        },
        onAcceptWithDetails: (details) {
          if (!_isProcessingDrop) {
            final task = details.data;
            _handleTaskDrop(task, columnStatus, 0);
          }
          setState(() {
            _dropTargetIndex = null;
            _dropTargetStatus = null;
          });
        },
        builder: (context, candidateData, rejectedData) {
          final showPlaceholder = candidateData.isNotEmpty;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: showPlaceholder
                  ? _buildInsertionPlaceholder()
                  : const Text(
                      'Sin tareas',
                      style: TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: tasks.length * 2 + 1,
      itemBuilder: (context, index) {
        if (index.isEven) {
          final dropIndex = index ~/ 2;
          return _buildDropZone(columnStatus, dropIndex, tasks);
        } else {
          final taskIndex = index ~/ 2;
          final task = tasks[taskIndex];

          if (_draggingTask?.id == task.id) {
            return _buildDraggingPlaceholder();
          }

          return _buildTaskCard(task, taskIndex, key: ValueKey(task.id));
        }
      },
    );
  }

  Widget _buildTaskCard(Task task, int taskIndex, {Key? key}) {
    final borderColor = KanbanColors.getBorderColor(task.status.dbValue);
    
    return Draggable<Task>(
      key: key,
      data: task,
      onDragStarted: () {
        setState(() {
          _draggingTask = task;
        });
      },
      onDragEnd: (_) {
        setState(() {
          _draggingTask = null;
          _dropTargetIndex = null;
          _dropTargetStatus = null;
        });
      },
      onDraggableCanceled: (_, __) {
        setState(() {
          _draggingTask = null;
          _dropTargetIndex = null;
          _dropTargetStatus = null;
        });
      },
      feedback: _buildDragFeedback(task),
      childWhenDragging: const SizedBox.shrink(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor.withValues(alpha: 0.5), width: 1),
        ),
        child: InkWell(
          onTap: () => _openTaskDetail(task),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: borderColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.drag_indicator,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                      size: 16,
                    ),
                  ],
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.description,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (task.hasSubtasks) ...[
                  const SizedBox(height: 6),
                  ...task.subtasks.take(4).map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                s.isDone ? Icons.check : Icons.radio_button_unchecked,
                                size: 12,
                                color: s.isDone ? AppColors.success : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  s.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    decoration:
                                        s.isDone ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (task.subtasks.length > 4)
                    Text(
                      '+${task.subtasks.length - 4} ítems más · pulsa para ver todo',
                      style: const TextStyle(fontSize: 10, color: AppColors.accentPrimary),
                    ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _buildComplexityChip(task.complexity),
                    if (task.hasSubtasks)
                      _buildInfoChip(
                        '${task.subtasksDoneCount}/${task.subtasksTotalCount}',
                        Icons.checklist,
                      ),
                    if (task.estimatedHours != null)
                      _buildInfoChip('${task.estimatedHours}h', Icons.schedule),
                    ...task.tags.map(_buildTagChip),
                  ],
                ),
                if (task.dueDate != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.event, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${task.dueDate!.day}/${task.dueDate!.month}',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropZone(TaskStatus status, int dropIndex, List<Task> columnTasks) {
    final isTargeted = _dropTargetStatus == status && _dropTargetIndex == dropIndex;

    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) {
        if (_draggingTask == null) return false;
        setState(() {
          _dropTargetIndex = dropIndex;
          _dropTargetStatus = status;
        });
        return true;
      },
      onLeave: (_) {
        if (_dropTargetIndex == dropIndex && _dropTargetStatus == status) {
          setState(() {
            _dropTargetIndex = null;
            _dropTargetStatus = null;
          });
        }
      },
      onAcceptWithDetails: (details) {
        if (!_isProcessingDrop) {
          final task = details.data;
          _handleTaskDrop(task, status, dropIndex);
          setState(() {
            _dropTargetIndex = null;
            _dropTargetStatus = null;
          });
        }
      },
      builder: (context, candidateData, rejectedData) {
        if (isTargeted || candidateData.isNotEmpty) {
          return _buildInsertionPlaceholder();
        }
        return const SizedBox(height: 4);
      },
    );
  }

  Widget _buildInsertionPlaceholder() {
    return Container(
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentPrimary.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggingPlaceholder() {
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.3),
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: const Center(
        child: Icon(Icons.drag_indicator, color: AppColors.textSecondary, size: 32),
      ),
    );
  }

  Widget _buildDragFeedback(Task task) {
    final borderColor = KanbanColors.getBorderColor(task.status.dbValue);
    
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(12),
      shadowColor: Colors.black.withValues(alpha: 0.3),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: borderColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task.description,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComplexityChip(TaskComplexity complexity) {
    Color color;
    switch (complexity) {
      case TaskComplexity.simple:
        color = AppColors.success;
        break;
      case TaskComplexity.medium:
        color = AppColors.warning;
        break;
      case TaskComplexity.complex:
        color = AppColors.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        complexity.displayName,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentSecondary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppColors.accentPrimary),
          const SizedBox(width: 2),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.accentPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  void _handleTaskDrop(Task task, TaskStatus newStatus, int targetIndex) {
    if (_isProcessingDrop) return;

    setState(() {
      _isProcessingDrop = true;
      _draggingTask = null;
      _dropTargetIndex = null;
      _dropTargetStatus = null;
    });

    context.read<TasksBloc>().add(
      TaskReorderRequested(
        taskId: task.id,
        newStatus: newStatus,
        targetIndex: targetIndex,
        projectId: widget.projectId,
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isProcessingDrop = false;
        });
      }
    });
  }

  void _openTaskDetail(Task task) {
    showTaskDetailSheet(
      context,
      task: task,
      onEdit: () => _editTask(task),
      onDelete: () => _deleteTask(task),
      onChecklistPersist: (updated) {
        context.read<TasksBloc>().add(TaskChecklistPersistRequested(updated));
      },
    );
  }

  void _openProjectAiChat() {
    final (title, desc) = _projectContextForAi();
    final state = context.read<TasksBloc>().state;
    final tasks = state is TasksLoaded ? state.tasks : const <Task>[];
    showProjectAiChatSheet(
      context,
      projectId: widget.projectId,
      projectTitle: title.isNotEmpty ? title : 'Proyecto ${widget.projectId}',
      projectDescription: desc,
      existingTasks: tasks,
    );
  }

  (String, String) _projectContextForAi() {
    final state = context.read<ProjectsBloc>().state;
    if (state is ProjectsLoaded) {
      for (final p in state.projects) {
        if (p.id == widget.projectId) {
          return (p.title, p.description);
        }
      }
    }
    return ('', '');
  }

  Future<void> _editTask(Task task) async {
    final (aiTitle, aiDesc) = _projectContextForAi();
    await showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: TaskForm(
            projectId: widget.projectId,
            projectTitleForAi: aiTitle,
            projectDescriptionForAi: aiDesc,
            task: task,
            onPersistChecklist: (t) {
              context.read<TasksBloc>().add(TaskChecklistPersistRequested(t));
            },
            onSave: (updatedTask) {
              context.read<TasksBloc>().add(TaskUpdateRequested(updatedTask));
              Navigator.of(dialogContext).pop();
            },
          ),
        ),
      ),
    );
  }

  void _deleteTask(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Tarea'),
        content: Text('¿Estás seguro de que quieres eliminar "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<TasksBloc>().add(
                TaskDeleteRequested(id: task.id, projectId: widget.projectId),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _createTask() async {
    final (aiTitle, aiDesc) = _projectContextForAi();
    await showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: TaskForm(
            projectId: widget.projectId,
            projectTitleForAi: aiTitle,
            projectDescriptionForAi: aiDesc,
            onSave: (task) {
              context.read<TasksBloc>().add(
                TaskCreateRequested(
                  projectId: widget.projectId,
                  title: task.title,
                  description: task.description,
                  complexity: task.complexity,
                  estimatedHours: task.estimatedHours,
                  dueDate: task.dueDate,
                  tags: task.tags,
                  subtasks: task.subtasks,
                ),
              );
              Navigator.of(dialogContext).pop();
            },
          ),
        ),
      ),
    );
  }
}
