import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/result.dart';
import '../../../tasks/domain/entities/task.dart';
import '../../domain/entities/agent_session.dart';
import '../../domain/entities/ai_chat.dart';
import '../../domain/entities/ai_task_suggestion.dart';
import '../../domain/services/ai_task_conversion.dart';
import '../../domain/usecases/ai_assistant_usecases.dart';
import '../utils/ai_error_messages.dart';

enum ProjectAiChatMode { create, existing }

/// Burbuja del chat: `user`, `assistant` o `terminal` (salida de Cursor Agent).
class AiChatEntry extends Equatable {
  const AiChatEntry({
    required this.role,
    required this.content,
    this.isStreaming = false,
  });

  final String role;
  final String content;
  final bool isStreaming;

  bool get isUser => role == 'user';
  bool get isTerminal => role == 'terminal';

  @override
  List<Object?> get props => [role, content, isStreaming];
}

class ProjectAiChatState extends Equatable {
  const ProjectAiChatState({
    this.entries = const [],
    this.history = const [],
    this.baseline = const [],
    this.draftTasks = const [],
    this.isLoading = false,
    this.isApplying = false,
    this.providerLabel,
    this.agentSession,
    this.agentRuns = const [],
    this.continueSession = true,
    this.forceNewSession = false,
  });

  final List<AiChatEntry> entries;

  /// Mensajes enviados al API en modo planificar (sin el saludo inicial).
  final List<AiChatMessage> history;

  /// Tareas que ya existen en el proyecto (o ya aplicadas).
  final List<AiTaskSuggestion> baseline;
  final List<AiTaskSuggestion> draftTasks;
  final bool isLoading;
  final bool isApplying;
  final String? providerLabel;
  final AgentSession? agentSession;
  final List<AgentRun> agentRuns;
  final bool continueSession;
  final bool forceNewSession;

  List<AiTaskSuggestion> get newDraftTasks =>
      newTasksInDraft(draft: draftTasks, baseline: baseline);

  ProjectAiChatState copyWith({
    List<AiChatEntry>? entries,
    List<AiChatMessage>? history,
    List<AiTaskSuggestion>? baseline,
    List<AiTaskSuggestion>? draftTasks,
    bool? isLoading,
    bool? isApplying,
    String? providerLabel,
    AgentSession? agentSession,
    bool clearAgentSession = false,
    List<AgentRun>? agentRuns,
    bool? continueSession,
    bool? forceNewSession,
  }) {
    return ProjectAiChatState(
      entries: entries ?? this.entries,
      history: history ?? this.history,
      baseline: baseline ?? this.baseline,
      draftTasks: draftTasks ?? this.draftTasks,
      isLoading: isLoading ?? this.isLoading,
      isApplying: isApplying ?? this.isApplying,
      providerLabel: providerLabel ?? this.providerLabel,
      agentSession: clearAgentSession
          ? null
          : (agentSession ?? this.agentSession),
      agentRuns: agentRuns ?? this.agentRuns,
      continueSession: continueSession ?? this.continueSession,
      forceNewSession: forceNewSession ?? this.forceNewSession,
    );
  }

  @override
  List<Object?> get props => [
    entries,
    history,
    baseline,
    draftTasks,
    isLoading,
    isApplying,
    providerLabel,
    agentSession,
    agentRuns,
    continueSession,
    forceNewSession,
  ];
}

/// Chat del asistente IA de un proyecto: planificar tareas o ejecutar Cursor Agent.
class ProjectAiChatCubit extends Cubit<ProjectAiChatState> {
  ProjectAiChatCubit({
    required SuggestProjectPlan suggestProjectPlan,
    required SendProjectChatMessage sendProjectChatMessage,
    required StreamAgentRun streamAgentRun,
    required GetAgentSession getAgentSession,
    required ResetAgentSession resetAgentSession,
    required GetAgentRuns getAgentRuns,
    required ApplyAiTaskSuggestions applyAiTaskSuggestions,
  }) : _suggestProjectPlan = suggestProjectPlan,
       _sendProjectChatMessage = sendProjectChatMessage,
       _streamAgentRun = streamAgentRun,
       _getAgentSession = getAgentSession,
       _resetAgentSession = resetAgentSession,
       _getAgentRuns = getAgentRuns,
       _applyAiTaskSuggestions = applyAiTaskSuggestions,
       super(const ProjectAiChatState());

  final SuggestProjectPlan _suggestProjectPlan;
  final SendProjectChatMessage _sendProjectChatMessage;
  final StreamAgentRun _streamAgentRun;
  final GetAgentSession _getAgentSession;
  final ResetAgentSession _resetAgentSession;
  final GetAgentRuns _getAgentRuns;
  final ApplyAiTaskSuggestions _applyAiTaskSuggestions;

  ProjectAiChatMode _mode = ProjectAiChatMode.existing;
  String _projectTitle = '';
  String _projectDescription = '';
  int? _projectId;

