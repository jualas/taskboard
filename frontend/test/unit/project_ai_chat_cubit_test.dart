import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_taskboard/core/error/failures.dart';
import 'package:personal_taskboard/core/error/result.dart';
import 'package:personal_taskboard/features/ai_assistant/domain/entities/agent_session.dart';
import 'package:personal_taskboard/features/ai_assistant/domain/entities/ai_chat.dart';
import 'package:personal_taskboard/features/ai_assistant/domain/entities/ai_task_suggestion.dart';
import 'package:personal_taskboard/features/ai_assistant/domain/usecases/ai_assistant_usecases.dart';
import 'package:personal_taskboard/features/ai_assistant/presentation/bloc/project_ai_chat_cubit.dart';
import 'package:personal_taskboard/features/tasks/domain/entities/task.dart';

class _MockSuggestProjectPlan extends Mock implements SuggestProjectPlan {}

class _MockSendProjectChatMessage extends Mock
    implements SendProjectChatMessage {}

class _MockStreamAgentRun extends Mock implements StreamAgentRun {}

class _MockGetAgentSession extends Mock implements GetAgentSession {}

class _MockResetAgentSession extends Mock implements ResetAgentSession {}

class _MockGetAgentRuns extends Mock implements GetAgentRuns {}

class _MockApply extends Mock implements ApplyAiTaskSuggestions {}

AiTaskSuggestion _s(String title) => AiTaskSuggestion(
  title: title,
  description: '',
  complexity: TaskComplexity.simple,
  estimatedHours: null,
  tags: const [],
  subtasks: const [],
);

final _t = DateTime(2026, 1, 1);

final _existing = Task(
  id: 1,
  projectId: 4,
  title: 'Login',
  description: '',
  status: TaskStatus.pending,
  kanbanPosition: 0,
  complexity: TaskComplexity.simple,
  tags: const [],
  createdAt: _t,
  updatedAt: _t,
);

