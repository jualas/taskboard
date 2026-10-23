import 'package:equatable/equatable.dart';

enum ProjectMemberRole { owner, editor, viewer }

class ProjectMember extends Equatable {
  const ProjectMember({
    required this.projectId,
    required this.userId,
    required this.role,
    required this.createdAt,
  });

  final int projectId;
  final String userId;
  final ProjectMemberRole role;
  final DateTime createdAt;

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

  @override
  List<Object?> get props => [projectId, userId, role];
}

extension ProjectMemberRoleX on ProjectMemberRole {
  String get dbValue => switch (this) {
        ProjectMemberRole.owner => 'owner',
        ProjectMemberRole.editor => 'editor',
        ProjectMemberRole.viewer => 'viewer',
      };

  String get displayName => switch (this) {
        ProjectMemberRole.owner => 'Propietario',
        ProjectMemberRole.editor => 'Editor',
        ProjectMemberRole.viewer => 'Solo lectura',
      };

  bool get canEdit =>
      this == ProjectMemberRole.owner || this == ProjectMemberRole.editor;
}

ProjectMemberRole projectMemberRoleFromDb(String value) {
  switch (value) {
    case 'owner':
      return ProjectMemberRole.owner;
    case 'viewer':
      return ProjectMemberRole.viewer;
    default:
      return ProjectMemberRole.editor;
  }
}
