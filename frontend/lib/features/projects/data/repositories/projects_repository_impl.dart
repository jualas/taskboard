import '../../../../core/error/exception_to_failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/project_member.dart';
import '../../domain/entities/workspace.dart';
import '../../domain/repositories/projects_repository.dart';
import '../datasources/projects_remote_data_source.dart';

class ProjectsRepositoryImpl implements ProjectsRepository {
  ProjectsRepositoryImpl(this._remote);

  final ProjectsRemoteDataSource _remote;

  @override
  Future<Result<List<Project>>> getProjects() async {
    try {
      return Success(await _remote.getProjects());
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<Project?>> getProject(int id) async {
    try {
      return Success(await _remote.getProject(id));
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<Project>> createProject(Project project) async {
    try {
      return Success(await _remote.createProject(project));
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<Project>> updateProject(Project project) async {
    try {
      return Success(await _remote.saveProject(project));
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<void>> deleteProject(int id) async {
    try {
      await _remote.deleteProject(id);
      return const Success(null);
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<WorkspacePreview>> previewWorkspaceSnapshot(
    String path,
  ) async {
    try {
      final raw = await _remote.previewWorkspaceSnapshot(path);
      return Success(
        WorkspacePreview((raw['summary'] ?? '').toString().trim()),
      );
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> getProjectWorkspaceSnapshot(
    int projectId,
  ) async {
    try {
      return Success(await _remote.getProjectWorkspaceSnapshot(projectId));
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<List<WorkspaceSuggestion>>> getWorkspaceSuggestions(
    int projectId, {
    String state = 'pending',
  }) async {
    try {
      return Success(
        await _remote.getWorkspaceSuggestions(projectId, state: state),
      );
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<void>> syncProjectWorkspace(int projectId) async {
    try {
      await _remote.syncProjectWorkspace(projectId);
      return const Success(null);
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<TaskboardExport>> exportTaskboardMd(
    int projectId, {
    bool dryRun = false,
    String filename = '',
  }) async {
    try {
      final raw = await _remote.exportTaskboardMd(
        projectId,
        dryRun: dryRun,
        filename: filename,
      );
      final path = (raw['file_path'] ?? raw['filePath'] ?? '').toString();
      final count = raw['task_count'] ?? raw['taskCount'] ?? '?';
      return Success(
        TaskboardExport(filePath: path, taskCountLabel: count.toString()),
      );
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<IdePrompt>> getIdePrompt(int projectId, {int? focusTaskId}) async {
    try {
      return Success(
        await _remote.getIdePrompt(projectId, focusTaskId: focusTaskId),
      );
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<IdePrompt>> prepareIdeSession(
    int projectId, {
    int? focusTaskId,
  }) async {
    try {
      return Success(
        await _remote.prepareIdeSession(projectId, focusTaskId: focusTaskId),
      );
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<void>> applyWorkspaceSuggestion(
    int projectId,
    int suggestionId,
  ) async {
    try {
      await _remote.applyWorkspaceSuggestion(projectId, suggestionId);
      return const Success(null);
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<void>> dismissWorkspaceSuggestion(
    int projectId,
    int suggestionId,
  ) async {
    try {
      await _remote.dismissWorkspaceSuggestion(projectId, suggestionId);
      return const Success(null);
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<WorkspaceInventory>> getWorkspaceInventory() async {
    try {
      return Success(await _remote.getWorkspaceInventory());
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<List<AppUser>>> getRegisteredUsers() async {
    try {
      return Success(await _remote.getRegisteredUsers());
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<List<ProjectMember>>> getProjectMembers(int projectId) async {
    try {
      return Success(await _remote.getProjectMembers(projectId));
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<ProjectMember>> addProjectMember({
    required int projectId,
    required String userId,
    required ProjectMemberRole role,
  }) async {
    try {
      return Success(
        await _remote.addProjectMember(
          projectId: projectId,
          userId: userId,
          role: role,
        ),
      );
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<ProjectMember>> updateProjectMemberRole({
    required int projectId,
    required String userId,
    required ProjectMemberRole role,
  }) async {
    try {
      return Success(
        await _remote.updateProjectMemberRole(
          projectId: projectId,
          userId: userId,
          role: role,
        ),
      );
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<void>> removeProjectMember({
    required int projectId,
    required String userId,
  }) async {
    try {
      await _remote.removeProjectMember(projectId: projectId, userId: userId);
      return const Success(null);
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<bool>> canEditProject(int projectId) async {
    try {
      return Success(await _remote.canEditProject(projectId));
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }
}
