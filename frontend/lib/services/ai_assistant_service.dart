import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

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
}

/// Resultado de [AiAssistantService.suggestTasks] (incluye qué motor usó el backend).
class AiSuggestTasksResult {
  final List<AiTaskSuggestion> suggestions;
  /// `deepseek` | `local` según el backend, o null si no vino en el JSON.
  final String? provider;

  const AiSuggestTasksResult({required this.suggestions, this.provider});

  String get providerLabel {
    switch (provider) {
      case 'deepseek':
        return 'DeepSeek (nube)';
      case 'local':
        return 'Ollama (local)';
      default:
        return 'IA';
    }
  }
}

enum _AiBackend { supabase, api, disabled }

/// Asistente IA: Supabase Edge, backend FastAPI o desactivado (modo local).
class AiAssistantService {
  AiAssistantService._(this._mode, [this._apiClient]);

  final _AiBackend _mode;
  final TaskboardApiClient? _apiClient;

  static AiAssistantService? _instance;

  static void configureApi(TaskboardApiClient client) {
    _instance = AiAssistantService._(_AiBackend.api, client);
  }

  static void configureSupabase() {
    _instance = AiAssistantService._(_AiBackend.supabase, null);
  }

  static void configureDisabled() {
    _instance = AiAssistantService._(_AiBackend.disabled, null);
  }

  factory AiAssistantService() {
    return _instance ??= AiAssistantService._(_AiBackend.supabase, null);
  }

  /// Mensaje legible cuando [suggestTasks] falla.
  static String describeErrorForUser(Object error) {
    final s = error.toString();
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
      return 'Error 502: fallo al hablar con el proveedor IA (timeout, red o respuesta inesperada). '
          'Si usas Ollama, revisa que esté en marcha; si usas DeepSeek, revisa logs del API.';
    }
    if (s.contains('no disponible en modo local')) {
      return 'La IA no está disponible en modo local sin API. Configura TASKBOARD_API_URL o Supabase.';
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
          'Asistente IA no disponible en modo local sin backend. '
          'Configura Taskboard API o Supabase.',
        );
      case _AiBackend.api:
        return _suggestViaApi(payload);
      case _AiBackend.supabase:
        return _suggestViaSupabase(payload);
    }
  }

  Future<AiSuggestTasksResult> _suggestViaApi(Map<String, dynamic> payload) async {
    final client = _apiClient!;
    final res = await client.post(
      '/api/ai/suggest',
      body: payload,
      extraHeaders: const {'x-operation-id': 'tb_suggest_v1'},
    );
    if (res.statusCode >= 400) {
      throw Exception('Error IA (${res.statusCode}): ${res.body}');
    }
    final data = _asJsonMap(jsonDecode(res.body));
    if (data == null) {
      throw Exception('Respuesta IA inválida');
    }
    return _parseSuggestResponse(data);
  }

  Future<AiSuggestTasksResult> _suggestViaSupabase(Map<String, dynamic> payload) async {
    final response = await Supabase.instance.client.functions.invoke(
      'ai-assistant',
      headers: const {'x-operation-id': 'tb_suggest_v1'},
      body: payload,
    );

    if (response.status >= 400) {
      throw Exception('Error IA (${response.status}): ${response.data}');
    }

    final data = _asJsonMap(response.data);
    if (data == null) {
      throw Exception(
        'Respuesta IA inválida (tipo ${response.data.runtimeType}). '
        '¿Content-Type JSON en la Edge Function?',
      );
    }
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
    final provider = data['provider']?.toString();
    return AiSuggestTasksResult(suggestions: out, provider: provider);
  }

  static Map<String, dynamic>? _asJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }
}
