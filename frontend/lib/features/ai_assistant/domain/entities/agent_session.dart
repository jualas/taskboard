import 'package:equatable/equatable.dart';

/// Sesión de Claude Code persistida por proyecto.
class AgentSession extends Equatable {
  const AgentSession({
    required this.projectId,
    required this.sessionId,
    this.workspacePath = '',
    required this.updatedAt,
  });

  final int projectId;
  final String sessionId;
  final String workspacePath;
  final DateTime updatedAt;

  String get shortId =>
      sessionId.length > 8 ? sessionId.substring(0, 8) : sessionId;

  @override
  List<Object?> get props => [projectId, sessionId, workspacePath, updatedAt];
}

/// Entrada del historial de ejecuciones agent.
class AgentRun extends Equatable {
  const AgentRun({
    required this.id,
    required this.projectId,
    required this.prompt,
    this.sessionId,
    this.executeMode = false,
    this.resultPreview = '',
    this.isError = false,
    required this.createdAt,
  });

  final int id;
  final int projectId;
  final String? sessionId;
  final String prompt;
  final bool executeMode;
  final String resultPreview;
  final bool isError;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    projectId,
    sessionId,
    prompt,
    executeMode,
    resultPreview,
    isError,
    createdAt,
  ];
}

/// Evento del stream SSE de Claude Code.
class AgentStreamEvent extends Equatable {
  const AgentStreamEvent({required this.kind, this.text = '', this.sessionId});

  final String kind;
  final String text;
  final String? sessionId;

  @override
  List<Object?> get props => [kind, text, sessionId];
}
