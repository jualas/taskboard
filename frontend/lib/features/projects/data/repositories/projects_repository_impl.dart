import '../../../../core/error/exception_to_failure.dart';
import '../../../../core/error/failures.dart';
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
  Future<Result<Project>> createProject({
    required String title,
    String description = '',
    ProjectStatus status = ProjectStatus.planning,
    String workspacePath = '',
  }) async {
    try {
      final project = Project.create(
        id: 0,
        title: title,
        description: description,
        status: status,
        workspacePath: workspacePath,
      );
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
  Future<Result<Project>> updateProjectStatus(int id, ProjectStatus status) async {
    try {
      final current = await _remote.getProject(id);
      if (current == null) {
        return const ResultFailure(NotFoundFailure('Proyecto no encontrado'));
      }
      final updated = current.copyWith(
        status: status,
        updatedAt: DateTime.now(),
      );
      return Success(await _remote.saveProject(updated));
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> previewWorkspaceSnapshot(
    String path,
  ) async {
    try {
      return Success(await _remote.previewWorkspaceSnapshot(path));
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
  Future<Result<Map<String, dynamic>>> syncProjectWorkspace(int projectId) async {
    try {
      return Success(await _remote.syncProjectWorkspace(projectId));
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> exportTaskboardMd(
    int projectId, {
    bool dryRun = false,
    String filename = '',
  }) async {
    try {
      return Success(
        await _remote.exportTaskboardMd(
          projectId,
          dryRun: dryRun,
          filename: filename,
        ),
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
  Future<Result<Map<String, dynamic>>> applyWorkspaceSuggestion(
    int projectId,
    int suggestionId,
  ) async {
    try {
      return Success(
        await _remote.applyWorkspaceSuggestion(projectId, suggestionId),
      );
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
