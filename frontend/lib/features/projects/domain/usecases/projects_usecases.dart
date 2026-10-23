import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/project.dart';
import '../entities/project_member.dart';
import '../entities/workspace.dart';
import '../repositories/projects_repository.dart';

class GetProjects implements UseCase<List<Project>, NoParams> {
  GetProjects(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<List<Project>>> call(NoParams params) => _repo.getProjects();
}

class GetProject implements UseCase<Project?, int> {
  GetProject(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<Project?>> call(int id) => _repo.getProject(id);
}

class CreateProject implements UseCase<Project, CreateProjectParams> {
  CreateProject(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<Project>> call(CreateProjectParams p) => _repo.createProject(
        title: p.title,
        description: p.description,
        status: p.status,
        workspacePath: p.workspacePath,
      );
}

class CreateProjectParams {
  const CreateProjectParams({
    required this.title,
    this.description = '',
    this.status = ProjectStatus.planning,
    this.workspacePath = '',
  });
  final String title;
  final String description;
  final ProjectStatus status;
  final String workspacePath;
}

class UpdateProject implements UseCase<Project, Project> {
  UpdateProject(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<Project>> call(Project p) => _repo.updateProject(p);
}

class DeleteProject implements UseCase<void, int> {
  DeleteProject(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<void>> call(int id) => _repo.deleteProject(id);
}

class UpdateProjectStatus implements UseCase<Project, UpdateProjectStatusParams> {
  UpdateProjectStatus(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<Project>> call(UpdateProjectStatusParams p) =>
      _repo.updateProjectStatus(p.id, p.status);
}

class UpdateProjectStatusParams {
  const UpdateProjectStatusParams({required this.id, required this.status});
  final int id;
  final ProjectStatus status;
}

class PreviewWorkspaceSnapshot
    implements UseCase<Map<String, dynamic>, String> {
  PreviewWorkspaceSnapshot(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<Map<String, dynamic>>> call(String path) =>
      _repo.previewWorkspaceSnapshot(path);
}

class GetWorkspaceSuggestions
    implements UseCase<List<WorkspaceSuggestion>, WorkspaceSuggestionsParams> {
  GetWorkspaceSuggestions(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<List<WorkspaceSuggestion>>> call(WorkspaceSuggestionsParams p) =>
      _repo.getWorkspaceSuggestions(p.projectId, state: p.state);
}

class WorkspaceSuggestionsParams {
  const WorkspaceSuggestionsParams(this.projectId, {this.state = 'pending'});
  final int projectId;
  final String state;
}

class ApplyWorkspaceSuggestion
    implements UseCase<Map<String, dynamic>, SuggestionActionParams> {
  ApplyWorkspaceSuggestion(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<Map<String, dynamic>>> call(SuggestionActionParams p) =>
      _repo.applyWorkspaceSuggestion(p.projectId, p.suggestionId);
}

class DismissWorkspaceSuggestion implements UseCase<void, SuggestionActionParams> {
  DismissWorkspaceSuggestion(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<void>> call(SuggestionActionParams p) =>
      _repo.dismissWorkspaceSuggestion(p.projectId, p.suggestionId);
}

class SuggestionActionParams {
  const SuggestionActionParams({
    required this.projectId,
    required this.suggestionId,
  });
  final int projectId;
  final int suggestionId;
}

class SyncProjectWorkspace implements UseCase<Map<String, dynamic>, int> {
  SyncProjectWorkspace(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<Map<String, dynamic>>> call(int projectId) =>
      _repo.syncProjectWorkspace(projectId);
}

class GetWorkspaceInventory implements UseCase<WorkspaceInventory, NoParams> {
  GetWorkspaceInventory(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<WorkspaceInventory>> call(NoParams params) =>
      _repo.getWorkspaceInventory();
}

class ExportTaskboardMd implements UseCase<Map<String, dynamic>, ExportTaskboardMdParams> {
  ExportTaskboardMd(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<Map<String, dynamic>>> call(ExportTaskboardMdParams p) =>
      _repo.exportTaskboardMd(
        p.projectId,
        dryRun: p.dryRun,
        filename: p.filename,
      );
}

class ExportTaskboardMdParams {
  const ExportTaskboardMdParams({
    required this.projectId,
    this.dryRun = false,
    this.filename = '',
  });
  final int projectId;
  final bool dryRun;
  final String filename;
}

class PrepareIdeSession implements UseCase<IdePrompt, PrepareIdeSessionParams> {
  PrepareIdeSession(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<IdePrompt>> call(PrepareIdeSessionParams p) =>
      _repo.prepareIdeSession(p.projectId, focusTaskId: p.focusTaskId);
}

class PrepareIdeSessionParams {
  const PrepareIdeSessionParams({required this.projectId, this.focusTaskId});
  final int projectId;
  final int? focusTaskId;
}

class GetProjectMembers implements UseCase<List<ProjectMember>, int> {
  GetProjectMembers(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<List<ProjectMember>>> call(int projectId) =>
      _repo.getProjectMembers(projectId);
}

class GetRegisteredUsers implements UseCase<List<AppUser>, NoParams> {
  GetRegisteredUsers(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<List<AppUser>>> call(NoParams params) =>
      _repo.getRegisteredUsers();
}

class AddProjectMember implements UseCase<ProjectMember, MemberChangeParams> {
  AddProjectMember(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<ProjectMember>> call(MemberChangeParams p) =>
      _repo.addProjectMember(
        projectId: p.projectId,
        userId: p.userId,
        role: p.role,
      );
}

class UpdateProjectMemberRole
    implements UseCase<ProjectMember, MemberChangeParams> {
  UpdateProjectMemberRole(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<ProjectMember>> call(MemberChangeParams p) =>
      _repo.updateProjectMemberRole(
        projectId: p.projectId,
        userId: p.userId,
        role: p.role,
      );
}

class RemoveProjectMember implements UseCase<void, MemberRemoveParams> {
  RemoveProjectMember(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<void>> call(MemberRemoveParams p) =>
      _repo.removeProjectMember(projectId: p.projectId, userId: p.userId);
}

class MemberChangeParams {
  const MemberChangeParams({
    required this.projectId,
    required this.userId,
    required this.role,
  });
  final int projectId;
  final String userId;
  final ProjectMemberRole role;
}

class MemberRemoveParams {
  const MemberRemoveParams({required this.projectId, required this.userId});
  final int projectId;
  final String userId;
}
