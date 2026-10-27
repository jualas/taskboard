import '../../../../core/error/exception_to_failure.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/agent_session.dart';
import '../../domain/entities/ai_chat.dart';
import '../../domain/entities/ai_task_suggestion.dart';
import '../../domain/repositories/ai_assistant_repository.dart';
import '../datasources/ai_assistant_remote_data_source.dart';
import '../models/ai_task_suggestion_model.dart';

/// Sin `remote` (no hay API Taskboard configurada) el asistente está
/// desactivado: las consultas fallan con un aviso y la sesión agent queda vacía.
class AiAssistantRepositoryImpl implements AiAssistantRepository {
  AiAssistantRepositoryImpl({AiAssistantRemoteDataSource? remote})
    : _remote = remote;

  final AiAssistantRemoteDataSource? _remote;

  static const _disabled = UnexpectedFailure(
    'Asistente IA no disponible: configura la API Taskboard (URL o proxy en config.json).',
  );

  /// Conserva el texto original del error (código HTTP, `TimeoutException`,
  /// `ClientException`…): la UI lo usa para elegir el mensaje.
  static Failure _toFailure(Object error) => error is AppException
      ? mapExceptionToFailure(error)
      : UnexpectedFailure(error.toString());

  Future<Result<T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Success(await body());
    } catch (e) {
      return ResultFailure(_toFailure(e));
    }
  }

  static Map<String, dynamic> _projectContext(
    String title,
    String description,
  ) => {'title': title, 'description': description};

  @override
  Future<Result<AiSuggestionResult>> suggestTasks({
    required String userMessage,
    required String projectTitle,
    required String projectDescription,
  }) async {
    final remote = _remote;
    if (remote == null) return const ResultFailure(_disabled);
    return _guard(
      () => remote.suggest({
        'userMessage': userMessage,
        'projectContext': _projectContext(projectTitle, projectDescription),
      }),
    );
  }

  @override
  Future<Result<AiSuggestionResult>> suggestProjectPlan({
    required String projectTitle,
    required String projectDescription,
    String userMessage = '',
  }) async {
    final remote = _remote;
    if (remote == null) return const ResultFailure(_disabled);
    return _guard(
      () => remote.suggest({
        'userMessage': userMessage,
        'projectPlan': true,
        'projectContext': _projectContext(projectTitle, projectDescription),
      }),
    );
  }

  @override
  Future<Result<AiChatReply>> chatProjectPlan({
    required String projectTitle,
    required String projectDescription,
    required List<AiChatMessage> messages,
    required List<AiTaskSuggestion> draftTasks,
    int? projectId,
  }) async {
    final remote = _remote;
    if (remote == null) return const ResultFailure(_disabled);
    final payload = <String, dynamic>{
      'projectContext': _projectContext(projectTitle, projectDescription),
      'messages': messages
          .map((m) => {'role': m.role, 'content': m.content})
          .toList(),
      'draftTasks': draftTasks
          .map((t) => AiTaskSuggestionModel(t).toJson())
          .toList(),
    };
    if (projectId != null) {
      payload['projectId'] = projectId;
    }
    return _guard(() => remote.chat(payload));
  }

  @override
  Stream<Result<AgentStreamEvent>> streamAgentRun({
    required String prompt,
    int? projectId,
    String projectTitle = '',
    String projectDescription = '',
    bool execute = false,
    bool continueSession = true,
    bool newSession = false,
  }) async* {
    final remote = _remote;
    if (remote == null) {
      yield const ResultFailure(
        UnexpectedFailure(
          'Claude Code no disponible: configura la API Taskboard.',
        ),
      );
      return;
    }
    final payload = <String, dynamic>{
      'prompt': prompt,
      'execute': execute,
      'continueSession': continueSession,
      'newSession': newSession,
      'projectContext': _projectContext(projectTitle, projectDescription),
    };
    if (projectId != null) {
      payload['projectId'] = projectId;
    }
    try {
      await for (final event in remote.streamAgentRun(payload)) {
        yield Success(event);
      }
    } catch (e) {
      yield ResultFailure(_toFailure(e));
    }
  }

  @override
  Future<Result<AgentSession?>> getAgentSession(int projectId) async {
    final remote = _remote;
    if (remote == null) return const Success(null);
    return _guard(() => remote.getAgentSession(projectId));
  }

  @override
  Future<Result<void>> resetAgentSession(int projectId) async {
    final remote = _remote;
    if (remote == null) {
      return const ResultFailure(UnexpectedFailure('API no disponible'));
    }
    return _guard(() => remote.resetAgentSession(projectId));
  }

  @override
  Future<Result<List<AgentRun>>> getAgentRuns(
    int projectId, {
    int limit = 30,
  }) async {
    final remote = _remote;
    if (remote == null) return const Success([]);
    return _guard(() => remote.getAgentRuns(projectId, limit: limit));
  }
}
