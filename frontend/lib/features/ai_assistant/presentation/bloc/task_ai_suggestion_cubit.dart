import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/ai_task_suggestion.dart';
import '../../domain/usecases/suggest_tasks.dart';
import '../utils/ai_error_messages.dart';

enum TaskAiSuggestionStatus { idle, loading, success, empty, failure }

class TaskAiSuggestionState extends Equatable {
  const TaskAiSuggestionState({
    this.status = TaskAiSuggestionStatus.idle,
    this.suggestion,
    this.providerLabel,
    this.errorMessage,
  });

  final TaskAiSuggestionStatus status;

  /// Primera sugerencia con título (solo en `success`).
  final AiTaskSuggestion? suggestion;
  final String? providerLabel;
  final String? errorMessage;

  bool get isLoading => status == TaskAiSuggestionStatus.loading;

  @override
  List<Object?> get props => [status, suggestion, providerLabel, errorMessage];
}

/// «Sugerir con IA» del formulario de tarea.
class TaskAiSuggestionCubit extends Cubit<TaskAiSuggestionState> {
  TaskAiSuggestionCubit({required SuggestTasks suggestTasks})
    : _suggestTasks = suggestTasks,
      super(const TaskAiSuggestionState());

  final SuggestTasks _suggestTasks;

  Future<void> suggest({
    required String brief,
    required String projectTitle,
    required String projectDescription,
  }) async {
    if (state.isLoading) return;
    emit(const TaskAiSuggestionState(status: TaskAiSuggestionStatus.loading));
    final result = await _suggestTasks(
      SuggestTasksParams(
        userMessage: brief,
        projectTitle: projectTitle,
        projectDescription: projectDescription,
      ),
    );
    emit(
      result.when(
        success: (r) => r.suggestions.isEmpty
            ? const TaskAiSuggestionState(status: TaskAiSuggestionStatus.empty)
            : TaskAiSuggestionState(
                status: TaskAiSuggestionStatus.success,
                suggestion: r.suggestions.first,
                providerLabel: r.providerLabel,
              ),
        onFailure: (f) => TaskAiSuggestionState(
          status: TaskAiSuggestionStatus.failure,
          errorMessage: describeAiFailure(f),
        ),
      ),
    );
  }
}
