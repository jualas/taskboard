/// Sesión Cursor Agent persistida por proyecto.
class AgentSession {
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

  factory AgentSession.fromJson(Map<String, dynamic> json) {
    return AgentSession(
      projectId: (json['project_id'] as num).toInt(),
      sessionId: json['session_id'] as String? ?? '',
      workspacePath: json['workspace_path'] as String? ?? '',
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  String get shortId =>
      sessionId.length > 8 ? sessionId.substring(0, 8) : sessionId;
}

/// Entrada del historial de ejecuciones agent.
class AgentRun {
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

  factory AgentRun.fromJson(Map<String, dynamic> json) {
    return AgentRun(
      id: (json['id'] as num).toInt(),
      projectId: (json['project_id'] as num).toInt(),
      sessionId: json['session_id'] as String?,
      prompt: json['prompt'] as String? ?? '',
      executeMode: json['execute_mode'] as bool? ?? false,
      resultPreview: json['result_preview'] as String? ?? '',
      isError: json['is_error'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
