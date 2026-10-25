import '../../domain/entities/agent_session.dart';

class AgentSessionModel {
  const AgentSessionModel._();

  static AgentSession fromJson(Map<String, dynamic> json) {
    return AgentSession(
      projectId: (json['project_id'] as num).toInt(),
      sessionId: json['session_id'] as String? ?? '',
      workspacePath: json['workspace_path'] as String? ?? '',
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class AgentRunModel {
  const AgentRunModel._();

  static AgentRun fromJson(Map<String, dynamic> json) {
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
