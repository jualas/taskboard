import 'package:flutter/material.dart';

import '../models/models.dart';
import '../themes/app_theme.dart';

/// Muestra descripción completa, checklist interactivo, etiquetas y metadatos.
Future<void> showTaskDetailSheet(
  BuildContext context, {
  required Task task,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  void Function(Task updated)? onChecklistPersist,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final bottom = MediaQuery.of(sheetContext).padding.bottom;
      final maxH = MediaQuery.sizeOf(sheetContext).height * 0.88;

      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: _TaskDetailSheetBody(
          initialTask: task,
          bottomPadding: bottom,
          onEdit: onEdit,
          onDelete: onDelete,
          onChecklistPersist: onChecklistPersist,
        ),
      );
    },
  );
}

class _TaskDetailSheetBody extends StatefulWidget {
  const _TaskDetailSheetBody({
    required this.initialTask,
    required this.bottomPadding,
    required this.onEdit,
    required this.onDelete,
    this.onChecklistPersist,
  });

  final Task initialTask;
  final double bottomPadding;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(Task updated)? onChecklistPersist;

  @override
  State<_TaskDetailSheetBody> createState() => _TaskDetailSheetBodyState();
}

class _TaskDetailSheetBodyState extends State<_TaskDetailSheetBody> {
  late Task _displayed;

  @override
  void initState() {
    super.initState();
    _displayed = widget.initialTask;
  }

  void _toggleSubtask(Subtask s, bool? value) {
    if (widget.onChecklistPersist == null) return;
    final nextDone = value ?? !s.isDone;
    final nextSubs = _displayed.subtasks
        .map((x) => x.id == s.id ? x.copyWith(isDone: nextDone) : x)
        .toList();
    final updated = _displayed.copyWith(
      subtasks: nextSubs,
      updatedAt: DateTime.now(),
    );
    setState(() => _displayed = updated);
    widget.onChecklistPersist!(updated);
  }

  @override
  Widget build(BuildContext context) {
    final sheetContext = context;
    final task = _displayed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  task.title,
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _statusChip(task.status),
                    _complexityChip(task.complexity),
                    if (task.estimatedHours != null)
                      Chip(
                        avatar: const Icon(Icons.schedule, size: 16, color: AppColors.accentPrimary),
                        label: Text('${task.estimatedHours} h'),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    if (task.dueDate != null)
                      Chip(
                        avatar: const Icon(Icons.event, size: 16, color: AppColors.accentPrimary),
                        label: Text(
                          '${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}',
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                if (task.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Etiquetas',
                    style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: task.tags
                        .map(
                          (t) => Chip(
                            label: Text(t),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            backgroundColor: AppColors.backgroundDark.withValues(alpha: 0.08),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (task.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Descripción',
                    style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    task.description,
                    style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                        ),
                  ),
                ],
                if (task.hasSubtasks) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Checklist (${task.subtasksDoneCount}/${task.subtasksTotalCount})',
                    style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  if (widget.onChecklistPersist != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Forma parte de la tarea: se guarda al marcar.',
                      style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                            color: AppColors.accentPrimary,
                          ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ...task.subtasks.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: s.isDone,
                            onChanged: widget.onChecklistPersist == null
                                ? null
                                : (v) => _toggleSubtask(s, v),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                s.title,
                                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                                      decoration: s.isDone ? TextDecoration.lineThrough : null,
                                      color: s.isDone
                                          ? AppColors.textSecondary
                                          : AppColors.textPrimary,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + widget.bottomPadding),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    widget.onEdit();
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    widget.onDelete();
                  },
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  label: const Text(
                    'Eliminar',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _statusChip(TaskStatus status) {
  final color = KanbanColors.getHeaderColor(status.dbValue);
  return Chip(
    label: Text(status.displayName),
    backgroundColor: color.withValues(alpha: 0.2),
    labelStyle: TextStyle(
      color: color,
      fontWeight: FontWeight.w600,
      fontSize: 12,
    ),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
  );
}

Widget _complexityChip(TaskComplexity complexity) {
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
