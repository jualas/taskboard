import 'dart:convert';

import '../models/models.dart';
import 'api/taskboard_api_client.dart';

class AiTaskSuggestion {
  final String title;
  final String description;
  final TaskComplexity complexity;
  final int? estimatedHours;
  final List<String> tags;
  final List<String> subtasks;

  const AiTaskSuggestion({
    required this.title,
    required this.description,
    required this.complexity,
    required this.estimatedHours,
    required this.tags,
    required this.subtasks,
  });

  factory AiTaskSuggestion.fromJson(Map<String, dynamic> json) {
    dynamic raw(String a, String b) => json[a] ?? json[b];

    TaskComplexity parseComplexity(dynamic value) {
      switch ((value ?? '').toString().toLowerCase()) {
        case 'simple':
        case 'sencilla':
          return TaskComplexity.simple;
        case 'complex':
        case 'compleja':
          return TaskComplexity.complex;
        default:
          return TaskComplexity.medium;
      }
    }

    final tagsRaw = raw('tags', 'Tags');
    final tags = (tagsRaw is List)
        ? tagsRaw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];

    dynamic subtasksRaw =
        raw('subtasks', 'sub_tasks') ?? json['checklist'] ?? json['checklistItems'];
    if (subtasksRaw == null && json['acceptanceCriteria'] is List) {
      subtasksRaw = json['acceptanceCriteria'];
    }
    final subtasks = (subtasksRaw is List)
        ? subtasksRaw
            .map((e) {
              if (e is Map<String, dynamic>) {
                return (e['title'] ?? e['text'] ?? e['item'] ?? '')
                    .toString()
                    .trim();
              }
              return e.toString().trim();
            })
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];

    final estimatedHoursValue = raw('estimatedHours', 'estimated_hours');
    final estimatedHours = estimatedHoursValue is num
        ? estimatedHoursValue.toInt()
        : int.tryParse(estimatedHoursValue?.toString() ?? '');

    return AiTaskSuggestion(
      title: (raw('title', 'Title') ?? '').toString().trim(),
      description: (raw('description', 'Description') ?? '').toString().trim(),
      complexity: parseComplexity(raw('complexity', 'Complexity')),
      estimatedHours: estimatedHours,
      tags: tags,
      subtasks: subtasks,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'complexity': complexity.name,
        'estimatedHours': estimatedHours,
        'tags': tags,
        'subtasks': subtasks,
      };
}

class AiChatMessage {
  final String role;
  final String content;

  const AiChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class AiChatResult {
  final String message;
  final List<AiTaskSuggestion>? tasks;
  final String? provider;

  const AiChatResult({
    required this.message,
    required this.tasks,
    this.provider,
  });

  String get providerLabel {
    switch (provider) {
      case 'cursor_agent':
        return 'Cursor Agent';
      case 'deepseek':
        return 'DeepSeek (nube)';
      case 'local':
        return 'Ollama (local)';
      default:
        return 'IA';
    }
  }
}

/// Evento del stream SSE del CLI Cursor Agent.
class AiAgentStreamEvent {
  const AiAgentStreamEvent({
    required this.kind,
    this.text = '',
    this.sessionId,
  });

  final String kind;
  final String text;
  final String? sessionId;
}

enum _AiBackend { api, disabled }

class AiSuggestTasksResult {
  final List<AiTaskSuggestion> suggestions;
  final String? provider;

  const AiSuggestTasksResult({required this.suggestions, this.provider});

  String get providerLabel {
    switch (provider) {
      case 'cursor_agent':
        return 'Cursor Agent';
      case 'deepseek':
        return 'DeepSeek (nube)';
      case 'local':
        return 'Ollama (local)';
      default:
        return 'IA';
    }
  }
}

class AiAssistantService {
  AiAssistantService._(this._mode, [this._apiClient]);

  final _AiBackend _mode;
  final TaskboardApiClient? _apiClient;

  static AiAssistantService? _instance;

  static void configureApi(TaskboardApiClient client) {
    _instance = AiAssistantService._(_AiBackend.api, client);
  }

  static void configureDisabled() {
    _instance = AiAssistantService._(_AiBackend.disabled, null);
  }

  factory AiAssistantService() {
    return _instance ??= AiAssistantService._(_AiBackend.disabled, null);
  }

  static String? fastApiDetailFromErrorString(String errorString) {
    final i = errorString.indexOf('{');
    if (i < 0) return null;
    try {
      final map = jsonDecode(errorString.substring(i)) as Map<String, dynamic>?;
      if (map == null) return null;
      final d = map['detail'];
      if (d is String && d.trim().isNotEmpty) return d.trim();
    } catch (_) {}
    return null;
  }

