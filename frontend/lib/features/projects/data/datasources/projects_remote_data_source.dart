import '../../../../core/error/exception_to_failure.dart';
import '../../../../models/ide_prompt.dart' as legacy_ide;
import '../../../../models/project.dart' as legacy_project;
import '../../../../models/project_member.dart' as legacy_member;
import '../../../../models/workspace_inventory.dart' as legacy_inv;
import '../../../../models/workspace_suggestion.dart' as legacy_ws;
import '../../../../services/taskboard_data_source.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/project_member.dart';
import '../../domain/entities/workspace.dart';
import '../models/project_model.dart';

abstract class ProjectsRemoteDataSource {
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

class ProjectsRemoteDataSourceImpl implements ProjectsRemoteDataSource {
  ProjectsRemoteDataSourceImpl(this._dataSource);

  final TaskboardDataSource _dataSource;

  Project _projectFromLegacy(legacy_project.Project p) =>
      ProjectModel.fromJson(p.toJson()).toEntity();

  legacy_project.Project _projectToLegacy(Project p) =>
      legacy_project.Project.fromJson(ProjectModel.fromEntity(p).toJson());

  ProjectMember _memberFromLegacy(legacy_member.ProjectMember m) =>
      ProjectMember(
        projectId: m.projectId,
        userId: m.userId,
        role: projectMemberRoleFromDb(m.role.dbValue),
        createdAt: m.createdAt,
      );

  legacy_member.ProjectMemberRole _memberRoleToLegacy(ProjectMemberRole r) {
    switch (r) {
      case ProjectMemberRole.owner:
        return legacy_member.ProjectMemberRole.owner;
      case ProjectMemberRole.viewer:
        return legacy_member.ProjectMemberRole.viewer;
      case ProjectMemberRole.editor:
        return legacy_member.ProjectMemberRole.editor;
    }
  }

  WorkspaceSuggestion _suggestionFromLegacy(legacy_ws.WorkspaceSuggestion s) =>
      WorkspaceSuggestion(
        id: s.id,
        projectId: s.projectId,
        snapshotId: s.snapshotId,
        suggestionType: s.suggestionType,
        title: s.title,
        body: s.body,
        payload: Map<String, dynamic>.from(s.payload),
        state: s.state,
        createdAt: s.createdAt,
      );

  IdePrompt _ideFromLegacy(legacy_ide.IdePrompt p) => IdePrompt(
        projectId: p.projectId,
        projectTitle: p.projectTitle,
        workspacePath: p.workspacePath,
        taskboardMd: p.taskboardMd,
        statusMdPaths: List<String>.from(p.statusMdPaths),
        fileReferences: List<String>.from(p.fileReferences),
        prompt: p.prompt,
        taskCounts: Map<String, int>.from(p.taskCounts),
        focusTaskId: p.focusTaskId,
        focusTaskTitle: p.focusTaskTitle,
      );

  WorkspaceInventory _inventoryFromLegacy(legacy_inv.WorkspaceInventory inv) =>
      WorkspaceInventory(
        entries: inv.entries
            .map(
              (e) => WorkspaceInventoryEntry(
                path: e.path,
                name: e.name,
                root: e.root,
                rootPath: e.rootPath,
                hasGit: e.hasGit,
                hasDockerCompose: e.hasDockerCompose,
                linkedProjectId: e.linkedProjectId,
                linkedProjectTitle: e.linkedProjectTitle,
              ),
            )
            .toList(),
        orphanProjects: inv.orphanProjects
            .map(
              (o) => WorkspaceOrphanProject(
                projectId: o.projectId,
                projectTitle: o.projectTitle,
                workspacePath: o.workspacePath,
              ),
            )
            .toList(),
        total: inv.total,
        linked: inv.linked,
        unlinked: inv.unlinked,
      );

  @override
  Future<List<Project>> getProjects() async {
    try {
      final list = await _dataSource.getProjects();
      return list.map(_projectFromLegacy).toList();
    } catch (e) {
      rethrowAsAppException(e, context: 'getProjects');
    }
  }

  @override
  Future<Project?> getProject(int id) async {
    try {
      final p = await _dataSource.getProject(id);
      return p == null ? null : _projectFromLegacy(p);
    } catch (e) {
      rethrowAsAppException(e, context: 'getProject');
    }
  }

  @override
  Future<Project> createProject(Project project) async {
    try {
      final saved = await _dataSource.createProject(_projectToLegacy(project));
      return _projectFromLegacy(saved);
    } catch (e) {
      rethrowAsAppException(e, context: 'createProject');
    }
  }

  @override
  Future<Project> saveProject(Project project) async {
    try {
      final saved = await _dataSource.saveProject(_projectToLegacy(project));
      return _projectFromLegacy(saved);
    } catch (e) {
      rethrowAsAppException(e, context: 'saveProject');
    }
  }

  @override
  Future<void> deleteProject(int id) async {
    try {
      await _dataSource.deleteProject(id);
    } catch (e) {
      rethrowAsAppException(e, context: 'deleteProject');
    }
  }

  @override
  Future<Map<String, dynamic>> previewWorkspaceSnapshot(String path) async {
    try {
      return await _dataSource.previewWorkspaceSnapshot(path);
    } catch (e) {
      rethrowAsAppException(e, context: 'previewWorkspaceSnapshot');
    }
  }

