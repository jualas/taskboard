import 'package:json_annotation/json_annotation.dart';
import 'project_member.dart';

part 'project.g.dart';

/// Modelo que representa un proyecto en el sistema de gestión personal.
@JsonSerializable()
class Project {
  final int id;
  final String title;
  final String description;
  final ProjectStatus status;
  @JsonKey(name: 'ownerId')
  final String? ownerId;
  @JsonKey(name: 'currentUserRole')
  final ProjectMemberRole? currentUserRole;
  @JsonKey(name: 'createdAt')
  final DateTime createdAt;
  @JsonKey(name: 'updatedAt')
  final DateTime updatedAt;

  const Project({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    this.ownerId,
    this.currentUserRole,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);
  Map<String, dynamic> toJson() => _$ProjectToJson(this);

  Project copyWith({
    int? id,
    String? title,
    String? description,
    ProjectStatus? status,
    String? ownerId,
    ProjectMemberRole? currentUserRole,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Crea un nuevo proyecto con valores por defecto
  factory Project.create({
    required int id,
    required String title,
    String description = '',
    ProjectStatus status = ProjectStatus.planning,
    String? ownerId,
  }) {
    final now = DateTime.now();
    return Project(
      id: id,
      title: title,
      description: description,
      status: status,
      ownerId: ownerId,
      createdAt: now,
      updatedAt: now,
    );
  }

  bool get canEdit =>
      currentUserRole?.canEdit ?? true; // En local asumimos edición permitida.

  @override
  String toString() {
    return 'Project(id: $id, title: $title, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Project && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Estados posibles de un proyecto.
enum ProjectStatus {
  @JsonValue('planning')
  planning,
  @JsonValue('development')
  development,
  @JsonValue('completed')
  completed,
  @JsonValue('archived')
  archived,
}

extension ProjectStatusExtension on ProjectStatus {
  String get displayName {
    switch (this) {
      case ProjectStatus.planning:
        return 'Planificación';
      case ProjectStatus.development:
        return 'En Desarrollo';
      case ProjectStatus.completed:
        return 'Completado';
      case ProjectStatus.archived:
        return 'Archivado';
    }
  }

  String get dbValue {
    switch (this) {
      case ProjectStatus.planning:
        return 'planning';
      case ProjectStatus.development:
        return 'development';
      case ProjectStatus.completed:
        return 'completed';
      case ProjectStatus.archived:
        return 'archived';
    }
  }

  bool get isCompleted => this == ProjectStatus.completed;
  bool get isInDevelopment => this == ProjectStatus.development;
  bool get isInPlanning => this == ProjectStatus.planning;
  bool get isArchived => this == ProjectStatus.archived;
}
