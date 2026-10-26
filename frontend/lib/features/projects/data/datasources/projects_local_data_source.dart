import '../../../../core/storage/storage_service.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/project_member.dart';
import '../../domain/entities/workspace.dart';
import '../models/project_model.dart';
import 'projects_data_source.dart';

/// Proyectos del modo local, en la colección `projects` de [StorageService].
/// Hay un único usuario (`local-user`), propietario de todo; workspace, IDE y
/// miembros devuelven valores vacíos o no están disponibles.
class ProjectsLocalDataSource implements ProjectsDataSource {
  ProjectsLocalDataSource(this._storage);

  static const collection = 'projects';

  /// Colección de tareas: al borrar un proyecto se borran también sus tareas.
  static const tasksCollection = 'tasks';
  static const localUserId = 'local-user';

  final StorageService _storage;

  List<Project> _all() => _storage
      .readCollection(collection)
      .map((m) => ProjectModel.fromJson(m).toEntity())
      .toList();

  Future<void> _write(List<Project> projects) => _storage.writeCollection(
    collection,
    projects.map((p) => ProjectModel.fromEntity(p).toJson()).toList(),
  );

  @override
  Future<List<Project>> getProjects() async => _all();

  @override
  Future<Project?> getProject(int id) async {
    for (final p in _all()) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<Project> createProject(Project project) =>
      saveProject(project.copyWith(id: _storage.nextId(collection)));

  /// Al actualizar se renueva `updatedAt`; uno nuevo queda a nombre del
  /// usuario local como propietario.
  @override
  Future<Project> saveProject(Project project) async {
    final projects = _all();
    final index = projects.indexWhere((p) => p.id == project.id);
    if (index >= 0) {
      projects[index] = project.copyWith(updatedAt: DateTime.now());
    } else {
      projects.add(
        project.copyWith(
          ownerId: project.ownerId ?? localUserId,
          currentUserRole: project.currentUserRole ?? ProjectMemberRole.owner,
        ),
      );
    }
    await _write(projects);
    return project;
  }

  @override
  Future<void> deleteProject(int id) async {
    await _write(_all().where((p) => p.id != id).toList());
    await _storage.writeCollection(
      tasksCollection,
      _storage
          .readCollection(tasksCollection)
          .where((t) => (t['projectId'] as num?)?.toInt() != id)
          .toList(),
    );
  }

  @override
  Future<Map<String, dynamic>> previewWorkspaceSnapshot(String path) async => {
    'configured': path.trim().isNotEmpty,
    'summary': 'Workspace solo disponible con la API Taskboard.',
  };

  @override
  Future<Map<String, dynamic>> getProjectWorkspaceSnapshot(int projectId) =>
      previewWorkspaceSnapshot('');

  @override
  Future<List<WorkspaceSuggestion>> getWorkspaceSuggestions(
    int projectId, {
    String state = 'pending',
  }) async => [];

  @override
  Future<Map<String, dynamic>> syncProjectWorkspace(int projectId) async => {
    'skipped': true,
  };

  @override
  Future<Map<String, dynamic>> exportTaskboardMd(
    int projectId, {
    bool dryRun = false,
    String filename = '',
  }) async => {'skipped': true, 'written': false};

  @override
  Future<IdePrompt> getIdePrompt(int projectId, {int? focusTaskId}) async =>
      throw UnsupportedError('Prompt IDE solo disponible con API Taskboard');

  @override
  Future<IdePrompt> prepareIdeSession(
    int projectId, {
    int? focusTaskId,
  }) async =>
      throw UnsupportedError('Sesión IDE solo disponible con API Taskboard');

  @override
  Future<Map<String, dynamic>> applyWorkspaceSuggestion(
    int projectId,
    int suggestionId,
  ) async => {};

  @override
  Future<void> dismissWorkspaceSuggestion(
    int projectId,
    int suggestionId,
  ) async {}

  @override
  Future<WorkspaceInventory> getWorkspaceInventory() async =>
      const WorkspaceInventory(
        entries: [],
        orphanProjects: [],
        total: 0,
        linked: 0,
        unlinked: 0,
      );

  @override
  Future<List<AppUser>> getRegisteredUsers() async => const [
    AppUser(id: localUserId, email: 'local@taskboard.dev'),
  ];

  @override
  Future<List<ProjectMember>> getProjectMembers(int projectId) async {
    final project = await getProject(projectId);
    if (project == null) return [];
    return [
      ProjectMember(
        projectId: projectId,
        userId: project.ownerId ?? localUserId,
        role: ProjectMemberRole.owner,
        createdAt: project.createdAt,
      ),
    ];
  }

  @override
  Future<ProjectMember> addProjectMember({
    required int projectId,
    required String userId,
    required ProjectMemberRole role,
  }) async => ProjectMember(
    projectId: projectId,
    userId: userId,
    role: role,
    createdAt: DateTime.now(),
  );

  @override
  Future<ProjectMember> updateProjectMemberRole({
    required int projectId,
    required String userId,
    required ProjectMemberRole role,
  }) => addProjectMember(projectId: projectId, userId: userId, role: role);

  @override
  Future<void> removeProjectMember({
    required int projectId,
    required String userId,
  }) async {}

  @override
  Future<bool> canEditProject(int projectId) async => true;
}
