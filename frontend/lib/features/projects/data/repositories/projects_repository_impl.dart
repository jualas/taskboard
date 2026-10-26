import '../../../../core/error/exception_to_failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/project_member.dart';
import '../../domain/entities/workspace.dart';
import '../../domain/repositories/projects_repository.dart';
import '../datasources/projects_data_source.dart';

class ProjectsRepositoryImpl implements ProjectsRepository {
  ProjectsRepositoryImpl(this._dataSource);

  final ProjectsDataSource _dataSource;

  @override
  Future<Result<List<Project>>> getProjects() async {
    try {
      return Success(await _dataSource.getProjects());
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<Project?>> getProject(int id) async {
    try {
      return Success(await _dataSource.getProject(id));
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<Project>> createProject(Project project) async {
    try {
      return Success(await _dataSource.createProject(project));
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<Project>> updateProject(Project project) async {
    try {
      return Success(await _dataSource.saveProject(project));
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<void>> deleteProject(int id) async {
    try {
      await _dataSource.deleteProject(id);
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
      final raw = await _dataSource.previewWorkspaceSnapshot(path);
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
      return Success(await _dataSource.getProjectWorkspaceSnapshot(projectId));
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
        await _dataSource.getWorkspaceSuggestions(projectId, state: state),
      );
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<void>> syncProjectWorkspace(int projectId) async {
    try {
      await _dataSource.syncProjectWorkspace(projectId);
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
      final raw = await _dataSource.exportTaskboardMd(
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
        await _dataSource.getIdePrompt(projectId, focusTaskId: focusTaskId),
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
        await _dataSource.prepareIdeSession(projectId, focusTaskId: focusTaskId),
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
      await _dataSource.applyWorkspaceSuggestion(projectId, suggestionId);
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
      await _dataSource.dismissWorkspaceSuggestion(projectId, suggestionId);
      return const Success(null);
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<WorkspaceInventory>> getWorkspaceInventory() async {
    try {
      return Success(await _dataSource.getWorkspaceInventory());
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<List<AppUser>>> getRegisteredUsers() async {
    try {
      return Success(await _dataSource.getRegisteredUsers());
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<List<ProjectMember>>> getProjectMembers(int projectId) async {
    try {
      return Success(await _dataSource.getProjectMembers(projectId));
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
        await _dataSource.addProjectMember(
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
        await _dataSource.updateProjectMemberRole(
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
      await _dataSource.removeProjectMember(projectId: projectId, userId: userId);
      return const Success(null);
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<bool>> canEditProject(int projectId) async {
    try {
      return Success(await _dataSource.canEditProject(projectId));
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }
}
