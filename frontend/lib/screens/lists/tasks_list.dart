import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/projects_bloc.dart';
import '../../blocs/tasks_bloc.dart';
import '../../models/models.dart';
import '../../themes/app_theme.dart';
import '../forms/task_form.dart';
import '../../widgets/task_detail_sheet.dart';

class TasksList extends StatefulWidget {
  final int projectId;

  const TasksList({
    super.key,
    required this.projectId,
  });

  @override
  State<TasksList> createState() => _TasksListState();
}

class _TasksListState extends State<TasksList> {
  @override
  void initState() {
    super.initState();
    context.read<TasksBloc>().add(
      TasksLoadRequested(projectId: widget.projectId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Tareas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/projects'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_kanban),
            onPressed: () => context.go('/projects/${widget.projectId}/kanban'),
            tooltip: 'Ver como Kanban',
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
            if (state.tasks.isEmpty) {
              return _buildEmptyState();
            }

            final tasksByStatus = _groupTasksByStatus(state.tasks);
            return _buildTasksList(tasksByStatus);
          }

          return _buildEmptyState();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTask,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt,
            size: 80,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay tareas',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea tu primera tarea para comenzar',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createTask,
            icon: const Icon(Icons.add),
            label: const Text('Crear Tarea'),
          ),
        ],
      ),
    );
  }

  Map<TaskStatus, List<Task>> _groupTasksByStatus(List<Task> tasks) {
    final Map<TaskStatus, List<Task>> grouped = {
      TaskStatus.pending: [],
      TaskStatus.inProgress: [],
      TaskStatus.completed: [],
    };

    for (final task in tasks) {
      grouped[task.status]?.add(task);
    }

    // Ordenar por posición Kanban dentro de cada grupo
    for (final status in TaskStatus.values) {
      grouped[status]?.sort((a, b) => a.kanbanPosition.compareTo(b.kanbanPosition));
    }

    return grouped;
  }

  Widget _buildTasksList(Map<TaskStatus, List<Task>> tasksByStatus) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<TasksBloc>().add(
          TasksLoadRequested(projectId: widget.projectId),
        );
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final status in TaskStatus.values)
            if (tasksByStatus[status]!.isNotEmpty) ...[
              _buildStatusHeader(status, tasksByStatus[status]!.length),
              ...tasksByStatus[status]!.map(_buildTaskCard),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }

  Widget _buildStatusHeader(TaskStatus status, int count) {
    final color = KanbanColors.getHeaderColor(status.dbValue);
    final bgColor = KanbanColors.getBackgroundColor(status.dbValue);
    IconData icon;

    switch (status) {
      case TaskStatus.pending:
        icon = Icons.schedule;
        break;
      case TaskStatus.inProgress:
        icon = Icons.play_circle_outline;
        break;
      case TaskStatus.completed:
        icon = Icons.check_circle;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 12),
          Text(
            status.displayName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textOnDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final borderColor = KanbanColors.getBorderColor(task.status.dbValue);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: task.status.isCompleted ? TextDecoration.lineThrough : null,
            color: task.status.isCompleted 
                ? AppColors.textSecondary 
                : AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task.description,
                maxLines: 10,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.4),
              ),
            ],
            if (task.hasSubtasks) ...[
              const SizedBox(height: 8),
              const Text(
                'Checklist',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              ...task.subtasks.take(6).map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            s.isDone ? Icons.check_box : Icons.check_box_outline_blank,
                            size: 16,
                            color: s.isDone ? AppColors.success : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                decoration: s.isDone ? TextDecoration.lineThrough : null,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (task.subtasks.length > 6)
                Text(
                  '+${task.subtasks.length - 6} ítems · toca la tarjeta para ver todo',
                  style: const TextStyle(fontSize: 11, color: AppColors.accentPrimary),
                ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildComplexityChip(task.complexity),
                if (task.hasSubtasks)
                  Chip(
                    avatar: const Icon(Icons.checklist, size: 16, color: AppColors.accentPrimary),
                    label: Text('${task.subtasksDoneCount}/${task.subtasksTotalCount}'),
                    backgroundColor: AppColors.accentSecondary.withValues(alpha: 0.2),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      color: AppColors.accentPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                if (task.estimatedHours != null)
                  Chip(
                    label: Text('${task.estimatedHours}h'),
                    backgroundColor: AppColors.accentSecondary.withValues(alpha: 0.2),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      color: AppColors.accentPrimary,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ...task.tags.map((tag) => Chip(
                  label: Text(tag),
                  backgroundColor: AppColors.backgroundDark.withValues(alpha: 0.1),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                )),
              ],
            ),
            if (task.dueDate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.event, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Vence: ${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isOverdue(task.dueDate!) 
                          ? AppColors.error 
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleTaskAction(value, task),
          itemBuilder: (context) => [
            if (task.status != TaskStatus.completed)
              const PopupMenuItem(
                value: 'complete',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success),
                    SizedBox(width: 8),
                    Text('Marcar completada'),
                  ],
                ),
              ),
            if (task.status == TaskStatus.completed)
              const PopupMenuItem(
                value: 'reopen',
                child: Row(
                  children: [
                    Icon(Icons.replay, color: AppColors.warning),
                    SizedBox(width: 8),
                    Text('Reabrir'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Editar'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Eliminar', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _openTaskDetail(task),
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

    return Chip(
      label: Text(complexity.displayName),
      backgroundColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        fontSize: 12,
        color: color,
        fontWeight: FontWeight.w600,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  bool _isOverdue(DateTime dueDate) {
    return dueDate.isBefore(DateTime.now()) && 
           dueDate.day != DateTime.now().day;
  }

  void _handleTaskAction(String action, Task task) {
    switch (action) {
      case 'complete':
        context.read<TasksBloc>().add(
          TaskStatusUpdateRequested(
            taskId: task.id,
            status: TaskStatus.completed,
            projectId: widget.projectId,
          ),
        );
        break;
      case 'reopen':
        context.read<TasksBloc>().add(
          TaskStatusUpdateRequested(
            taskId: task.id,
            status: TaskStatus.pending,
            projectId: widget.projectId,
          ),
        );
        break;
      case 'edit':
        _editTask(task);
        break;
      case 'delete':
        _deleteTask(task);
        break;
    }
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
