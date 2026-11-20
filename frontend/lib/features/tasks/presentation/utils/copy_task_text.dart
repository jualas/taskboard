import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/ui/root_scaffold_messenger.dart';
import '../../domain/entities/task.dart';

/// Texto plano de una tarea para pegar en otras aplicaciones (correo, chat, documentos).
/// Usa sintaxis Markdown sencilla, que se lee bien aunque el destino no la interprete.
String taskAsPlainText(Task task) {
  final b = StringBuffer(task.title.trim());
  final meta = <String>[
    task.status.displayName,
    'Complejidad: ${task.complexity.displayName}',
    if (task.estimatedHours != null) '${task.estimatedHours} h',
    if (task.dueDate != null) 'Vence: ${_fecha(task.dueDate!)}',
  ];
  b.write('\n${meta.join(' · ')}');
  if (task.tags.isNotEmpty) b.write('\nEtiquetas: ${task.tags.join(', ')}');
  final description = task.description.trim();
  if (description.isNotEmpty) b.write('\n\n$description');
  if (task.subtasks.isNotEmpty) {
    b.write(
      '\n\nChecklist (${task.subtasksDoneCount}/${task.subtasksTotalCount}):',
    );
    for (final s in task.subtasks) {
      b.write('\n- [${s.isDone ? 'x' : ' '}] ${s.title.trim()}');
    }
  }
  return b.toString();
}

String _fecha(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Copia la tarea al portapapeles y lo confirma con un aviso.
Future<void> copyTaskToClipboard(Task task) async {
  await Clipboard.setData(ClipboardData(text: taskAsPlainText(task)));
  kRootScaffoldMessenger.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(content: Text('Tarea copiada al portapapeles')),
    );
}
