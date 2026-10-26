import '../../domain/entities/project_member.dart';
import '../../domain/entities/workspace.dart';

/// Lectura del JSON del API (snake_case) para miembros, usuarios y workspace.
class ProjectsApiJson {
  const ProjectsApiJson._();

  static ProjectMember member(Map<String, dynamic> m) => ProjectMember(
    projectId: (m['project_id'] as num).toInt(),
    userId: m['user_id'].toString(),
    role: projectMemberRoleFromDb(m['role'] as String),
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  /// Null si falta el id o el email.
  static AppUser? user(Map<String, dynamic> m) {
    final id = (m['user_id'] ?? m['userId'] ?? '').toString();
    final email = (m['email'] ?? '').toString();
    if (id.isEmpty || email.isEmpty) return null;
    return AppUser(id: id, email: email);
  }

  static WorkspaceSuggestion suggestion(Map<String, dynamic> m) {
    final payloadRaw = m['payload'];
    return WorkspaceSuggestion(
      id: (m['id'] as num).toInt(),
      projectId: (m['project_id'] as num).toInt(),
      snapshotId: (m['snapshot_id'] as num?)?.toInt(),
      suggestionType: m['suggestion_type'] as String? ?? 'info',
      title: m['title'] as String? ?? '',
      body: m['body'] as String? ?? '',
      payload: payloadRaw is Map
          ? Map<String, dynamic>.from(payloadRaw)
          : const <String, dynamic>{},
      state: m['state'] as String? ?? 'pending',
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  static IdePrompt idePrompt(Map<String, dynamic> json) {
    final countsRaw = json['task_counts'] ?? json['taskCounts'];
    final counts = <String, int>{};
    if (countsRaw is Map) {
      countsRaw.forEach((k, v) {
        if (v is num) counts[k.toString()] = v.toInt();
      });
    }
    final refs = json['file_references'] ?? json['fileReferences'];
    return IdePrompt(
      projectId: (json['project_id'] as num).toInt(),
      projectTitle: json['project_title'] as String? ?? '',
      workspacePath: json['workspace_path'] as String? ?? '',
      taskboardMd: json['taskboard_md'] as String? ?? 'TASKBOARD.md',
      statusMdPaths:
          (json['status_md_paths'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      fileReferences: refs is List
          ? refs.map((e) => e.toString()).toList()
          : [],
      focusTaskId: (json['focus_task_id'] as num?)?.toInt(),
      focusTaskTitle: json['focus_task_title'] as String?,
      prompt: json['prompt'] as String? ?? '',
      taskCounts: counts,
    );
  }

  static WorkspaceInventory inventory(Map<String, dynamic> json) {
    List<Map<String, dynamic>> maps(dynamic raw) => raw is List
        ? raw.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const [];
    return WorkspaceInventory(
      entries: maps(json['entries'])
          .map(
            (e) => WorkspaceInventoryEntry(
              path: e['path'] as String? ?? '',
              name: e['name'] as String? ?? '',
              root: e['root'] as String? ?? '',
              rootPath: e['root_path'] as String? ?? '',
              hasGit: e['has_git'] as bool? ?? false,
              hasDockerCompose: e['has_docker_compose'] as bool? ?? false,
              linkedProjectId: (e['linked_project_id'] as num?)?.toInt(),
              linkedProjectTitle: e['linked_project_title'] as String?,
            ),
          )
          .toList(),
      orphanProjects: maps(json['orphan_projects'])
          .map(
            (o) => WorkspaceOrphanProject(
              projectId: (o['project_id'] as num).toInt(),
              projectTitle: o['project_title'] as String? ?? '',
              workspacePath: o['workspace_path'] as String? ?? '',
            ),
          )
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      linked: (json['linked'] as num?)?.toInt() ?? 0,
      unlinked: (json['unlinked'] as num?)?.toInt() ?? 0,
    );
  }
}
