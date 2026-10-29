import 'dart:convert';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/taskboard_api_client.dart';
import '../../domain/entities/agent_session.dart';
import '../../domain/entities/ai_chat.dart';
import '../../domain/entities/ai_task_suggestion.dart';
import '../models/agent_session_model.dart';
import '../models/ai_task_suggestion_model.dart';

/// Llamadas a `/api/ai/*` y a la sesión/historial de Claude Code.
/// Los errores HTTP se lanzan como [ServerException] con el cuerpo de la
/// respuesta, del que la UI extrae el `detail` de FastAPI.
abstract class AiAssistantRemoteDataSource {
  Future<AiSuggestionResult> suggest(Map<String, dynamic> payload);
  Future<AiChatReply> chat(Map<String, dynamic> payload);
  Stream<AgentStreamEvent> streamAgentRun(Map<String, dynamic> payload);
  Future<AgentSession?> getAgentSession(int projectId);
  Future<void> resetAgentSession(int projectId);
  Future<List<AgentRun>> getAgentRuns(int projectId, {int limit = 30});
}

class AiAssistantRemoteDataSourceImpl implements AiAssistantRemoteDataSource {
  AiAssistantRemoteDataSourceImpl(this._client);

  final TaskboardApiClient _client;

  static const _aiTimeout = Duration(minutes: 25);

  @override
  Future<AiSuggestionResult> suggest(Map<String, dynamic> payload) async {
    final res = await _client.post(
      '/api/ai/suggest',
      body: payload,
      extraHeaders: const {'x-operation-id': 'tb_suggest_v1'},
      timeout: _aiTimeout,
    );
    if (res.statusCode >= 400) {
      throw ServerException(
        'Error IA (${res.statusCode}): ${res.body}',
        statusCode: res.statusCode,
      );
    }
    final data = AiTaskSuggestionModel.asJsonMap(jsonDecode(res.body));
    if (data == null) throw const ServerException('Respuesta IA inválida');

    final tasksRaw = data['tasks'] ?? data['Tasks'];
    if (tasksRaw is! List) {
      throw ServerException(
        'La IA no devolvió la lista tasks. Claves recibidas: ${data.keys.join(", ")}',
      );
    }
    return AiSuggestionResult(
      suggestions: AiTaskSuggestionModel.listFromJson(tasksRaw),
      provider: data['provider']?.toString(),
    );
  }

  @override
  Future<AiChatReply> chat(Map<String, dynamic> payload) async {
    final res = await _client.post(
      '/api/ai/chat',
      body: payload,
      extraHeaders: const {'x-operation-id': 'tb_chat_v1'},
      timeout: _aiTimeout,
    );
    if (res.statusCode >= 400) {
      throw ServerException(
        'Error IA (${res.statusCode}): ${res.body}',
        statusCode: res.statusCode,
      );
    }
    final data = AiTaskSuggestionModel.asJsonMap(jsonDecode(res.body));
    if (data == null) throw const ServerException('Respuesta IA inválida');

    final message = (data['message'] ?? '').toString().trim();
    if (message.isEmpty) {
      throw const ServerException('La IA no devolvió mensaje de respuesta');
    }

    List<AiTaskSuggestion>? tasks;
    final tasksRaw = data['tasks'];
    if (tasksRaw != null) {
      if (tasksRaw is! List) {
        throw const ServerException('Campo tasks inválido en respuesta IA');
      }
      tasks = AiTaskSuggestionModel.listFromJson(tasksRaw);
    }

    return AiChatReply(
      message: message,
      tasks: tasks,
      provider: data['provider']?.toString(),
    );
  }

  @override
  Stream<AgentStreamEvent> streamAgentRun(Map<String, dynamic> payload) async* {
    await for (final raw in _client.postSseStream(
      '/api/ai/agent-stream',
      body: payload,
    )) {
      final kind = (raw['kind'] ?? '').toString();
      if (kind == 'end') break;
      yield AgentStreamEvent(
        kind: kind,
        text: (raw['text'] ?? '').toString(),
        sessionId: raw['session_id']?.toString(),
      );
    }
  }

  @override
  Future<AgentSession?> getAgentSession(int projectId) async {
    final res = await _client.get('/api/projects/$projectId/agent-session');
    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ServerException(
        'Sesión agent (${res.statusCode}): ${res.body}',
        statusCode: res.statusCode,
      );
    }
    final body = res.body.trim();
    if (body.isEmpty || body == 'null') return null;
    final decoded = jsonDecode(body);
    if (decoded == null) return null;
    return AgentSessionModel.fromJson(
      Map<String, dynamic>.from(decoded as Map),
    );
  }

  @override
  Future<void> resetAgentSession(int projectId) async {
    final res = await _client.delete('/api/projects/$projectId/agent-session');
    if (res.statusCode != 204 &&
        (res.statusCode < 200 || res.statusCode >= 300)) {
      throw ServerException(
        'Reset sesión (${res.statusCode}): ${res.body}',
        statusCode: res.statusCode,
      );
    }
  }

  @override
  Future<List<AgentRun>> getAgentRuns(int projectId, {int limit = 30}) async {
    final res = await _client.get(
      '/api/projects/$projectId/agent-runs?limit=$limit',
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ServerException(
        'Historial agent (${res.statusCode}): ${res.body}',
        statusCode: res.statusCode,
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => AgentRunModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
