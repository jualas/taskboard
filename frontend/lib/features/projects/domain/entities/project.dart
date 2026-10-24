import 'package:equatable/equatable.dart';

import 'project_member.dart';

enum ProjectStatus { planning, development, completed, archived }

class Project extends Equatable {
  const Project({
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

  bool get canEdit => currentUserRole?.canEdit ?? true;

  factory Project.create({
    required int id,
    required String title,
    String description = '',
    ProjectStatus status = ProjectStatus.planning,
    String? ownerId,
    String workspacePath = '',
  }) {
    final now = DateTime.now();
    return Project(
      id: id,
      title: title,
      description: description,
      status: status,
      ownerId: ownerId,
      workspacePath: workspacePath,
      createdAt: now,
      updatedAt: now,
    );
  }

  Project copyWith({
    int? id,
    String? title,
    String? description,
    ProjectStatus? status,
    String? ownerId,
    ProjectMemberRole? currentUserRole,
    String? workspacePath,
    int? pendingWorkspaceSuggestions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      ownerId: ownerId ?? this.ownerId,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      workspacePath: workspacePath ?? this.workspacePath,
      pendingWorkspaceSuggestions:
          pendingWorkspaceSuggestions ?? this.pendingWorkspaceSuggestions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, title, status, updatedAt];
}

extension ProjectStatusX on ProjectStatus {
  String get displayName => switch (this) {
        ProjectStatus.planning => 'Planificación',
        ProjectStatus.development => 'En Desarrollo',
        ProjectStatus.completed => 'Completado',
        ProjectStatus.archived => 'Archivado',
      };

  String get dbValue => switch (this) {
        ProjectStatus.planning => 'planning',
        ProjectStatus.development => 'development',
        ProjectStatus.completed => 'completed',
        ProjectStatus.archived => 'archived',
      };
}

ProjectStatus projectStatusFromDb(String value) {
  switch (value) {
    case 'development':
      return ProjectStatus.development;
    case 'completed':
      return ProjectStatus.completed;
    case 'archived':
      return ProjectStatus.archived;
    default:
      return ProjectStatus.planning;
  }
}

class ProjectStats extends Equatable {
  const ProjectStats({
    required this.totalTasks,
    required this.completedTasks,
    required this.inProgressTasks,
    required this.pendingTasks,
    required this.totalEstimatedHours,
    required this.completionPercentage,
  });

  final int totalTasks;
  final int completedTasks;
  final int inProgressTasks;
  final int pendingTasks;
  final int totalEstimatedHours;
  final int completionPercentage;

  @override
  List<Object?> get props => [
        totalTasks,
        completedTasks,
        completionPercentage,
      ];
}
