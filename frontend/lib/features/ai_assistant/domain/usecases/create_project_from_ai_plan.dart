import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../projects/domain/entities/project.dart';
import '../../../projects/domain/usecases/projects_usecases.dart';
import '../entities/ai_task_suggestion.dart';
import 'apply_ai_task_suggestions.dart';

class CreateProjectFromAiPlanParams {
  const CreateProjectFromAiPlanParams({
    required this.title,
    required this.description,
    required this.draft,
  });

  final String title;
  final String description;
  final List<AiTaskSuggestion> draft;
}

/// Proyecto recién creado y cuántas tareas del plan se crearon en él.
/// [taskFailure] indica que el proyecto existe pero alguna tarea no se pudo crear.
class ProjectFromAiPlan {
  const ProjectFromAiPlan({
    required this.project,
    required this.createdTasks,
    this.taskFailure,
  });

  final Project project;
  final int createdTasks;
  final Failure? taskFailure;
}

/// Crea el proyecto y después las tareas del borrador del asistente IA.
class CreateProjectFromAiPlan
    implements UseCase<ProjectFromAiPlan, CreateProjectFromAiPlanParams> {
  CreateProjectFromAiPlan(this._createProject, this._applyAiTaskSuggestions);

  final CreateProject _createProject;
  final ApplyAiTaskSuggestions _applyAiTaskSuggestions;

  @override
  Future<Result<ProjectFromAiPlan>> call(
    CreateProjectFromAiPlanParams params,
  ) async {
    final title = params.title.trim();
    if (title.isEmpty) {
      return const ResultFailure(
        ValidationFailure('El proyecto necesita un título.'),
      );
    }
    final created = await _createProject(
      CreateProjectParams(title: title, description: params.description.trim()),
    );
    final createFailure = created.failureOrNull;
    if (createFailure != null) return ResultFailure(createFailure);
    final project = created.valueOrNull!;

    final applied = await _applyAiTaskSuggestions(
      ApplyAiTaskSuggestionsParams(
        projectId: project.id,
        draft: params.draft,
        baseline: const [],
      ),
    );
    return Success(
      ProjectFromAiPlan(
        project: project,
        createdTasks: applied.valueOrNull ?? 0,
        taskFailure: applied.failureOrNull,
      ),
    );
  }
}
