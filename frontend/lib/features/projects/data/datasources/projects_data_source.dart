import '../../domain/entities/project.dart';
import '../../domain/entities/project_member.dart';
import '../../domain/entities/workspace.dart';

/// Acceso a proyectos, miembros y workspace. Dos implementaciones:
/// `ProjectsApiDataSource` (API TaskBoard) y `ProjectsLocalDataSource` (modo
/// local sin API, donde workspace, IDE y miembros no están disponibles).
abstract class ProjectsDataSource {
  Future<List<Project>> getProjects();
  Future<Project?> getProject(int id);
  Future<Project> createProject(Project project);
  Future<Project> saveProject(Project project);
  Future<void> deleteProject(int id);

  Future<Map<String, dynamic>> previewWorkspaceSnapshot(String path);
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
}
