import 'package:equatable/equatable.dart';

import '../../../tasks/domain/entities/task.dart';

/// Tarea propuesta por la IA (aún no creada en el proyecto).
class AiTaskSuggestion extends Equatable {
  const AiTaskSuggestion({
    required this.title,
    required this.description,
    required this.complexity,
    required this.estimatedHours,
    required this.tags,
    required this.subtasks,
  });

  final String title;
  final String description;
  final TaskComplexity complexity;
  final int? estimatedHours;
  final List<String> tags;
  final List<String> subtasks;

  @override
  List<Object?> get props => [
    title,
    description,
    complexity,
    estimatedHours,
    tags,
    subtasks,
  ];
}
