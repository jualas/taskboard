import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_taskboard/core/error/failures.dart';
import 'package:personal_taskboard/core/error/result.dart';
import 'package:personal_taskboard/features/ai_assistant/domain/entities/agent_session.dart';
import 'package:personal_taskboard/features/ai_assistant/domain/entities/ai_chat.dart';
import 'package:personal_taskboard/features/ai_assistant/domain/entities/ai_task_suggestion.dart';
import 'package:personal_taskboard/features/ai_assistant/domain/repositories/ai_assistant_repository.dart';
import 'package:personal_taskboard/features/ai_assistant/domain/usecases/ai_assistant_usecases.dart';
import 'package:personal_taskboard/features/projects/domain/entities/project.dart';
import 'package:personal_taskboard/features/projects/domain/usecases/projects_usecases.dart';
import 'package:personal_taskboard/features/tasks/domain/entities/task.dart';
import 'package:personal_taskboard/features/tasks/domain/usecases/tasks_usecases.dart';

class _MockAiRepository extends Mock implements AiAssistantRepository {}

class _MockCreateTask extends Mock implements CreateTask {}

class _MockCreateProject extends Mock implements CreateProject {}

class _MockApply extends Mock implements ApplyAiTaskSuggestions {}

AiTaskSuggestion _s(String title) => AiTaskSuggestion(
  title: title,
  description: 'd',
  complexity: TaskComplexity.complex,
  estimatedHours: 2,
  tags: const ['ia'],
  subtasks: const ['a', 'b'],
);

final _t = DateTime(2026, 1, 1);

Task _created(CreateTaskParams p) => Task(
  id: 1,
  projectId: p.projectId,
  title: p.title,
  description: p.description,
  status: TaskStatus.pending,
  kanbanPosition: 0,
  complexity: p.complexity,
  tags: p.tags,
  createdAt: _t,
  updatedAt: _t,
);

