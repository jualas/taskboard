import 'package:equatable/equatable.dart';

enum TaskStatus { pending, inProgress, completed }

enum TaskComplexity { simple, medium, complex }

class Subtask extends Equatable {
  const Subtask({
    required this.id,
    required this.title,
    this.isDone = false,
  });

  final int id;
  final String title;
  final bool isDone;

  Subtask copyWith({int? id, String? title, bool? isDone}) {
    return Subtask(
      id: id ?? this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
    );
  }

  @override
  List<Object?> get props => [id, title, isDone];
}

class Task extends Equatable {
  const Task({
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
  final List<Subtask> subtasks;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasSubtasks => subtasks.isNotEmpty;
  int get subtasksTotalCount => subtasks.length;
  int get subtasksDoneCount => subtasks.where((s) => s.isDone).length;

  factory Task.create({
    required int id,
    required int projectId,
    required String title,
    String description = '',
    TaskStatus status = TaskStatus.pending,
    DateTime? dueDate,
    double kanbanPosition = 1.0,
    int? estimatedHours,
    TaskComplexity complexity = TaskComplexity.simple,
    List<String> tags = const [],
    List<Subtask> subtasks = const [],
  }) {
    final now = DateTime.now();
    return Task(
      id: id,
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
      createdAt: now,
      updatedAt: now,
    );
  }

  Task copyWith({
    int? id,
    int? projectId,
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? dueDate,
    double? kanbanPosition,
    int? estimatedHours,
    TaskComplexity? complexity,
    List<String>? tags,
    List<Subtask>? subtasks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      kanbanPosition: kanbanPosition ?? this.kanbanPosition,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      complexity: complexity ?? this.complexity,
      tags: tags ?? this.tags,
      subtasks: subtasks ?? this.subtasks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        projectId,
        title,
        description,
        status,
        dueDate,
        kanbanPosition,
        estimatedHours,
        complexity,
        tags,
        subtasks,
        createdAt,
        updatedAt,
      ];
}

extension TaskStatusX on TaskStatus {
  bool get isCompleted => this == TaskStatus.completed;
  bool get isInProgress => this == TaskStatus.inProgress;
  bool get isPending => this == TaskStatus.pending;

  String get dbValue => switch (this) {
        TaskStatus.pending => 'pending',
        TaskStatus.inProgress => 'in_progress',
        TaskStatus.completed => 'completed',
      };

  String get displayName => switch (this) {
        TaskStatus.pending => 'Pendiente',
        TaskStatus.inProgress => 'En Progreso',
        TaskStatus.completed => 'Completada',
      };
}

extension TaskComplexityX on TaskComplexity {
  String get dbValue => switch (this) {
        TaskComplexity.simple => 'simple',
        TaskComplexity.medium => 'medium',
        TaskComplexity.complex => 'complex',
      };

  String get displayName => switch (this) {
        TaskComplexity.simple => 'Simple',
        TaskComplexity.medium => 'Media',
        TaskComplexity.complex => 'Compleja',
      };
}

TaskStatus taskStatusFromDb(String value) {
  switch (value) {
    case 'in_progress':
      return TaskStatus.inProgress;
    case 'completed':
      return TaskStatus.completed;
    default:
      return TaskStatus.pending;
  }
}

TaskComplexity taskComplexityFromDb(String value) {
  switch (value) {
    case 'medium':
      return TaskComplexity.medium;
    case 'complex':
      return TaskComplexity.complex;
    default:
      return TaskComplexity.simple;
  }
}
