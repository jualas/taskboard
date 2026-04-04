// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_member.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProjectMember _$ProjectMemberFromJson(Map<String, dynamic> json) =>
    ProjectMember(
      projectId: (json['projectId'] as num).toInt(),
      userId: json['userId'] as String,
      role: $enumDecode(_$ProjectMemberRoleEnumMap, json['role']),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$ProjectMemberToJson(ProjectMember instance) =>
    <String, dynamic>{
      'projectId': instance.projectId,
      'userId': instance.userId,
      'role': _$ProjectMemberRoleEnumMap[instance.role]!,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$ProjectMemberRoleEnumMap = {
  ProjectMemberRole.owner: 'owner',
  ProjectMemberRole.editor: 'editor',
  ProjectMemberRole.viewer: 'viewer',
};