  final List<String> _agentLogLines = [];
  String _agentStreamText = '';

  /// Fija el proyecto y muestra el saludo inicial. Se llama una vez al abrir el panel.
  void start({
    required ProjectAiChatMode mode,
    required String projectTitle,
    required String projectDescription,
    int? projectId,
    List<Task> existingTasks = const [],
  }) {
    _mode = mode;
    _projectTitle = projectTitle;
    _projectDescription = projectDescription;
    _projectId = projectId;
    final baseline = aiSuggestionsFromTasks(existingTasks);
    emit(
      ProjectAiChatState(
        baseline: baseline,
        draftTasks: List<AiTaskSuggestion>.from(baseline),
        entries: [
          AiChatEntry(
            role: 'assistant',
            content: mode == ProjectAiChatMode.existing
                ? 'Puedo ayudarte a ampliar o refinar el plan de tareas del proyecto. '
                      'Describe qué necesitas y revisaré el borrador antes de crear tareas nuevas.'
                : 'Describe el proyecto o el alcance inicial y generaré un plan de tareas. '
                      'Luego podrás pedir cambios en el chat.',
          ),
        ],
      ),
    );
  }

  void setContinueSession(bool value) =>
      emit(state.copyWith(continueSession: value));

  /// Modo planificar. En un proyecto nuevo sin borrador, el primer mensaje
  /// pide el plan inicial; el resto son turnos del chat con el borrador actual.
  Future<void> sendPlanMessage(String text) async {
    if (text.isEmpty || state.isLoading) return;
    final history = [
      ...state.history,
      AiChatMessage(role: 'user', content: text),
    ];
    emit(
      state.copyWith(
        isLoading: true,
        entries: [
          ...state.entries,
          AiChatEntry(role: 'user', content: text),
        ],
        history: history,
      ),
    );

    final isFirstPlan =
        _mode == ProjectAiChatMode.create &&
        state.draftTasks.isEmpty &&
        history.where((m) => m.role == 'user').length == 1;

    if (isFirstPlan) {
      final result = await _suggestProjectPlan(
        SuggestProjectPlanParams(
          projectTitle: _projectTitle,
          projectDescription: _projectDescription,
          userMessage: text,
        ),
      );
      if (isClosed) return;
      result.when(
        success: (r) {
          final tasks = r.suggestions;
          final assistantText = tasks.isEmpty
              ? 'No pude generar tareas útiles. Prueba a ser más concreto sobre objetivos y entregables.'
              : 'Plan inicial con ${tasks.length} tarea(s). Revisa el borrador abajo y pide ajustes si hace falta.';
          emit(
            state.copyWith(
              isLoading: false,
              draftTasks: tasks,
              providerLabel: r.providerLabel,
              entries: [
                ...state.entries,
                AiChatEntry(role: 'assistant', content: assistantText),
              ],
              history: [
                ...state.history,
                AiChatMessage(role: 'assistant', content: assistantText),
              ],
            ),
          );
        },
        onFailure: (f) => _emitPlanError(describeAiFailure(f)),
      );
      return;
    }

    final result = await _sendProjectChatMessage(
      SendProjectChatMessageParams(
        projectTitle: _projectTitle,
        projectDescription: _projectDescription,
        messages: history,
        draftTasks: state.draftTasks,
        projectId: _projectId,
      ),
    );
    if (isClosed) return;
    result.when(
      success: (reply) => emit(
        state.copyWith(
          isLoading: false,
          entries: [
            ...state.entries,
            AiChatEntry(role: 'assistant', content: reply.message),
          ],
          history: [
            ...state.history,
            AiChatMessage(role: 'assistant', content: reply.message),
          ],
          draftTasks: reply.tasks,
          providerLabel: reply.providerLabel,
        ),
      ),
      onFailure: (f) => _emitPlanError(describeAiFailure(f)),
    );
  }

  void _emitPlanError(String message) {
    emit(
      state.copyWith(
        isLoading: false,
        entries: [
          ...state.entries,
          AiChatEntry(role: 'assistant', content: message),
        ],
      ),
    );
  }

