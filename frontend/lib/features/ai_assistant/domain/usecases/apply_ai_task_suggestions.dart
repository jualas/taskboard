import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../tasks/domain/usecases/tasks_usecases.dart';
import '../entities/ai_task_suggestion.dart';
import '../services/ai_task_conversion.dart';

class ApplyAiTaskSuggestionsParams {
  const ApplyAiTaskSuggestionsParams({
    required this.projectId,
    required this.draft,
    required this.baseline,
  });

  final int projectId;
  final List<AiTaskSuggestion> draft;
  final List<AiTaskSuggestion> baseline;
}

/// Crea en el proyecto solo las tareas del borrador que aún no existen.
/// Devuelve cuántas se crearon; se detiene en el primer fallo.
class ApplyAiTaskSuggestions
    implements UseCase<int, ApplyAiTaskSuggestionsParams> {
  ApplyAiTaskSuggestions(this._createTask);

  final CreateTask _createTask;

  @override
  Future<Result<int>> call(ApplyAiTaskSuggestionsParams params) async {
    final toCreate = newTasksInDraft(
      draft: params.draft,
      baseline: params.baseline,
    );
    for (final s in toCreate) {
      final result = await _createTask(
        CreateTaskParams(
          projectId: params.projectId,
          title: s.title,
          description: s.description,
          complexity: s.complexity,
          estimatedHours: s.estimatedHours,
          tags: s.tags,
          subtasks: subtasksFromAiSuggestion(s),
        ),
      );
      final failure = result.failureOrNull;
      if (failure != null) return ResultFailure(failure);
    }
    return Success(toCreate.length);
  }
}
