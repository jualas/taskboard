import '../models/models.dart';
import '../services/ai_assistant_service.dart';
import '../services/tasks_service.dart';

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
      .map(
        (e) => Subtask(
          id: e.key + 1,
          title: e.value,
          isDone: false,
        ),
      )
      .toList();
}

Future<int> applyNewAiTasksToProject({
  required TasksService tasksService,
  required int projectId,
  required List<AiTaskSuggestion> draft,
  required List<AiTaskSuggestion> baseline,
}) async {
  final toCreate = newTasksInDraft(draft: draft, baseline: baseline);
  for (final s in toCreate) {
    await tasksService.createTask(
      projectId: projectId,
      title: s.title,
      description: s.description,
      complexity: s.complexity,
      estimatedHours: s.estimatedHours,
      tags: s.tags,
      subtasks: subtasksFromAiSuggestion(s),
    );
  }
  return toCreate.length;
}