  /// Modo agent: la salida del CLI se va acumulando en una burbuja `terminal`.
  Future<void> sendAgentMessage(String text, {required bool execute}) async {
    if (text.isEmpty || state.isLoading) return;
    _agentLogLines.clear();
    _agentStreamText = '';
    emit(
      state.copyWith(
        isLoading: true,
        providerLabel: 'Cursor Agent',
        entries: [
          ...state.entries,
          AiChatEntry(role: 'user', content: text),
          const AiChatEntry(role: 'terminal', content: '', isStreaming: true),
        ],
      ),
    );
    final terminalIndex = state.entries.length - 1;
    AgentSession? session = state.agentSession;
    String? error;

    await for (final result in _streamAgentRun(
      StreamAgentRunParams(
        prompt: text,
        projectId: _projectId,
        projectTitle: _projectTitle,
        projectDescription: _projectDescription,
        execute: execute,
        continueSession: state.continueSession,
        newSession: state.forceNewSession,
      ),
    )) {
      if (isClosed) return;
      final failure = result.failureOrNull;
      if (failure != null) {
        error = describeAiFailure(failure);
        break;
      }
      final event = result.valueOrNull!;
      switch (event.kind) {
        case 'init':
        case 'tool':
        case 'meta':
        case 'log':
          if (event.text.isNotEmpty) {
            _agentLogLines.add(event.text);
          }
          break;
        case 'session':
          if (event.text.isNotEmpty) {
            _agentLogLines.add(event.text);
          }
          session = _sessionFrom(event) ?? session;
          break;
        case 'text':
          _mergeAgentStreamText(event.text);
          break;
        case 'done':
          if (event.text.isNotEmpty) {
            _agentStreamText = event.text;
          }
          session = _sessionFrom(event) ?? session;
          break;
        case 'error':
          _agentLogLines.add('✗ ${event.text}');
          break;
      }
      emit(
        state.copyWith(
          agentSession: session,
          entries: _replaceAt(
            terminalIndex,
            AiChatEntry(
              role: 'terminal',
              content: _terminalDisplayText(),
              isStreaming: true,
            ),
          ),
        ),
      );
    }
    if (isClosed) return;

    final output = _terminalDisplayText();
    emit(
      state.copyWith(
        isLoading: false,
        forceNewSession: false,
        continueSession: session != null ? true : null,
        entries: _replaceAt(
          terminalIndex,
          AiChatEntry(
            role: 'terminal',
            content: error != null
                ? '✗ $error'
                : output.isEmpty
                ? '(sin salida del agente)'
                : output,
          ),
        ),
      ),
    );
    await loadAgentMeta();
  }

  AgentSession? _sessionFrom(AgentStreamEvent event) {
    final id = event.sessionId;
    if (id == null || id.isEmpty) return null;
    return AgentSession(
      projectId: _projectId ?? 0,
      sessionId: id,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  List<AiChatEntry> _replaceAt(int index, AiChatEntry entry) =>
      List<AiChatEntry>.from(state.entries)..[index] = entry;

  /// El CLI puede mandar el texto acumulado o solo el fragmento nuevo.
  void _mergeAgentStreamText(String piece) {
    if (piece.isEmpty) return;
    if (_agentStreamText.isEmpty) {
      _agentStreamText = piece;
      return;
    }
    if (piece.startsWith(_agentStreamText)) {
      _agentStreamText = piece;
      return;
    }
    if (_agentStreamText.startsWith(piece)) return;
    _agentStreamText += piece;
  }

  String _terminalDisplayText() {
    final parts = <String>[..._agentLogLines];
    if (_agentStreamText.isNotEmpty) {
      parts.add(_agentStreamText);
    }
    return parts.join('\n');
  }

  /// Sesión e historial agent del proyecto. Es opcional: si falla, no cambia nada.
  Future<void> loadAgentMeta() async {
    final projectId = _projectId;
    if (projectId == null) return;
    final session = await _getAgentSession(projectId);
    if (session.isFailure) return;
    final runs = await _getAgentRuns(projectId);
    if (runs.isFailure || isClosed) return;
    emit(
      state.copyWith(
        agentSession: session.valueOrNull,
        clearAgentSession: session.valueOrNull == null,
        agentRuns: runs.valueOrNull,
      ),
    );
  }

  /// Borra la sesión guardada; el siguiente prompt abrirá una conversación nueva.
  Future<Result<void>> resetAgentSession() async {
    final projectId = _projectId;
    if (projectId == null) return const Success(null);
    final result = await _resetAgentSession(projectId);
    if (result.isSuccess && !isClosed) {
      emit(
        state.copyWith(
          clearAgentSession: true,
          continueSession: false,
          forceNewSession: true,
        ),
      );
    }
    return result;
  }

  /// Crea las tareas nuevas del borrador. Devuelve cuántas se crearon.
  Future<Result<int>> applyNewTasks() async {
    final projectId = _projectId;
    if (_mode != ProjectAiChatMode.existing ||
        projectId == null ||
        state.isApplying) {
      return const Success(0);
    }
    emit(state.copyWith(isApplying: true));
    final draft = state.draftTasks;
    final result = await _applyAiTaskSuggestions(
      ApplyAiTaskSuggestionsParams(
        projectId: projectId,
        draft: draft,
        baseline: state.baseline,
      ),
    );
    if (isClosed) return result;
    emit(
      state.copyWith(
        isApplying: false,
        baseline: result.isSuccess ? List<AiTaskSuggestion>.from(draft) : null,
      ),
    );
    return result;
  }
}
