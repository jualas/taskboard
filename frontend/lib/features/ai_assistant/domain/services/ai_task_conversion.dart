import '../../../tasks/domain/entities/task.dart';
import '../entities/ai_task_suggestion.dart';

/// Reglas puras para comparar el borrador de la IA con las tareas del proyecto.

AiTaskSuggestion aiSuggestionFromTask(Task task) {
  return AiTaskSuggestion(
    title: task.title,
    description: task.description,
    complexity: task.complexity,
    estimatedHours: task.estimatedHours,
    tags: List<String>.from(task.tags),
    subtasks: task.subtasks.map((s) => s.title).toList(),
  );
}

List<AiTaskSuggestion> aiSuggestionsFromTasks(List<Task> tasks) {
  return tasks.map(aiSuggestionFromTask).toList();
}

Set<String> baselineTitleKeys(List<AiTaskSuggestion> baseline) {
  return baseline
      .map((t) => t.title.trim().toLowerCase())
      .where((t) => t.isNotEmpty)
      .toSet();
}

/// Tareas del borrador cuyo título (sin mayúsculas ni espacios) no está en `baseline`.
List<AiTaskSuggestion> newTasksInDraft({
  required List<AiTaskSuggestion> draft,
  required List<AiTaskSuggestion> baseline,
}) {
  final existing = baselineTitleKeys(baseline);
  return draft
      .where((t) => t.title.trim().isNotEmpty)
      .where((t) => !existing.contains(t.title.trim().toLowerCase()))
      .toList();
}

List<Subtask> subtasksFromAiSuggestion(AiTaskSuggestion suggestion) {
  return suggestion.subtasks
      .asMap()
      .entries
      .map((e) => Subtask(id: e.key + 1, title: e.value, isDone: false))
      .toList();
}