  static String describeErrorForUser(Object error) {
    final s = error.toString();
    if (s.contains('504') || s.contains('Gateway Timeout')) {
      final detail = fastApiDetailFromErrorString(s);
      if (detail != null) return detail;
      return 'Cursor Agent tardó demasiado. Divide la petición o inténtalo de nuevo.';
    }
    if (s.contains('TimeoutException') || s.contains('timed out')) {
      return 'La consulta al Cursor Agent tardó demasiado. '
          'Prueba un mensaje más corto o divide la petición (p. ej. primero alinear tareas, luego repo). '
          'Las peticiones complejas pueden tardar varios minutos.';
    }
    if (s.contains('Failed to fetch') ||
        s.contains('Failed to execute fetch') ||
        s.contains('ClientException') ||
        s.contains('XMLHttpRequest error') ||
        s.contains('NetworkError')) {
      return 'No se pudo llamar a la función IA: fallo de red o respuesta inválida. '
          'Comprueba la URL del API, proxy mismo-origen y CORS.';
    }
    if (s.contains('CORS') || s.contains('Access-Control-Allow-Origin')) {
      return 'CORS: el API no autoriza este origen. Revisa el proxy o cabeceras del servidor.';
    }
    if (s.contains('402') ||
        s.contains('Insufficient Balance') ||
        s.contains('saldo insuficiente')) {
      return 'DeepSeek: la cuenta no tiene saldo o créditos. Recarga en https://platform.deepseek.com/';
    }
    if (s.contains('502')) {
      final detail = fastApiDetailFromErrorString(s);
      if (detail != null) return detail;
      if (s.contains('Authentication required') || s.contains('agent login')) {
        return 'Cursor Agent: sesión no válida en el servidor. '
            'Define CURSOR_API_KEY en el .env del API o ejecuta agent login en el mini PC.';
      }
      return 'Error 502: fallo al hablar con el proveedor IA. Revisa logs del contenedor taskboard-api.';
    }
    if (s.contains('no disponible en modo local')) {
      return 'La IA no está disponible sin API Taskboard. Configura TASKBOARD_API_URL o taskboardApi en config.json.';
    }
    return 'No se pudo generar sugerencia IA: $error';
  }

  Future<AiSuggestTasksResult> suggestTasks({
    required String userMessage,
    required String projectTitle,
    required String projectDescription,
  }) async {
    final payload = {
      'userMessage': userMessage,
      'projectContext': {
        'title': projectTitle,
        'description': projectDescription,
      },
    };

    switch (_mode) {
      case _AiBackend.disabled:
        throw Exception(
          'Asistente IA no disponible: configura la API Taskboard (URL o proxy en config.json).',
        );
      case _AiBackend.api:
        return _suggestViaApi(payload);
    }
  }

  Future<AiSuggestTasksResult> suggestProjectPlan({
    required String projectTitle,
    required String projectDescription,
    String userMessage = '',
  }) async {
    final payload = {
      'userMessage': userMessage.trim(),
      'projectPlan': true,
      'projectContext': {
        'title': projectTitle,
        'description': projectDescription,
      },
    };

    switch (_mode) {
      case _AiBackend.disabled:
        throw Exception(
          'Asistente IA no disponible: configura la API Taskboard (URL o proxy en config.json).',
        );
      case _AiBackend.api:
        return _suggestViaApi(payload);
    }
  }

  Future<AiChatResult> chatProjectPlan({
    required String projectTitle,
    required String projectDescription,
    required List<AiChatMessage> messages,
    required List<AiTaskSuggestion> draftTasks,
    int? projectId,
  }) async {
    final payload = {
      'projectContext': {
        'title': projectTitle,
        'description': projectDescription,
      },
      'messages': messages.map((m) => m.toJson()).toList(),
      'draftTasks': draftTasks.map((t) => t.toJson()).toList(),
    };
    if (projectId != null) {
      payload['projectId'] = projectId;
    }

    switch (_mode) {
      case _AiBackend.disabled:
        throw Exception(
          'Asistente IA no disponible: configura la API Taskboard (URL o proxy en config.json).',
        );
      case _AiBackend.api:
        return _chatViaApi(payload);
    }
  }

