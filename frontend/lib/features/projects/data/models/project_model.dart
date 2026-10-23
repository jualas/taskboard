import '../../domain/entities/project.dart';
import '../../domain/entities/project_member.dart';

class ProjectModel {
  const ProjectModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    this.ownerId,
    this.currentUserRole,
    this.workspacePath = '',
    this.pendingWorkspaceSuggestions = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String description;
  final ProjectStatus status;
  final String? ownerId;
  final ProjectMemberRole? currentUserRole;
  final String workspacePath;
  final int pendingWorkspaceSuggestions;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    final roleRaw = json['currentUserRole'] as String?;
    return ProjectModel(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: projectStatusFromDb(json['status'] as String? ?? 'planning'),
      ownerId: json['ownerId'] as String?,
      currentUserRole:
          roleRaw == null ? null : projectMemberRoleFromDb(roleRaw),
      workspacePath: json['workspacePath'] as String? ?? '',
      pendingWorkspaceSuggestions:
          (json['pendingWorkspaceSuggestions'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'status': status.dbValue,
        'ownerId': ownerId,
        'currentUserRole': currentUserRole?.dbValue,
        'workspacePath': workspacePath,
        'pendingWorkspaceSuggestions': pendingWorkspaceSuggestions,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Project toEntity() => Project(
        id: id,
        title: title,
        description: description,
        status: status,
        ownerId: ownerId,
        currentUserRole: currentUserRole,
        workspacePath: workspacePath,
        pendingWorkspaceSuggestions: pendingWorkspaceSuggestions,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory ProjectModel.fromEntity(Project p) => ProjectModel(
        id: p.id,
        title: p.title,
        description: p.description,
        status: p.status,
        ownerId: p.ownerId,
        currentUserRole: p.currentUserRole,
        workspacePath: p.workspacePath,
        pendingWorkspaceSuggestions: p.pendingWorkspaceSuggestions,
        createdAt: p.createdAt,
        updatedAt: p.updatedAt,
      );
}