void main() {
  late _MockAiRepository repo;

  setUpAll(() {
    registerFallbackValue(const CreateTaskParams(projectId: 0, title: ''));
    registerFallbackValue(const CreateProjectParams(title: ''));
    registerFallbackValue(
      const ApplyAiTaskSuggestionsParams(projectId: 0, draft: [], baseline: []),
    );
  });

  setUp(() => repo = _MockAiRepository());

  test('SuggestTasks pasa brief y contexto del proyecto', () async {
    final expected = AiSuggestionResult(
      suggestions: [_s('x')],
      provider: 'local',
    );
    when(
      () => repo.suggestTasks(
        userMessage: 'brief',
        projectTitle: 'P',
        projectDescription: 'D',
      ),
    ).thenAnswer((_) async => Success(expected));

    final result = await SuggestTasks(repo)(
      const SuggestTasksParams(
        userMessage: 'brief',
        projectTitle: 'P',
        projectDescription: 'D',
      ),
    );
    expect(result.valueOrNull, expected);
    expect(result.valueOrNull!.providerLabel, 'Ollama (local)');
  });

  test('SuggestTasks propaga el fallo del proveedor', () async {
    when(
      () => repo.suggestTasks(
        userMessage: any(named: 'userMessage'),
        projectTitle: any(named: 'projectTitle'),
        projectDescription: any(named: 'projectDescription'),
      ),
    ).thenAnswer(
      (_) async => const ResultFailure(
        ServerFailure(statusCode: 502, message: 'Error IA (502)'),
      ),
    );
    final result = await SuggestTasks(repo)(
      const SuggestTasksParams(
        userMessage: 'b',
        projectTitle: 'P',
        projectDescription: '',
      ),
    );
    expect(result.failureOrNull, isA<ServerFailure>());
  });

  test('SuggestProjectPlan recorta el mensaje', () async {
    when(
      () => repo.suggestProjectPlan(
        projectTitle: 'P',
        projectDescription: 'D',
        userMessage: 'hola',
      ),
    ).thenAnswer(
      (_) async => const Success(AiSuggestionResult(suggestions: [])),
    );
    final result = await SuggestProjectPlan(repo)(
      const SuggestProjectPlanParams(
        projectTitle: 'P',
        projectDescription: 'D',
        userMessage: '  hola ',
      ),
    );
    expect(result.isSuccess, isTrue);
  });

  test('SendProjectChatMessage envía historial y borrador', () async {
    const messages = [AiChatMessage(role: 'user', content: 'más tareas')];
    final draft = [_s('a')];
    when(
      () => repo.chatProjectPlan(
        projectTitle: 'P',
        projectDescription: 'D',
        messages: messages,
        draftTasks: draft,
        projectId: 5,
      ),
    ).thenAnswer(
      (_) async => const Success(AiChatReply(message: 'ok', tasks: null)),
    );

    final result = await SendProjectChatMessage(repo)(
      SendProjectChatMessageParams(
        projectTitle: 'P',
        projectDescription: 'D',
        messages: messages,
        draftTasks: draft,
        projectId: 5,
      ),
    );
    expect(result.valueOrNull!.message, 'ok');
  });

  test('sesión agent: obtener, reiniciar, historial y stream', () async {
    final session = AgentSession(
      projectId: 3,
      sessionId: 's1',
      updatedAt: DateTime(2026, 1, 1),
    );
    when(
      () => repo.getAgentSession(3),
    ).thenAnswer((_) async => Success(session));
    when(
      () => repo.resetAgentSession(3),
    ).thenAnswer((_) async => const Success(null));
    when(() => repo.getAgentRuns(3)).thenAnswer((_) async => const Success([]));
    when(
      () => repo.streamAgentRun(
        prompt: 'p',
        projectId: 3,
        projectTitle: 'P',
        projectDescription: '',
        execute: true,
        continueSession: false,
        newSession: true,
      ),
    ).thenAnswer(
      (_) => Stream.value(const Success(AgentStreamEvent(kind: 'text'))),
    );

    expect((await GetAgentSession(repo)(3)).valueOrNull, session);
    expect((await ResetAgentSession(repo)(3)).isSuccess, isTrue);
    expect((await GetAgentRuns(repo)(3)).valueOrNull, isEmpty);
    final events = await StreamAgentRun(repo)(
      const StreamAgentRunParams(
        prompt: 'p',
        projectId: 3,
        projectTitle: 'P',
        execute: true,
        continueSession: false,
        newSession: true,
      ),
    ).toList();
    expect(events.single.valueOrNull!.kind, 'text');
  });

  group('ApplyAiTaskSuggestions', () {
    late _MockCreateTask createTask;

    setUp(() => createTask = _MockCreateTask());

    test('crea solo las tareas nuevas con su checklist', () async {
      when(() => createTask(any())).thenAnswer(
        (inv) async => Success(
          _created(inv.positionalArguments.first as CreateTaskParams),
        ),
      );

      final result = await ApplyAiTaskSuggestions(createTask)(
        ApplyAiTaskSuggestionsParams(
          projectId: 9,
          draft: [_s('Existente'), _s('Nueva')],
          baseline: [_s('existente')],
        ),
      );

      expect(result.valueOrNull, 1);
      final params =
          verify(() => createTask(captureAny())).captured.single
              as CreateTaskParams;
      expect(params.projectId, 9);
      expect(params.title, 'Nueva');
      expect(params.complexity, TaskComplexity.complex);
      expect(params.estimatedHours, 2);
      expect(params.subtasks.map((s) => s.id), [1, 2]);
    });

    test('se detiene en el primer fallo', () async {
      when(() => createTask(any())).thenAnswer(
        (_) async =>
            const ResultFailure(ServerFailure(message: 'Permiso denegado.')),
      );

      final result = await ApplyAiTaskSuggestions(createTask)(
        ApplyAiTaskSuggestionsParams(
          projectId: 9,
          draft: [_s('A'), _s('B')],
          baseline: const [],
        ),
      );

      expect(result.failureOrNull?.message, 'Permiso denegado.');
      verify(() => createTask(any())).called(1);
    });
  });

  group('CreateProjectFromAiPlan', () {
    late _MockCreateProject createProject;
    late _MockApply apply;

    setUp(() {
      createProject = _MockCreateProject();
      apply = _MockApply();
    });

    CreateProjectFromAiPlan useCase() =>
        CreateProjectFromAiPlan(createProject, apply);

    test('crea el proyecto y todas las tareas del borrador', () async {
      when(() => createProject(any())).thenAnswer(
        (_) async => Success(Project.create(id: 12, title: 'Web')),
      );
      when(() => apply(any())).thenAnswer((_) async => const Success(2));

      final result = await useCase()(
        CreateProjectFromAiPlanParams(
          title: ' Web ',
          description: ' Tienda ',
          draft: [_s('A'), _s('B')],
        ),
      );

      final created = result.valueOrNull!;
      expect(created.project.id, 12);
      expect(created.createdTasks, 2);
      expect(created.taskFailure, isNull);
      final projectParams =
          verify(() => createProject(captureAny())).captured.single
              as CreateProjectParams;
      expect(projectParams.title, 'Web');
      expect(projectParams.description, 'Tienda');
      final applyParams =
          verify(() => apply(captureAny())).captured.single
              as ApplyAiTaskSuggestionsParams;
      expect(applyParams.projectId, 12);
      expect(applyParams.draft, hasLength(2));
      expect(applyParams.baseline, isEmpty);
    });

    test('sin título no crea nada', () async {
      final result = await useCase()(
        const CreateProjectFromAiPlanParams(
          title: '  ',
          description: '',
          draft: [],
        ),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      verifyNever(() => createProject(any()));
    });

    test('si falla el proyecto no intenta las tareas', () async {
      when(() => createProject(any())).thenAnswer(
        (_) async => const ResultFailure(NetworkFailure()),
      );

      final result = await useCase()(
        CreateProjectFromAiPlanParams(
          title: 'Web',
          description: '',
          draft: [_s('A')],
        ),
      );

      expect(result.failureOrNull, isA<NetworkFailure>());
      verifyNever(() => apply(any()));
    });

    test('si fallan las tareas devuelve el proyecto con el fallo', () async {
      when(() => createProject(any())).thenAnswer(
        (_) async => Success(Project.create(id: 12, title: 'Web')),
      );
      when(() => apply(any())).thenAnswer(
        (_) async =>
            const ResultFailure(ServerFailure(message: 'Permiso denegado.')),
      );

      final result = await useCase()(
        CreateProjectFromAiPlanParams(
          title: 'Web',
          description: '',
          draft: [_s('A')],
        ),
      );

      final created = result.valueOrNull!;
      expect(created.project.id, 12);
      expect(created.taskFailure?.message, 'Permiso denegado.');
    });
  });
}
