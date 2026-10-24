/// Lo que la UI lee de la vista previa de un workspace.
class WorkspacePreview {
  const WorkspacePreview(this.summary);

  final String summary;
}

/// Lo que la UI muestra tras exportar TASKBOARD.md.
class TaskboardExport {
  const TaskboardExport({required this.filePath, required this.taskCountLabel});

  final String filePath;
  final String taskCountLabel;
}

class WorkspaceSuggestion {
  const WorkspaceSuggestion({
    required this.id,
    required this.projectId,
    this.snapshotId,
    required this.suggestionType,
    required this.title,
    this.body = '',
    this.payload = const {},
    this.state = 'pending',
    required this.createdAt,
  });

  final int id;
  final int projectId;
  final int? snapshotId;
  final String suggestionType;
  final String title;
  final String body;
  final Map<String, dynamic> payload;
  final String state;
  final DateTime createdAt;

  bool get isInfo => suggestionType == 'info';
  bool get isProjectStatus => suggestionType == 'project_status';
  bool get isTask => suggestionType == 'task';

  String get typeLabel {
    switch (suggestionType) {
      case 'project_status':
        return 'Estado del proyecto';
      case 'task':
        return 'Tarea sugerida';
      default:
        return 'Información';
    }
  }
}

class IdePrompt {
  const IdePrompt({
    required this.projectId,
    required this.projectTitle,
    required this.workspacePath,
    required this.taskboardMd,
    required this.statusMdPaths,
    required this.fileReferences,
    required this.prompt,
    required this.taskCounts,
    this.focusTaskId,
    this.focusTaskTitle,
  });

  final int projectId;
  final String projectTitle;
  final String workspacePath;
  final String taskboardMd;
  final List<String> statusMdPaths;
  final List<String> fileReferences;
  final int? focusTaskId;
  final String? focusTaskTitle;
  final String prompt;
  final Map<String, int> taskCounts;
}

class AppUser {
  const AppUser({required this.id, required this.email});

  final String id;
  final String email;
}

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
}
