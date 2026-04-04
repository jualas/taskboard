// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Subtask _$SubtaskFromJson(Map<String, dynamic> json) => Subtask(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  isDone: json['isDone'] as bool? ?? false,
);

Map<String, dynamic> _$SubtaskToJson(Subtask instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'isDone': instance.isDone,
};

Task _$TaskFromJson(Map<String, dynamic> json) => Task(
  id: (json['id'] as num).toInt(),
  projectId: (json['projectId'] as num).toInt(),
  title: json['title'] as String,
  description: json['description'] as String,
  status: $enumDecode(_$TaskStatusEnumMap, json['status']),
  dueDate: json['dueDate'] == null
      ? null
      : DateTime.parse(json['dueDate'] as String),
  kanbanPosition: (json['kanbanPosition'] as num).toDouble(),
  estimatedHours: (json['estimatedHours'] as num?)?.toInt(),
  complexity: $enumDecode(_$TaskComplexityEnumMap, json['complexity']),
  tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
  subtasks:
      (json['subtasks'] as List<dynamic>?)
          ?.map((e) => Subtask.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$TaskToJson(Task instance) => <String, dynamic>{
  'id': instance.id,
  'projectId': instance.projectId,
  'title': instance.title,
  'description': instance.description,
  'status': _$TaskStatusEnumMap[instance.status]!,
  'dueDate': instance.dueDate?.toIso8601String(),
  'kanbanPosition': instance.kanbanPosition,
  'estimatedHours': instance.estimatedHours,
  'complexity': _$TaskComplexityEnumMap[instance.complexity]!,
  'tags': instance.tags,
  'subtasks': instance.subtasks,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

const _$TaskStatusEnumMap = {
  TaskStatus.pending: 'pending',
  TaskStatus.inProgress: 'in_progress',
  TaskStatus.completed: 'completed',
};

const _$TaskComplexityEnumMap = {
  TaskComplexity.simple: 'simple',
  TaskComplexity.medium: 'medium',
  TaskComplexity.complex: 'complex',
};
