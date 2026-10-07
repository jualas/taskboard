import '../models/models.dart';

/// Contrato de persistencia para la app (local o remoto).
abstract class TaskboardDataSource {
  Future<List<Project>> getProjects();
  Future<Project?> getProject(int id);
  Future<Project> saveProject(Project project);

  /// Solo INSERT en remoto (evita upsert que podría hacer UPDATE de un id ajeno).
  Future<Project> createProject(Project project);

  Future<void> deleteProject(int id);
  Future<int> getNextProjectId();

  /// Vista previa del snapshot de una ruta (solo API remota).
  Future<Map<String, dynamic>> previewWorkspaceSnapshot(String path);

  /// Snapshot del workspace vinculado a un proyecto (solo API remota).
  Future<Map<String, dynamic>> getProjectWorkspaceSnapshot(int projectId);

  Future<List<WorkspaceSuggestion>> getWorkspaceSuggestions(
    int projectId, {
    String state = 'pending',
  });

  Future<Map<String, dynamic>> syncProjectWorkspace(int projectId);

  Future<Map<String, dynamic>> exportTaskboardMd(
    int projectId, {
    bool dryRun = false,
    String filename = '',
  });

  Future<IdePrompt> getIdePrompt(int projectId, {int? focusTaskId});

  Future<IdePrompt> prepareIdeSession(int projectId, {int? focusTaskId});

  Future<Map<String, dynamic>> applyWorkspaceSuggestion(
    int projectId,
    int suggestionId,
  );

  Future<void> dismissWorkspaceSuggestion(int projectId, int suggestionId);

  Future<WorkspaceInventory> getWorkspaceInventory();

  Future<List<AppUser>> getRegisteredUsers();
  Future<List<ProjectMember>> getProjectMembers(int projectId);
  Future<ProjectMember> addProjectMember({
    required int projectId,
    required String userId,
    required ProjectMemberRole role,
  });
  Future<ProjectMember> updateProjectMemberRole({
    required int projectId,
    required String userId,
    required ProjectMemberRole role,
  });
  Future<void> removeProjectMember({
    required int projectId,
    required String userId,
  });
  Future<bool> canEditProject(int projectId);

  Future<List<Task>> getTasks();
  Future<List<Task>> getTasksByProject(int projectId);
  Future<Task?> getTask(int id);
  Future<Task> saveTask(Task task);
  Future<void> deleteTask(int id);
  Future<int> getNextTaskId();
}

