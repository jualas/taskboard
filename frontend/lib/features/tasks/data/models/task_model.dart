import '../../domain/entities/task.dart';

/// DTO de tarea: JSON local (camelCase) con [TaskModel.fromJson] y JSON del API
/// (snake_case) con [TaskModel.fromApiJson].
class SubtaskModel {
  const SubtaskModel({
    required this.id,
    required this.title,
    this.isDone = false,
  });

  final int id;
  final String title;
  final bool isDone;

  factory SubtaskModel.fromJson(Map<String, dynamic> json) => SubtaskModel(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? '',
        isDone: json['isDone'] as bool? ?? json['is_done'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isDone': isDone,
      };

  Subtask toEntity() => Subtask(id: id, title: title, isDone: isDone);

  factory SubtaskModel.fromEntity(Subtask s) =>
      SubtaskModel(id: s.id, title: s.title, isDone: s.isDone);
}

class TaskModel {
  const TaskModel({
    required this.id,
    required this.projectId,
    required this.title,
    required this.description,
    required this.status,
    this.dueDate,
    required this.kanbanPosition,
    this.estimatedHours,
    required this.complexity,
    required this.tags,
    this.subtasks = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int projectId;
  final String title;
  final String description;
  final TaskStatus status;
  final DateTime? dueDate;
  final double kanbanPosition;
  final int? estimatedHours;
  final TaskComplexity complexity;
  final List<String> tags;
  final List<SubtaskModel> subtasks;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final subsRaw = json['subtasks'];
    final subs = <SubtaskModel>[];
    if (subsRaw is List) {
      for (final e in subsRaw) {
        if (e is Map<String, dynamic>) {
          subs.add(SubtaskModel.fromJson(e));
        } else if (e is Map) {
          subs.add(SubtaskModel.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    final tagsRaw = json['tags'];
    final tags = tagsRaw is List
        ? tagsRaw.map((e) => e.toString()).toList()
        : <String>[];

    return TaskModel(
      id: (json['id'] as num).toInt(),
      projectId: (json['projectId'] as num).toInt(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: taskStatusFromDb(json['status'] as String? ?? 'pending'),
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.parse(json['dueDate'] as String),
      kanbanPosition: (json['kanbanPosition'] as num?)?.toDouble() ?? 1.0,
      estimatedHours: (json['estimatedHours'] as num?)?.toInt(),
      complexity: taskComplexityFromDb(
        json['complexity'] as String? ?? 'simple',
      ),
      tags: tags,
      subtasks: subs,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'title': title,
        'description': description,
        'status': status.dbValue,
        'dueDate': dueDate?.toIso8601String(),
        'kanbanPosition': kanbanPosition,
        'estimatedHours': estimatedHours,
        'complexity': complexity.dbValue,
        'tags': tags,
        'subtasks': subtasks.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Task toEntity() => Task(
        id: id,
        projectId: projectId,
        title: title,
        description: description,
        status: status,
        dueDate: dueDate,
        kanbanPosition: kanbanPosition,
        estimatedHours: estimatedHours,
        complexity: complexity,
        tags: List<String>.from(tags),
        subtasks: subtasks.map((s) => s.toEntity()).toList(),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory TaskModel.fromEntity(Task task) => TaskModel(
        id: task.id,
        projectId: task.projectId,
        title: task.title,
        description: task.description,
        status: task.status,
        dueDate: task.dueDate,
        kanbanPosition: task.kanbanPosition,
        estimatedHours: task.estimatedHours,
        complexity: task.complexity,
        tags: List<String>.from(task.tags),
        subtasks:
            task.subtasks.map(SubtaskModel.fromEntity).toList(),
        createdAt: task.createdAt,
        updatedAt: task.updatedAt,
      );

  /// Formato del API (snake_case). Las subtareas aceptan `isDone` o `is_done`.
  factory TaskModel.fromApiJson(Map<String, dynamic> m) {
    final subsRaw = m['subtasks'];
    final tagsRaw = m['tags'];
    return TaskModel.fromJson({
      'id': m['id'],
      'projectId': m['project_id'],
      'title': m['title'],
      'description': m['description'],
      'status': m['status'],
      'dueDate': m['due_date'],
      'kanbanPosition': m['kanban_position'],
      'estimatedHours': m['estimated_hours'],
      'complexity': m['complexity'],
      'tags': tagsRaw is List ? tagsRaw : const <String>[],
      'subtasks': subsRaw is List
          ? subsRaw
              .whereType<Map>()
              .map(
                (e) => {
                  'id': (e['id'] as num?)?.toInt() ?? 0,
                  'title': (e['title'] ?? '').toString(),
                  'isDone': e['isDone'] as bool? ?? e['is_done'] as bool? ?? false,
                },
              )
              .toList()
          : const <Map<String, dynamic>>[],
      'createdAt': m['created_at'],
      'updatedAt': m['updated_at'],
    });
  }

  /// Cuerpo de `PUT /api/tasks` (crea o actualiza por `id`).
  Map<String, dynamic> toApiJson() => {
        'id': id,
        'project_id': projectId,
        'title': title,
        'description': description,
        'status': status.dbValue,
        'due_date': dueDate?.toIso8601String(),
        'kanban_position': kanbanPosition,
        'estimated_hours': estimatedHours,
        'complexity': complexity.dbValue,
        'tags': tags,
        'subtasks': subtasks
            .map(
              (s) => {
                'id': s.id,
                'title': s.title,
                'isDone': s.isDone,
                'is_done': s.isDone,
              },
            )
            .toList(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  TaskModel copyWith({int? id, DateTime? updatedAt}) => TaskModel(
        id: id ?? this.id,
        projectId: projectId,
        title: title,
        description: description,
        status: status,
        dueDate: dueDate,
        kanbanPosition: kanbanPosition,
        estimatedHours: estimatedHours,
        complexity: complexity,
        tags: tags,
        subtasks: subtasks,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
