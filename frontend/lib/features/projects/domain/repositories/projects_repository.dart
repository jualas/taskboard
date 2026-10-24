import '../../../../core/error/result.dart';
import '../entities/project.dart';
import '../entities/project_member.dart';
import '../entities/workspace.dart';

abstract class ProjectCrudRepository {
  Future<Result<List<Project>>> getProjects();
  Future<Result<Project?>> getProject(int id);
  Future<Result<Project>> createProject(Project project);
  Future<Result<Project>> updateProject(Project project);
  Future<Result<void>> deleteProject(int id);
  Future<Result<bool>> canEditProject(int projectId);
}

abstract class ProjectMembersRepository {
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
}

abstract class WorkspaceRepository {
  Future<Result<WorkspacePreview>> previewWorkspaceSnapshot(String path);
  Future<Result<Map<String, dynamic>>> getProjectWorkspaceSnapshot(
    int projectId,
  );
  Future<Result<List<WorkspaceSuggestion>>> getWorkspaceSuggestions(
    int projectId, {
    String state,
  });
  Future<Result<void>> syncProjectWorkspace(int projectId);
  Future<Result<TaskboardExport>> exportTaskboardMd(
    int projectId, {
    bool dryRun,
    String filename,
  });
  Future<Result<void>> applyWorkspaceSuggestion(
    int projectId,
    int suggestionId,
  );
  Future<Result<void>> dismissWorkspaceSuggestion(
    int projectId,
    int suggestionId,
  );
  Future<Result<WorkspaceInventory>> getWorkspaceInventory();
}

abstract class IdeRepository {
  Future<Result<IdePrompt>> getIdePrompt(int projectId, {int? focusTaskId});
  Future<Result<IdePrompt>> prepareIdeSession(int projectId, {int? focusTaskId});
}

/// Fachada: una implementación cubre los cuatro contratos segregados.
abstract class ProjectsRepository
    implements
        ProjectCrudRepository,
        ProjectMembersRepository,
        WorkspaceRepository,
        IdeRepository {}
