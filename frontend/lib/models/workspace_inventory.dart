/// Entrada del inventario de carpetas workspace (Fase 4).
class WorkspaceInventoryEntry {
  const WorkspaceInventoryEntry({
    required this.path,
    required this.name,
    required this.root,
    this.rootPath = '',
    this.hasGit = false,
    this.hasDockerCompose = false,
    this.linkedProjectId,
    this.linkedProjectTitle,
  });

  final String path;
  final String name;
  final String root;
  final String rootPath;
  final bool hasGit;
  final bool hasDockerCompose;
  final int? linkedProjectId;
  final String? linkedProjectTitle;

  bool get isLinked => linkedProjectId != null;

  factory WorkspaceInventoryEntry.fromJson(Map<String, dynamic> json) {
    return WorkspaceInventoryEntry(
      path: json['path'] as String? ?? '',
      name: json['name'] as String? ?? '',
      root: json['root'] as String? ?? '',
      rootPath: json['root_path'] as String? ?? '',
      hasGit: json['has_git'] as bool? ?? false,
      hasDockerCompose: json['has_docker_compose'] as bool? ?? false,
      linkedProjectId: (json['linked_project_id'] as num?)?.toInt(),
      linkedProjectTitle: json['linked_project_title'] as String?,
    );
  }
}

class WorkspaceOrphanProject {
  const WorkspaceOrphanProject({
    required this.projectId,
    required this.projectTitle,
    required this.workspacePath,
  });

  final int projectId;
  final String projectTitle;
  final String workspacePath;

  factory WorkspaceOrphanProject.fromJson(Map<String, dynamic> json) {
    return WorkspaceOrphanProject(
      projectId: (json['project_id'] as num).toInt(),
      projectTitle: json['project_title'] as String? ?? '',
      workspacePath: json['workspace_path'] as String? ?? '',
    );
  }
}

class WorkspaceInventory {
  const WorkspaceInventory({
    required this.entries,
    required this.orphanProjects,
    required this.total,
    required this.linked,
    required this.unlinked,
  });

  final List<WorkspaceInventoryEntry> entries;
  final List<WorkspaceOrphanProject> orphanProjects;
  final int total;
  final int linked;
  final int unlinked;

  factory WorkspaceInventory.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    final rawOrphans = json['orphan_projects'];
    return WorkspaceInventory(
      entries: rawEntries is List
          ? rawEntries
              .whereType<Map>()
              .map(
                (e) => WorkspaceInventoryEntry.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : [],
      orphanProjects: rawOrphans is List
          ? rawOrphans
              .whereType<Map>()
              .map(
                (e) => WorkspaceOrphanProject.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : [],
      total: (json['total'] as num?)?.toInt() ?? 0,
      linked: (json['linked'] as num?)?.toInt() ?? 0,
      unlinked: (json['unlinked'] as num?)?.toInt() ?? 0,
    );
  }
}