  @override
  Future<Map<String, dynamic>> getProjectWorkspaceSnapshot(int projectId) async {
    try {
      return await _dataSource.getProjectWorkspaceSnapshot(projectId);
    } catch (e) {
      rethrowAsAppException(e, context: 'getProjectWorkspaceSnapshot');
    }
  }

  @override
  Future<List<WorkspaceSuggestion>> getWorkspaceSuggestions(
    int projectId, {
    String state = 'pending',
  }) async {
    try {
      final list =
          await _dataSource.getWorkspaceSuggestions(projectId, state: state);
      return list.map(_suggestionFromLegacy).toList();
    } catch (e) {
      rethrowAsAppException(e, context: 'getWorkspaceSuggestions');
    }
  }

  @override
  Future<Map<String, dynamic>> syncProjectWorkspace(int projectId) async {
    try {
      return await _dataSource.syncProjectWorkspace(projectId);
    } catch (e) {
      rethrowAsAppException(e, context: 'syncProjectWorkspace');
    }
  }

  @override
  Future<Map<String, dynamic>> exportTaskboardMd(
    int projectId, {
    bool dryRun = false,
    String filename = '',
  }) async {
    try {
      return await _dataSource.exportTaskboardMd(
        projectId,
        dryRun: dryRun,
        filename: filename,
      );
    } catch (e) {
      rethrowAsAppException(e, context: 'exportTaskboardMd');
    }
  }

  @override
  Future<IdePrompt> getIdePrompt(int projectId, {int? focusTaskId}) async {
    try {
      return _ideFromLegacy(
        await _dataSource.getIdePrompt(projectId, focusTaskId: focusTaskId),
      );
    } catch (e) {
      rethrowAsAppException(e, context: 'getIdePrompt');
    }
  }

  @override
  Future<IdePrompt> prepareIdeSession(int projectId, {int? focusTaskId}) async {
    try {
      return _ideFromLegacy(
        await _dataSource.prepareIdeSession(
          projectId,
          focusTaskId: focusTaskId,
        ),
      );
    } catch (e) {
      rethrowAsAppException(e, context: 'prepareIdeSession');
    }
  }

  @override
  Future<Map<String, dynamic>> applyWorkspaceSuggestion(
    int projectId,
    int suggestionId,
  ) async {
    try {
      return await _dataSource.applyWorkspaceSuggestion(
        projectId,
        suggestionId,
      );
    } catch (e) {
      rethrowAsAppException(e, context: 'applyWorkspaceSuggestion');
    }
  }

  @override
  Future<void> dismissWorkspaceSuggestion(
    int projectId,
    int suggestionId,
  ) async {
    try {
      await _dataSource.dismissWorkspaceSuggestion(projectId, suggestionId);
    } catch (e) {
      rethrowAsAppException(e, context: 'dismissWorkspaceSuggestion');
    }
  }

  @override
  Future<WorkspaceInventory> getWorkspaceInventory() async {
    try {
      return _inventoryFromLegacy(await _dataSource.getWorkspaceInventory());
    } catch (e) {
      rethrowAsAppException(e, context: 'getWorkspaceInventory');
    }
  }

  @override
  Future<List<AppUser>> getRegisteredUsers() async {
    try {
      final users = await _dataSource.getRegisteredUsers();
      return users
          .map((u) => AppUser(id: u.id, email: u.email))
          .toList();
    } catch (e) {
      rethrowAsAppException(e, context: 'getRegisteredUsers');
    }
  }

  @override
  Future<List<ProjectMember>> getProjectMembers(int projectId) async {
    try {
      final list = await _dataSource.getProjectMembers(projectId);
      return list.map(_memberFromLegacy).toList();
    } catch (e) {
      rethrowAsAppException(e, context: 'getProjectMembers');
    }
  }

  @override
  Future<ProjectMember> addProjectMember({
    required int projectId,
    required String userId,
    required ProjectMemberRole role,
  }) async {
    try {
      final m = await _dataSource.addProjectMember(
        projectId: projectId,
        userId: userId,
        role: _memberRoleToLegacy(role),
      );
      return _memberFromLegacy(m);
    } catch (e) {
      rethrowAsAppException(e, context: 'addProjectMember');
    }
  }

  @override
  Future<ProjectMember> updateProjectMemberRole({
    required int projectId,
    required String userId,
    required ProjectMemberRole role,
  }) async {
    try {
      final m = await _dataSource.updateProjectMemberRole(
        projectId: projectId,
        userId: userId,
        role: _memberRoleToLegacy(role),
      );
      return _memberFromLegacy(m);
    } catch (e) {
      rethrowAsAppException(e, context: 'updateProjectMemberRole');
    }
  }

  @override
  Future<void> removeProjectMember({
    required int projectId,
    required String userId,
  }) async {
    try {
      await _dataSource.removeProjectMember(
        projectId: projectId,
        userId: userId,
      );
    } catch (e) {
      rethrowAsAppException(e, context: 'removeProjectMember');
    }
  }

  @override
  Future<bool> canEditProject(int projectId) async {
    try {
      return await _dataSource.canEditProject(projectId);
    } catch (e) {
      rethrowAsAppException(e, context: 'canEditProject');
    }
  }
}
