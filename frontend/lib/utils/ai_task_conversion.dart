import '../features/tasks/domain/entities/task.dart' as domain;
import '../features/tasks/domain/usecases/tasks_usecases.dart';
import '../models/task.dart' as legacy;
import '../services/ai_assistant_service.dart';

legacy.TaskComplexity _legacyComplexity(domain.TaskComplexity c) {
  switch (c) {
    case domain.TaskComplexity.simple:
      return legacy.TaskComplexity.simple;
    case domain.TaskComplexity.medium:
      return legacy.TaskComplexity.medium;
    case domain.TaskComplexity.complex:
      return legacy.TaskComplexity.complex;
  }
}

domain.TaskComplexity domainComplexityFromLegacy(legacy.TaskComplexity c) {
  switch (c) {
    case legacy.TaskComplexity.simple:
      return domain.TaskComplexity.simple;
    case legacy.TaskComplexity.medium:
      return domain.TaskComplexity.medium;
    case legacy.TaskComplexity.complex:
      return domain.TaskComplexity.complex;
  }
}

AiTaskSuggestion aiSuggestionFromTask(domain.Task task) {
  return AiTaskSuggestion(
    title: task.title,
    description: task.description,
    complexity: _legacyComplexity(task.complexity),
    estimatedHours: task.estimatedHours,
    tags: List<String>.from(task.tags),
    subtasks: task.subtasks.map((s) => s.title).toList(),
  );
}

List<AiTaskSuggestion> aiSuggestionsFromTasks(List<domain.Task> tasks) {
  return tasks.map(aiSuggestionFromTask).toList();
}

Set<String> baselineTitleKeys(List<AiTaskSuggestion> baseline) {
  return baseline
      .map((t) => t.title.trim().toLowerCase())
      .where((t) => t.isNotEmpty)
      .toSet();
}

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

List<domain.Subtask> subtasksFromAiSuggestion(AiTaskSuggestion suggestion) {
  return suggestion.subtasks
      .asMap()
      .entries
      .map(
        (e) => domain.Subtask(
          id: e.key + 1,
          title: e.value,
          isDone: false,
        ),
      )
      .toList();
}

Future<int> applyNewAiTasksToProject({
  required CreateTask createTask,
  required int projectId,
  required List<AiTaskSuggestion> draft,
  required List<AiTaskSuggestion> baseline,
}) async {
  final toCreate = newTasksInDraft(draft: draft, baseline: baseline);
  for (final s in toCreate) {
    final result = await createTask(
      CreateTaskParams(
        projectId: projectId,
        title: s.title,
        description: s.description,
        complexity: domainComplexityFromLegacy(s.complexity),
        estimatedHours: s.estimatedHours,
        tags: s.tags,
        subtasks: subtasksFromAiSuggestion(s),
      ),
    );
    if (result.isFailure) {
      throw StateError(result.failureOrNull?.message ?? 'Error al crear tarea');
    }
  }
  return toCreate.length;
}
