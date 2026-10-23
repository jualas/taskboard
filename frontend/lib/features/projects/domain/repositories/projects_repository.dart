import '../../../../core/error/result.dart';
import '../entities/project.dart';
import '../entities/project_member.dart';
import '../entities/workspace.dart';

abstract class ProjectsRepository {
  Future<Result<List<Project>>> getProjects();
  Future<Result<Project?>> getProject(int id);
  Future<Result<Project>> createProject({
    required String title,
    String description,
    ProjectStatus status,
    String workspacePath,
  });
  Future<Result<Project>> updateProject(Project project);
  Future<Result<void>> deleteProject(int id);
  Future<Result<Project>> updateProjectStatus(int id, ProjectStatus status);

  Future<Result<Map<String, dynamic>>> previewWorkspaceSnapshot(String path);
  Future<Result<Map<String, dynamic>>> getProjectWorkspaceSnapshot(
    int projectId,
  );
  Future<Result<List<WorkspaceSuggestion>>> getWorkspaceSuggestions(
    int projectId, {
    String state,
  });
  Future<Result<Map<String, dynamic>>> syncProjectWorkspace(int projectId);
  Future<Result<Map<String, dynamic>>> exportTaskboardMd(
    int projectId, {
    bool dryRun,
    String filename,
  });
  Future<Result<IdePrompt>> getIdePrompt(int projectId, {int? focusTaskId});
  Future<Result<IdePrompt>> prepareIdeSession(int projectId, {int? focusTaskId});
  Future<Result<Map<String, dynamic>>> applyWorkspaceSuggestion(
    int projectId,
    int suggestionId,
  );
  Future<Result<void>> dismissWorkspaceSuggestion(
    int projectId,
    int suggestionId,
  );
  Future<Result<WorkspaceInventory>> getWorkspaceInventory();
  Future<Result<List<AppUser>>> getRegisteredUsers();
  Future<Result<List<ProjectMember>>> getProjectMembers(int projectId);
  Future<Result<ProjectMember>> addProjectMember({
    required int projectId,
    required String userId,
    required ProjectMemberRole role,
  });
  Future<Result<ProjectMember>> updateProjectMemberRole({
    required int projectId,
    required String userId,
    required ProjectMemberRole role,
  });
  Future<Result<void>> removeProjectMember({
    required int projectId,
    required String userId,
  });
  Future<Result<bool>> canEditProject(int projectId);
}
