// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Project _$ProjectFromJson(Map<String, dynamic> json) => Project(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  description: json['description'] as String,
  status: $enumDecode(_$ProjectStatusEnumMap, json['status']),
  ownerId: json['ownerId'] as String?,
  currentUserRole: $enumDecodeNullable(
    _$ProjectMemberRoleEnumMap,
    json['currentUserRole'],
  ),
  workspacePath: json['workspacePath'] as String? ?? '',
  pendingWorkspaceSuggestions: (json['pendingWorkspaceSuggestions'] as num?)?.toInt() ?? 0,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$ProjectToJson(Project instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'description': instance.description,
  'status': _$ProjectStatusEnumMap[instance.status]!,
  'ownerId': instance.ownerId,
  'currentUserRole': _$ProjectMemberRoleEnumMap[instance.currentUserRole],
  'workspacePath': instance.workspacePath,
  'pendingWorkspaceSuggestions': instance.pendingWorkspaceSuggestions,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

const _$ProjectStatusEnumMap = {
  ProjectStatus.planning: 'planning',
  ProjectStatus.development: 'development',
  ProjectStatus.completed: 'completed',
  ProjectStatus.archived: 'archived',
};

const _$ProjectMemberRoleEnumMap = {
  ProjectMemberRole.owner: 'owner',
  ProjectMemberRole.editor: 'editor',
  ProjectMemberRole.viewer: 'viewer',
};