  Future<AiChatResult> _chatViaApi(Map<String, dynamic> payload) async {
    final client = _apiClient!;
    final res = await client.post(
      '/api/ai/chat',
      body: payload,
      extraHeaders: const {'x-operation-id': 'tb_chat_v1'},
      timeout: const Duration(minutes: 25),
    );
    if (res.statusCode >= 400) {
      throw Exception('Error IA (${res.statusCode}): ${res.body}');
    }
    final data = _asJsonMap(jsonDecode(res.body));
    if (data == null) throw Exception('Respuesta IA inválida');

    final message = (data['message'] ?? '').toString().trim();
    if (message.isEmpty) {
      throw Exception('La IA no devolvió mensaje de respuesta');
    }

    List<AiTaskSuggestion>? tasks;
    final tasksRaw = data['tasks'];
    if (tasksRaw != null) {
      if (tasksRaw is! List) {
        throw Exception('Campo tasks inválido en respuesta IA');
      }
      tasks = <AiTaskSuggestion>[];
      for (final item in tasksRaw) {
        final m = _asJsonMap(item);
        if (m == null) continue;
        try {
          final s = AiTaskSuggestion.fromJson(m);
          if (s.title.isNotEmpty) tasks.add(s);
        } catch (_) {}
      }
    }

    return AiChatResult(
      message: message,
      tasks: tasks,
      provider: data['provider']?.toString(),
    );
  }

  /// Stream en vivo del CLI `agent` (terminal integrado en el asistente).
  Stream<AiAgentStreamEvent> streamAgentRun({
    required String prompt,
    int? projectId,
    String projectTitle = '',
    String projectDescription = '',
    bool execute = false,
    bool continueSession = true,
    bool newSession = false,
  }) async* {
    if (_mode != _AiBackend.api || _apiClient == null) {
      throw Exception(
        'Cursor Agent no disponible: configura la API Taskboard.',
      );
    }
    final payload = <String, dynamic>{
      'prompt': prompt,
      'execute': execute,
      'continueSession': continueSession,
      'newSession': newSession,
      'projectContext': {
        'title': projectTitle,
        'description': projectDescription,
      },
    };
    if (projectId != null) {
      payload['projectId'] = projectId;
    }

    await for (final raw in _apiClient.postSseStream(
      '/api/ai/agent-stream',
      body: payload,
    )) {
      final kind = (raw['kind'] ?? '').toString();
      if (kind == 'end') break;
      yield AiAgentStreamEvent(
        kind: kind,
        text: (raw['text'] ?? '').toString(),
        sessionId: raw['session_id']?.toString(),
      );
    }
  }

  Future<AgentSession?> getAgentSession(int projectId) async {
    if (_mode != _AiBackend.api || _apiClient == null) return null;
    final res = await _apiClient.get('/api/projects/$projectId/agent-session');
    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Sesión agent (${res.statusCode}): ${res.body}');
    }
    final body = res.body.trim();
    if (body.isEmpty || body == 'null') return null;
    final decoded = jsonDecode(body);
    if (decoded == null) return null;
    return AgentSession.fromJson(Map<String, dynamic>.from(decoded as Map));
  }

  Future<void> resetAgentSession(int projectId) async {
    if (_mode != _AiBackend.api || _apiClient == null) {
      throw Exception('API no disponible');
    }
    final res = await _apiClient.delete('/api/projects/$projectId/agent-session');
    if (res.statusCode != 204 && (res.statusCode < 200 || res.statusCode >= 300)) {
      throw Exception('Reset sesión (${res.statusCode}): ${res.body}');
    }
  }

  Future<List<AgentRun>> getAgentRuns(int projectId, {int limit = 30}) async {
    if (_mode != _AiBackend.api || _apiClient == null) return [];
    final res = await _apiClient.get(
      '/api/projects/$projectId/agent-runs?limit=$limit',
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Historial agent (${res.statusCode}): ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => AgentRun.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<AiSuggestTasksResult> _suggestViaApi(Map<String, dynamic> payload) async {
    final client = _apiClient!;
    final res = await client.post(
      '/api/ai/suggest',
      body: payload,
      extraHeaders: const {'x-operation-id': 'tb_suggest_v1'},
      timeout: const Duration(minutes: 25),
    );
    if (res.statusCode >= 400) {
      throw Exception('Error IA (${res.statusCode}): ${res.body}');
    }
    final data = _asJsonMap(jsonDecode(res.body));
    if (data == null) throw Exception('Respuesta IA inválida');
    return _parseSuggestResponse(data);
  }

  AiSuggestTasksResult _parseSuggestResponse(Map<String, dynamic> data) {
    final tasksRaw = data['tasks'] ?? data['Tasks'];
    if (tasksRaw is! List) {
      throw Exception(
        'La IA no devolvió la lista tasks. Claves recibidas: ${data.keys.join(", ")}',
      );
    }

    final out = <AiTaskSuggestion>[];
    for (final item in tasksRaw) {
      final m = _asJsonMap(item);
      if (m == null) continue;
      try {
        final s = AiTaskSuggestion.fromJson(m);
        if (s.title.isNotEmpty) out.add(s);
      } catch (_) {}
    }
    return AiSuggestTasksResult(
      suggestions: out,
      provider: data['provider']?.toString(),
    );
  }

  static Map<String, dynamic>? _asJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }
}
