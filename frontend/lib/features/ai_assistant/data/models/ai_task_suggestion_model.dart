import '../../../tasks/domain/entities/task.dart';
import '../../domain/entities/ai_task_suggestion.dart';

/// DTO de una tarea sugerida. Acepta las variantes de clave que devuelven
/// los distintos modelos (camelCase, snake_case, mayúsculas, checklist…).
class AiTaskSuggestionModel {
  const AiTaskSuggestionModel(this.entity);

  final AiTaskSuggestion entity;

  factory AiTaskSuggestionModel.fromJson(Map<String, dynamic> json) {
    dynamic raw(String a, String b) => json[a] ?? json[b];

    final tagsRaw = raw('tags', 'Tags');
    final tags = (tagsRaw is List)
        ? tagsRaw
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];

    dynamic subtasksRaw =
        raw('subtasks', 'sub_tasks') ??
        json['checklist'] ??
        json['checklistItems'];
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

    return AiTaskSuggestionModel(
      AiTaskSuggestion(
        title: (raw('title', 'Title') ?? '').toString().trim(),
        description: (raw('description', 'Description') ?? '')
            .toString()
            .trim(),
        complexity: _parseComplexity(raw('complexity', 'Complexity')),
        estimatedHours: estimatedHours,
        tags: tags,
        subtasks: subtasks,
      ),
    );
  }

  static TaskComplexity _parseComplexity(dynamic value) {
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

  Map<String, dynamic> toJson() => {
    'title': entity.title,
    'description': entity.description,
    'complexity': entity.complexity.name,
    'estimatedHours': entity.estimatedHours,
    'tags': entity.tags,
    'subtasks': entity.subtasks,
  };

  /// Lista `tasks` de una respuesta IA: descarta elementos que no son objeto,
  /// que no se pueden leer o que no tienen título.
  static List<AiTaskSuggestion> listFromJson(List<dynamic> raw) {
    final out = <AiTaskSuggestion>[];
    for (final item in raw) {
      final m = asJsonMap(item);
      if (m == null) continue;
      try {
        final s = AiTaskSuggestionModel.fromJson(m).entity;
        if (s.title.isNotEmpty) out.add(s);
      } catch (_) {}
    }
    return out;
  }

  static Map<String, dynamic>? asJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }
}
