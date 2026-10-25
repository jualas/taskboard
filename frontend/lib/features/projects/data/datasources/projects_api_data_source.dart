import 'package:http/http.dart' as http;

import '../../../../core/network/api_response.dart';
import '../../../../core/network/taskboard_api_client.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/project_member.dart';
import '../../domain/entities/workspace.dart';
import '../models/project_model.dart';
import '../models/workspace_models.dart';
import 'projects_data_source.dart';

class ProjectsApiDataSource implements ProjectsDataSource {
  ProjectsApiDataSource(this._client);

  final TaskboardApiClient _client;

  Project _project(Map<String, dynamic> m) =>
      ProjectModel.fromApiJson(m).toEntity();

  /// GET o POST que devuelve un objeto JSON.
  Future<Map<String, dynamic>> _map(
    String action,
    Future<http.Response> Function() request,
  ) => guardApiCall(action, () async {
    final res = await request();
    ensureSuccess(res, action);
    return decodeJsonMap(res.body);
  });

  Future<List<Map<String, dynamic>>> _list(String action, String path) =>
      guardApiCall(action, () async {
        final res = await _client.get(path);
        ensureSuccess(res, action);
        return decodeJsonList(res.body);
      });

  Future<void> _noContent(
    String action,
    Future<http.Response> Function() request,
  ) => guardApiCall(action, () async {
    ensureSuccess(await request(), action);
  });

  @override
  Future<List<Project>> getProjects() async =>
      (await _list('Listar proyectos', '/api/projects')).map(_project).toList();

  @override
  Future<Project?> getProject(int id) =>
      guardApiCall('Obtener proyecto', () async {
        final res = await _client.get('/api/projects/$id');
        if (res.statusCode == 404) return null;
        ensureSuccess(res, 'Obtener proyecto');
        return _project(decodeJsonMap(res.body));
      });

  @override
  Future<Project> createProject(Project project) async => _project(
    await _map(
      'Crear proyecto',
      () => _client.post(
        '/api/projects',
        body: ProjectModel.fromEntity(project).toApiJson(),
      ),
    ),
  );

  @override
  Future<Project> saveProject(Project project) async => _project(
    await _map(
      'Guardar proyecto',
      () => _client.patch(
        '/api/projects/${project.id}',
        body: ProjectModel.fromEntity(project).toApiJson(),
      ),
    ),
  );

  @override
  Future<void> deleteProject(int id) => _noContent(
    'Eliminar proyecto',
    () => _client.delete('/api/projects/$id'),
  );

  @override
  Future<Map<String, dynamic>> previewWorkspaceSnapshot(String path) => _map(
    'Vista previa workspace',
    () => _client.post(
      '/api/projects/workspace-snapshot-preview',
      body: {'path': path},
    ),
  );

  @override
  Future<Map<String, dynamic>> getProjectWorkspaceSnapshot(int projectId) =>
      _map(
        'Snapshot workspace',
        () => _client.get('/api/projects/$projectId/workspace-snapshot'),
      );

  @override
  Future<List<WorkspaceSuggestion>> getWorkspaceSuggestions(
    int projectId, {
    String state = 'pending',
  }) async => (await _list(
    'Sugerencias workspace',
    '/api/projects/$projectId/workspace-suggestions?state=$state',
  )).map(ProjectsApiJson.suggestion).toList();

  @override
  Future<Map<String, dynamic>> syncProjectWorkspace(int projectId) => _map(
    'Sync workspace',
    () => _client.post('/api/projects/$projectId/workspace-sync'),
  );

  @override
  Future<Map<String, dynamic>> exportTaskboardMd(
    int projectId, {
    bool dryRun = false,
    String filename = '',
  }) => _map(
    'Export TASKBOARD.md',
    () => _client.post(
      '/api/projects/$projectId/taskboard-md',
      body: {
        'dryRun': dryRun,
        if (filename.trim().isNotEmpty) 'filename': filename.trim(),
      },
    ),
  );

  String _withFocus(String path, int? focusTaskId) =>
      focusTaskId == null ? path : '$path?focus_task_id=$focusTaskId';

  @override
  Future<IdePrompt> getIdePrompt(int projectId, {int? focusTaskId}) async =>
      ProjectsApiJson.idePrompt(
        await _map(
          'Prompt IDE',
          () => _client.get(
            _withFocus('/api/projects/$projectId/ide-prompt', focusTaskId),
          ),
        ),
      );

  @override
  Future<IdePrompt> prepareIdeSession(int projectId, {int? focusTaskId}) async {
    final data = await _map(
      'Sesión IDE',
      () => _client.post(
        _withFocus('/api/projects/$projectId/ide-session', focusTaskId),
        body: {},
      ),
    );
    final promptRaw = data['ide_prompt'] ?? data['idePrompt'];
    if (promptRaw is! Map) {
      throw Exception('Respuesta ide-session inválida');
    }
    return ProjectsApiJson.idePrompt(Map<String, dynamic>.from(promptRaw));
  }

  @override
  Future<Map<String, dynamic>> applyWorkspaceSuggestion(
    int projectId,
    int suggestionId,
  ) => _map(
    'Aplicar sugerencia',
    () => _client.post(
      '/api/projects/$projectId/workspace-suggestions/$suggestionId/apply',
    ),
  );

  @override
  Future<void> dismissWorkspaceSuggestion(
    int projectId,
    int suggestionId,
  ) => _noContent(
    'Descartar sugerencia',
    () => _client.post(
      '/api/projects/$projectId/workspace-suggestions/$suggestionId/dismiss',
    ),
  );

  @override
  Future<WorkspaceInventory> getWorkspaceInventory() async =>
      ProjectsApiJson.inventory(
        await _map(
          'Inventario workspace',
          () => _client.get('/api/projects/workspace-inventory'),
        ),
      );

  @override
  Future<List<AppUser>> getRegisteredUsers() async => (await _list(
    'Usuarios',
    '/api/users',
  )).map(ProjectsApiJson.user).whereType<AppUser>().toList();

  @override
  Future<List<ProjectMember>> getProjectMembers(int projectId) async =>
      (await _list(
        'Miembros',
        '/api/projects/$projectId/members',
      )).map(ProjectsApiJson.member).toList();

  @override
  Future<ProjectMember> addProjectMember({
    required int projectId,
    required String userId,
    required ProjectMemberRole role,
  }) async => ProjectsApiJson.member(
    await _map(
      'Añadir miembro',
      () => _client.post(
        '/api/projects/$projectId/members',
        body: {'user_id': userId, 'role': role.dbValue},
      ),
    ),
  );

  @override
  Future<ProjectMember> updateProjectMemberRole({
    required int projectId,
    required String userId,
    required ProjectMemberRole role,
  }) async => ProjectsApiJson.member(
    await _map(
      'Actualizar rol',
      () => _client.patch(
        '/api/projects/$projectId/members/$userId',
        body: {'role': role.dbValue},
      ),
    ),
  );

  @override
  Future<void> removeProjectMember({
    required int projectId,
    required String userId,
  }) => _noContent(
    'Quitar miembro',
    () => _client.delete('/api/projects/$projectId/members/$userId'),
  );

  @override
  Future<bool> canEditProject(int projectId) async =>
      (await getProject(projectId))?.currentUserRole?.canEdit ?? false;
}