void main() {
  late _MockSuggestProjectPlan suggestProjectPlan;
  late _MockSendProjectChatMessage sendMessage;
  late _MockStreamAgentRun streamAgentRun;
  late _MockGetAgentSession getAgentSession;
  late _MockResetAgentSession resetAgentSession;
  late _MockGetAgentRuns getAgentRuns;
  late _MockApply apply;

  setUpAll(() {
    registerFallbackValue(
      const SuggestProjectPlanParams(projectTitle: '', projectDescription: ''),
    );
    registerFallbackValue(
      const SendProjectChatMessageParams(
        projectTitle: '',
        projectDescription: '',
        messages: [],
        draftTasks: [],
      ),
    );
    registerFallbackValue(const StreamAgentRunParams(prompt: ''));
    registerFallbackValue(
      const ApplyAiTaskSuggestionsParams(projectId: 0, draft: [], baseline: []),
    );
  });

  setUp(() {
    suggestProjectPlan = _MockSuggestProjectPlan();
    sendMessage = _MockSendProjectChatMessage();
    streamAgentRun = _MockStreamAgentRun();
    getAgentSession = _MockGetAgentSession();
    resetAgentSession = _MockResetAgentSession();
    getAgentRuns = _MockGetAgentRuns();
    apply = _MockApply();
    when(
      () => getAgentSession(any()),
    ).thenAnswer((_) async => const Success(null));
    when(() => getAgentRuns(any())).thenAnswer((_) async => const Success([]));
  });

  ProjectAiChatCubit build({
    ProjectAiChatMode mode = ProjectAiChatMode.existing,
  }) =>
      ProjectAiChatCubit(
        suggestProjectPlan: suggestProjectPlan,
        sendProjectChatMessage: sendMessage,
        streamAgentRun: streamAgentRun,
        getAgentSession: getAgentSession,
        resetAgentSession: resetAgentSession,
        getAgentRuns: getAgentRuns,
        applyAiTaskSuggestions: apply,
      )..start(
        mode: mode,
        projectTitle: 'P',
        projectDescription: 'D',
        projectId: mode == ProjectAiChatMode.existing ? 4 : null,
        existingTasks: mode == ProjectAiChatMode.existing
            ? [_existing]
            : const [],
      );

  test('start: saludo y borrador con las tareas existentes', () {
    final cubit = build();
    expect(cubit.state.entries.single.role, 'assistant');
    expect(cubit.state.baseline.single.title, 'Login');
    expect(cubit.state.draftTasks, cubit.state.baseline);
    expect(cubit.state.newDraftTasks, isEmpty);
  });

  blocTest<ProjectAiChatCubit, ProjectAiChatState>(
    'planificar: la respuesta actualiza el borrador y el historial',
    setUp: () => when(() => sendMessage(any())).thenAnswer(
      (_) async => Success(
        AiChatReply(
          message: 'Añado una',
          tasks: [_s('Login'), _s('Exportar')],
          provider: 'deepseek',
        ),
      ),
    ),
    build: build,
    act: (c) => c.sendPlanMessage('más tareas'),
    verify: (c) {
      final s = c.state;
      expect(s.isLoading, isFalse);
      expect(s.entries.map((e) => e.role), ['assistant', 'user', 'assistant']);
      expect(s.history.map((m) => m.content), ['más tareas', 'Añado una']);
      expect(s.newDraftTasks.map((t) => t.title), ['Exportar']);
      expect(s.providerLabel, 'DeepSeek (nube)');
      final params =
          verify(() => sendMessage(captureAny())).captured.single
              as SendProjectChatMessageParams;
      expect(params.projectId, 4);
      expect(params.draftTasks.single.title, 'Login');
    },
  );

  blocTest<ProjectAiChatCubit, ProjectAiChatState>(
    'planificar: el error del proveedor aparece como mensaje del asistente',
    setUp: () => when(() => sendMessage(any())).thenAnswer(
      (_) async => const ResultFailure(
        UnexpectedFailure('ClientException: Failed to fetch'),
      ),
    ),
    build: build,
    act: (c) => c.sendPlanMessage('hola'),
    verify: (c) {
      expect(c.state.isLoading, isFalse);
      expect(
        c.state.entries.last.content,
        startsWith('No se pudo llamar a la función IA'),
      );
      expect(c.state.history, hasLength(1));
      expect(c.state.draftTasks.single.title, 'Login');
    },
  );

  blocTest<ProjectAiChatCubit, ProjectAiChatState>(
    'proyecto nuevo: el primer mensaje pide el plan inicial',
    setUp: () => when(() => suggestProjectPlan(any())).thenAnswer(
      (_) async => Success(AiSuggestionResult(suggestions: [_s('A'), _s('B')])),
    ),
    build: () => build(mode: ProjectAiChatMode.create),
    act: (c) => c.sendPlanMessage('una web'),
    verify: (c) {
      expect(c.state.draftTasks.map((t) => t.title), ['A', 'B']);
      expect(
        c.state.entries.last.content,
        startsWith('Plan inicial con 2 tarea(s)'),
      );
      verifyNever(() => sendMessage(any()));
    },
  );

  blocTest<ProjectAiChatCubit, ProjectAiChatState>(
    'agent: acumula la salida, guarda la sesión y recarga el historial',
    setUp: () => when(() => streamAgentRun(any())).thenAnswer(
      (_) => Stream.fromIterable(const [
        Success(AgentStreamEvent(kind: 'init', text: 'arrancando')),
        Success(AgentStreamEvent(kind: 'session', sessionId: 'sess-123456789')),
        Success(AgentStreamEvent(kind: 'text', text: 'Hola')),
        Success(AgentStreamEvent(kind: 'text', text: 'Hola mundo')),
      ]),
    ),
    build: build,
    act: (c) => c.sendAgentMessage('revisa', execute: true),
    verify: (c) {
      final terminal = c.state.entries.last;
      expect(terminal.isTerminal, isTrue);
      expect(terminal.isStreaming, isFalse);
      expect(terminal.content, 'arrancando\nHola mundo');
      expect(c.state.isLoading, isFalse);
      expect(c.state.continueSession, isTrue);
      final params =
          verify(() => streamAgentRun(captureAny())).captured.single
              as StreamAgentRunParams;
      expect(params.execute, isTrue);
      expect(params.projectId, 4);
      verify(() => getAgentRuns(4)).called(1);
    },
  );

  blocTest<ProjectAiChatCubit, ProjectAiChatState>(
    'agent: un error sustituye la salida por el mensaje',
    setUp: () => when(() => streamAgentRun(any())).thenAnswer(
      (_) => Stream.fromIterable(const [
        Success(AgentStreamEvent(kind: 'log', text: 'x')),
        ResultFailure(
          ServerFailure(statusCode: 502, message: 'Error IA (502): boom'),
        ),
      ]),
    ),
    build: build,
    act: (c) => c.sendAgentMessage('revisa', execute: false),
    verify: (c) {
      expect(c.state.entries.last.content, startsWith('✗ Error 502'));
      expect(c.state.isLoading, isFalse);
    },
  );

  blocTest<ProjectAiChatCubit, ProjectAiChatState>(
    'reiniciar sesión: fuerza una conversación nueva',
    setUp: () => when(
      () => resetAgentSession(4),
    ).thenAnswer((_) async => const Success(null)),
    build: build,
    act: (c) => c.resetAgentSession(),
    verify: (c) {
      expect(c.state.agentSession, isNull);
      expect(c.state.continueSession, isFalse);
      expect(c.state.forceNewSession, isTrue);
    },
  );

  blocTest<ProjectAiChatCubit, ProjectAiChatState>(
    'aplicar: las tareas creadas pasan a la base',
    setUp: () {
      when(() => sendMessage(any())).thenAnswer(
        (_) async => Success(
          AiChatReply(message: 'ok', tasks: [_s('Login'), _s('Nueva')]),
        ),
      );
      when(() => apply(any())).thenAnswer((_) async => const Success(1));
    },
    build: build,
    act: (c) async {
      await c.sendPlanMessage('más');
      final result = await c.applyNewTasks();
      expect(result.valueOrNull, 1);
    },
    verify: (c) {
      expect(c.state.isApplying, isFalse);
      expect(c.state.newDraftTasks, isEmpty);
    },
  );

  blocTest<ProjectAiChatCubit, ProjectAiChatState>(
    'aplicar: si falla, el borrador sigue pendiente',
    setUp: () {
      when(() => sendMessage(any())).thenAnswer(
        (_) async => Success(AiChatReply(message: 'ok', tasks: [_s('Nueva')])),
      );
      when(() => apply(any())).thenAnswer(
        (_) async =>
            const ResultFailure(ServerFailure(message: 'Permiso denegado.')),
      );
    },
    build: build,
    act: (c) async {
      await c.sendPlanMessage('más');
      await c.applyNewTasks();
    },
    verify: (c) => expect(c.state.newDraftTasks.single.title, 'Nueva'),
  );
}
