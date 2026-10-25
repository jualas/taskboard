import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_taskboard/core/error/failures.dart';
import 'package:personal_taskboard/core/error/result.dart';
import 'package:personal_taskboard/features/ai_assistant/domain/entities/ai_chat.dart';
import 'package:personal_taskboard/features/ai_assistant/domain/entities/ai_task_suggestion.dart';
import 'package:personal_taskboard/features/ai_assistant/domain/usecases/suggest_tasks.dart';
import 'package:personal_taskboard/features/ai_assistant/presentation/bloc/task_ai_suggestion_cubit.dart';
import 'package:personal_taskboard/features/tasks/domain/entities/task.dart';

class _MockSuggestTasks extends Mock implements SuggestTasks {}

const _suggestion = AiTaskSuggestion(
  title: 'Exportar CSV',
  description: 'd',
  complexity: TaskComplexity.medium,
  estimatedHours: 3,
  tags: ['csv'],
  subtasks: ['a'],
);

void main() {
  late _MockSuggestTasks suggestTasks;

  setUpAll(() {
    registerFallbackValue(
      const SuggestTasksParams(
        userMessage: '',
        projectTitle: '',
        projectDescription: '',
      ),
    );
  });

  setUp(() => suggestTasks = _MockSuggestTasks());

  TaskAiSuggestionCubit build() =>
      TaskAiSuggestionCubit(suggestTasks: suggestTasks);

  Future<void> suggest(TaskAiSuggestionCubit c) =>
      c.suggest(brief: 'b', projectTitle: 'P', projectDescription: '');

  blocTest<TaskAiSuggestionCubit, TaskAiSuggestionState>(
    'éxito: primera sugerencia y proveedor',
    setUp: () => when(() => suggestTasks(any())).thenAnswer(
      (_) async => const Success(
        AiSuggestionResult(
          suggestions: [_suggestion],
          provider: 'cursor_agent',
        ),
      ),
    ),
    build: build,
    act: suggest,
    expect: () => const [
      TaskAiSuggestionState(status: TaskAiSuggestionStatus.loading),
      TaskAiSuggestionState(
        status: TaskAiSuggestionStatus.success,
        suggestion: _suggestion,
        providerLabel: 'Cursor Agent',
      ),
    ],
  );

  blocTest<TaskAiSuggestionCubit, TaskAiSuggestionState>(
    'respuesta sin tareas útiles',
    setUp: () => when(() => suggestTasks(any())).thenAnswer(
      (_) async => const Success(AiSuggestionResult(suggestions: [])),
    ),
    build: build,
    act: suggest,
    expect: () => const [
      TaskAiSuggestionState(status: TaskAiSuggestionStatus.loading),
      TaskAiSuggestionState(status: TaskAiSuggestionStatus.empty),
    ],
  );

  blocTest<TaskAiSuggestionCubit, TaskAiSuggestionState>(
    'error del proveedor: mensaje para el usuario',
    setUp: () => when(() => suggestTasks(any())).thenAnswer(
      (_) async => const ResultFailure(
        ServerFailure(
          statusCode: 402,
          message: 'Error IA (402): Insufficient Balance',
        ),
      ),
    ),
    build: build,
    act: suggest,
    expect: () => [
      const TaskAiSuggestionState(status: TaskAiSuggestionStatus.loading),
      isA<TaskAiSuggestionState>()
          .having((s) => s.status, 'status', TaskAiSuggestionStatus.failure)
          .having(
            (s) => s.errorMessage,
            'errorMessage',
            startsWith('DeepSeek'),
          ),
    ],
  );
}
