import 'dart:convert';

import '../../models/models.dart';
import '../taskboard_data_source.dart';
import 'taskboard_api_client.dart';

/// Persistencia remota vía REST + JWT (backend FastAPI).
class ApiDataSource implements TaskboardDataSource {
  ApiDataSource(this._client);

  final TaskboardApiClient _client;

  Never _httpError(String action, int code, String body) {
    if (code == 401) {
      throw Exception(
        'Sesión no válida o caducada (401). Cierra sesión y vuelve a entrar.',
      );
    }
    if (code == 403) {
      throw Exception('Permiso denegado (403). $action');
    }
    throw Exception('$action (${code}): $body');
  }

  List<dynamic> _decodeList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw Exception('Respuesta no es lista JSON');
    }
    return decoded;
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw Exception('Respuesta no es objeto JSON');
    }
    return Map<String, dynamic>.from(decoded);
  }

  String? _nullableUuid(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  Project _projectFromApi(Map<String, dynamic> m) {
    return Project.fromJson({
      'id': (m['id'] as num).toInt(),
      'title': m['title'] as String? ?? '',
      'description': m['description'] as String? ?? '',
      'status': m['status'] as String,
      'ownerId': _nullableUuid(m['owner_id']),
      'currentUserRole': m['current_user_role'] as String?,
      'workspacePath': m['workspace_path'] as String? ?? '',
      'pendingWorkspaceSuggestions':
          (m['pending_workspace_suggestions'] as num?)?.toInt() ?? 0,
      'createdAt': m['created_at'] as String,
      'updatedAt': m['updated_at'] as String,
    });
  }

  Task _taskFromApi(Map<String, dynamic> m) {
    final subsRaw = m['subtasks'];
    final subs = <Map<String, dynamic>>[];
    if (subsRaw is List) {
      for (final e in subsRaw) {
        if (e is Map) {
          final mm = Map<String, dynamic>.from(e);
          subs.add({
            'id': (mm['id'] as num?)?.toInt() ?? 0,
            'title': (mm['title'] ?? '').toString(),
            'isDone': mm['isDone'] as bool? ?? mm['is_done'] as bool? ?? false,
          });
        }
      }
    }
    final tagsRaw = m['tags'];
    final tags = (tagsRaw is List)
        ? tagsRaw.map((e) => e.toString()).toList()
        : <String>[];
    return Task.fromJson({
      'id': (m['id'] as num).toInt(),
      'projectId': (m['project_id'] as num).toInt(),
      'title': m['title'] as String? ?? '',
      'description': m['description'] as String? ?? '',
      'status': m['status'] as String,
      'dueDate': m['due_date'],
      'kanbanPosition': (m['kanban_position'] as num?)?.toDouble() ?? 1.0,
      'estimatedHours': (m['estimated_hours'] as num?)?.toInt(),
      'complexity': m['complexity'] as String? ?? 'simple',
      'tags': tags,
      'subtasks': subs,
      'createdAt': m['created_at'] as String,
      'updatedAt': m['updated_at'] as String,
    });
  }

  ProjectMember _memberFromApi(Map<String, dynamic> m) {
    return ProjectMember.fromJson({
      'projectId': (m['project_id'] as num).toInt(),
      'userId': m['user_id'].toString(),
      'role': m['role'] as String,
      'createdAt': m['created_at'] as String,
    });
  }

  @override
  Future<List<Project>> getProjects() async {
    final res = await _client.get('/api/projects');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Listar proyectos', res.statusCode, res.body);
    }
    final list = _decodeList(res.body);
    return list
        .whereType<Map>()
        .map((e) => _projectFromApi(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<Project?> getProject(int id) async {
    final res = await _client.get('/api/projects/$id');
    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Obtener proyecto', res.statusCode, res.body);
    }
    return _projectFromApi(_decodeMap(res.body));
  }

  @override
  Future<Project> saveProject(Project project) async {
    final res = await _client.patch(
      '/api/projects/${project.id}',
      body: {
        'title': project.title,
        'description': project.description,
        'status': project.status.dbValue,
        'workspace_path': project.workspacePath,
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Guardar proyecto', res.statusCode, res.body);
    }
    return _projectFromApi(_decodeMap(res.body));
  }

  @override
  Future<Project> createProject(Project project) async {
    final res = await _client.post(
      '/api/projects',
      body: {
        'title': project.title,
        'description': project.description,
        'status': project.status.dbValue,
        'workspace_path': project.workspacePath,
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Crear proyecto', res.statusCode, res.body);
    }
    return _projectFromApi(_decodeMap(res.body));
  }

  Map<String, dynamic> _decodeSnapshot(String body) {
    final map = _decodeMap(body);
    return Map<String, dynamic>.from(map);
  }

  @override
  Future<Map<String, dynamic>> previewWorkspaceSnapshot(String path) async {
    final res = await _client.post(
      '/api/projects/workspace-snapshot-preview',
      body: {'path': path},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Vista previa workspace', res.statusCode, res.body);
    }
    return _decodeSnapshot(res.body);
  }

  @override
  Future<Map<String, dynamic>> getProjectWorkspaceSnapshot(int projectId) async {
    final res = await _client.get('/api/projects/$projectId/workspace-snapshot');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Snapshot workspace', res.statusCode, res.body);
    }
    return _decodeSnapshot(res.body);
  }

  @override
  Future<List<WorkspaceSuggestion>> getWorkspaceSuggestions(
    int projectId, {
    String state = 'pending',
  }) async {
    final res = await _client.get(
      '/api/projects/$projectId/workspace-suggestions?state=$state',
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Sugerencias workspace', res.statusCode, res.body);
    }
    final list = _decodeList(res.body);
    return list
        .whereType<Map>()
        .map((e) => WorkspaceSuggestion.fromApi(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> syncProjectWorkspace(int projectId) async {
    final res = await _client.post('/api/projects/$projectId/workspace-sync');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Sync workspace', res.statusCode, res.body);
    }
    return Map<String, dynamic>.from(_decodeMap(res.body));
  }

  @override
  Future<Map<String, dynamic>> exportTaskboardMd(
    int projectId, {
    bool dryRun = false,
    String filename = '',
  }) async {
    final body = <String, dynamic>{
      'dryRun': dryRun,
      if (filename.trim().isNotEmpty) 'filename': filename.trim(),
    };
    final res = await _client.post(
      '/api/projects/$projectId/taskboard-md',
      body: body,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Export TASKBOARD.md', res.statusCode, res.body);
    }
    return Map<String, dynamic>.from(_decodeMap(res.body));
  }

  @override
  Future<IdePrompt> getIdePrompt(int projectId, {int? focusTaskId}) async {
    var path = '/api/projects/$projectId/ide-prompt';
    if (focusTaskId != null) {
      path += '?focus_task_id=$focusTaskId';
    }
    final res = await _client.get(path);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Prompt IDE', res.statusCode, res.body);
    }
    return IdePrompt.fromJson(Map<String, dynamic>.from(_decodeMap(res.body)));
  }

  @override
  Future<IdePrompt> prepareIdeSession(int projectId, {int? focusTaskId}) async {
    var path = '/api/projects/$projectId/ide-session';
    if (focusTaskId != null) {
      path += '?focus_task_id=$focusTaskId';
    }
    final res = await _client.post(path, body: {});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Sesión IDE', res.statusCode, res.body);
    }
    final data = Map<String, dynamic>.from(_decodeMap(res.body));
    final promptRaw = data['ide_prompt'] ?? data['idePrompt'];
    if (promptRaw is! Map) {
      throw Exception('Respuesta ide-session inválida');
    }
    return IdePrompt.fromJson(Map<String, dynamic>.from(promptRaw));
  }

  @override
  Future<Map<String, dynamic>> applyWorkspaceSuggestion(
    int projectId,
    int suggestionId,
  ) async {
    final res = await _client.post(
      '/api/projects/$projectId/workspace-suggestions/$suggestionId/apply',
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Aplicar sugerencia', res.statusCode, res.body);
    }
    return Map<String, dynamic>.from(_decodeMap(res.body));
  }

  @override
  Future<void> dismissWorkspaceSuggestion(int projectId, int suggestionId) async {
    final res = await _client.post(
      '/api/projects/$projectId/workspace-suggestions/$suggestionId/dismiss',
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Descartar sugerencia', res.statusCode, res.body);
    }
  }

  @override
  Future<WorkspaceInventory> getWorkspaceInventory() async {
    final res = await _client.get('/api/projects/workspace-inventory');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Inventario workspace', res.statusCode, res.body);
    }
    return WorkspaceInventory.fromJson(_decodeMap(res.body));
  }

  @override
  Future<void> deleteProject(int id) async {
    final res = await _client.delete('/api/projects/$id');
    if (res.statusCode != 204 && (res.statusCode < 200 || res.statusCode >= 300)) {
      _httpError('Eliminar proyecto', res.statusCode, res.body);
    }
  }

  @override
  Future<int> getNextProjectId() async {
    final res = await _client.get('/api/meta/next-project-id');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('next-project-id', res.statusCode, res.body);
    }
    final t = res.body.trim();
    final n = int.tryParse(t);
    if (n == null) {
      throw Exception('Respuesta next-project-id inválida: $t');
    }
    return n;
  }

  @override
  Future<List<AppUser>> getRegisteredUsers() async {
    final res = await _client.get('/api/users');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Usuarios', res.statusCode, res.body);
    }
    final list = _decodeList(res.body);
    return list
        .whereType<Map>()
        .map((e) {
          final m = Map<String, dynamic>.from(e);
          return AppUser(
            id: (m['user_id'] ?? m['userId'] ?? '').toString(),
            email: (m['email'] ?? '').toString(),
          );
        })
        .where((u) => u.id.isNotEmpty && u.email.isNotEmpty)
        .toList();
  }

  @override
  Future<List<ProjectMember>> getProjectMembers(int projectId) async {
    final res = await _client.get('/api/projects/$projectId/members');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Miembros', res.statusCode, res.body);
    }
    final list = _decodeList(res.body);
    return list
        .whereType<Map>()
        .map((e) => _memberFromApi(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<ProjectMember> addProjectMember({
    required int projectId,
    required String userId,
    required ProjectMemberRole role,
  }) async {
    final res = await _client.post(
      '/api/projects/$projectId/members',
      body: {'user_id': userId, 'role': role.dbValue},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Añadir miembro', res.statusCode, res.body);
    }
    return _memberFromApi(_decodeMap(res.body));
  }

  @override
  Future<ProjectMember> updateProjectMemberRole({
    required int projectId,
    required String userId,
    required ProjectMemberRole role,
  }) async {
    final res = await _client.patch(
      '/api/projects/$projectId/members/$userId',
      body: {'role': role.dbValue},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Actualizar rol', res.statusCode, res.body);
    }
    return _memberFromApi(_decodeMap(res.body));
  }

  @override
  Future<void> removeProjectMember({
    required int projectId,
    required String userId,
  }) async {
    final res = await _client.delete('/api/projects/$projectId/members/$userId');
    if (res.statusCode != 204 && (res.statusCode < 200 || res.statusCode >= 300)) {
      _httpError('Quitar miembro', res.statusCode, res.body);
    }
  }

  @override
  Future<bool> canEditProject(int projectId) async {
    final p = await getProject(projectId);
    return p?.currentUserRole?.canEdit ?? false;
  }

  @override
  Future<List<Task>> getTasks() async {
    final res = await _client.get('/api/tasks');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Listar tareas', res.statusCode, res.body);
    }
    final list = _decodeList(res.body);
    return list
        .whereType<Map>()
        .map((e) => _taskFromApi(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<Task>> getTasksByProject(int projectId) async {
    final res = await _client.get('/api/tasks/by-project/$projectId');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Tareas del proyecto', res.statusCode, res.body);
    }
    final list = _decodeList(res.body);
    return list
        .whereType<Map>()
        .map((e) => _taskFromApi(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<Task?> getTask(int id) async {
    final res = await _client.get('/api/tasks/$id');
    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Obtener tarea', res.statusCode, res.body);
    }
    return _taskFromApi(_decodeMap(res.body));
  }

  @override
  Future<Task> saveTask(Task task) async {
    final res = await _client.put(
      '/api/tasks',
      body: {
        'id': task.id,
        'project_id': task.projectId,
        'title': task.title,
        'description': task.description,
        'status': task.status.dbValue,
        'due_date': task.dueDate?.toIso8601String(),
        'kanban_position': task.kanbanPosition,
        'estimated_hours': task.estimatedHours,
        'complexity': task.complexity.dbValue,
        'tags': task.tags,
        'subtasks': task.subtasks
            .map(
              (s) => {
                'id': s.id,
                'title': s.title,
                'isDone': s.isDone,
                'is_done': s.isDone,
              },
            )
            .toList(),
        'created_at': task.createdAt.toIso8601String(),
        'updated_at': task.updatedAt.toIso8601String(),
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('Guardar tarea', res.statusCode, res.body);
    }
    return _taskFromApi(_decodeMap(res.body));
  }

  @override
  Future<void> deleteTask(int id) async {
    final res = await _client.delete('/api/tasks/$id');
    if (res.statusCode != 204 && (res.statusCode < 200 || res.statusCode >= 300)) {
      _httpError('Eliminar tarea', res.statusCode, res.body);
    }
  }

  @override
  Future<int> getNextTaskId() async {
    final res = await _client.get('/api/meta/next-task-id');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _httpError('next-task-id', res.statusCode, res.body);
    }
    final t = res.body.trim();
    final n = int.tryParse(t);
    if (n == null) {
      throw Exception('Respuesta next-task-id inválida: $t');
    }
    return n;
  }
}
