import 'package:json_annotation/json_annotation.dart';

part 'project_member.g.dart';

@JsonSerializable()
class ProjectMember {
  @JsonKey(name: 'projectId')
  final int projectId;
  @JsonKey(name: 'userId')
  final String userId;
  final ProjectMemberRole role;
  @JsonKey(name: 'createdAt')
  final DateTime createdAt;

  const ProjectMember({
    required this.projectId,
    required this.userId,
    required this.role,
    required this.createdAt,
  });

  factory ProjectMember.fromJson(Map<String, dynamic> json) =>
      _$ProjectMemberFromJson(json);
  Map<String, dynamic> toJson() => _$ProjectMemberToJson(this);

  ProjectMember copyWith({
    int? projectId,
    String? userId,
    ProjectMemberRole? role,
    DateTime? createdAt,
  }) {
    return ProjectMember(
      projectId: projectId ?? this.projectId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

enum ProjectMemberRole {
  @JsonValue('owner')
  owner,
  @JsonValue('editor')
  editor,
  @JsonValue('viewer')
  viewer,
}

extension ProjectMemberRoleExtension on ProjectMemberRole {
  String get dbValue {
    switch (this) {
      case ProjectMemberRole.owner:
        return 'owner';
      case ProjectMemberRole.editor:
        return 'editor';
      case ProjectMemberRole.viewer:
        return 'viewer';
    }
  }

  String get displayName {
    switch (this) {
      case ProjectMemberRole.owner:
        return 'Propietario';
      case ProjectMemberRole.editor:
        return 'Editor';
      case ProjectMemberRole.viewer:
        return 'Solo lectura';
    }
  }

  bool get canEdit =>
      this == ProjectMemberRole.owner || this == ProjectMemberRole.editor;
}
