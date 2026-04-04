import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../taskboard_data_source.dart';

class SupabaseDataSource implements TaskboardDataSource {
  final SupabaseClient _client;

  SupabaseDataSource(this._client);

  static const String _projectsTable = 'projects';
  static const String _tasksTable = 'tasks';
  static const String _projectMembersTable = 'project_members';

  String _requireCurrentUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw Exception('Debes iniciar sesión para operar con proyectos.');
    }
    return userId;
  }

  /// PostgREST usa el JWT de sesión en Authorization; si falta, el SDK envía la anon key
  /// y `auth.uid()` en RLS queda null → error 42501 al insertar en `projects`.
  Future<void> _ensureJwtForRls() async {
    Session? session = _client.auth.currentSession;
    if (session == null) {
      throw Exception(
        'No hay sesión activa. Vuelve a iniciar sesión para usar Supabase.',
      );
    }
    if (session.isExpired) {
      try {
        await _client.auth.refreshSession();
      } catch (_) {
        throw Exception(
          'La sesión ha caducado y no se pudo renovar. Vuelve a iniciar sesión.',
        );
      }
      session = _client.auth.currentSession;
    }
    final token = session?.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception(
        'No hay token de acceso. Cierra sesión y entra de nuevo.',
      );
    }
    final payload = _jwtPayload(token);
    if (payload == null) {
      throw Exception('Token de acceso ilegible. Vuelve a iniciar sesión.');
    }
    final role = payload['role']?.toString();
    if (role != 'authenticated') {
      throw Exception(
        'La sesión no es de un usuario autenticado (rol JWT: $role). '
        'Cierra sesión y entra de nuevo.',
      );
    }
    final sub = payload['sub']?.toString();
    final uid = _client.auth.currentUser?.id;
    if (sub == null ||
        sub.isEmpty ||
        uid == null ||
        uid.isEmpty ||
        sub != uid) {
      throw Exception(
        'El token no coincide con el usuario actual. Cierra sesión y entra de nuevo.',
      );
    }
  }

  Map<String, dynamic>? _jwtPayload(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  Never _mapProjectsRlsError(Object e) {
    final s = e.toString();
    if (s.contains('42501') ||
        s.contains('row-level security') ||
        s.contains('violates row-level security')) {
      throw Exception(
        'Permiso denegado por la base de datos (RLS). Si acabas de entrar y '
        'el JWT es correcto, puede ser un id de proyecto en conflicto con otro '
        'usuario (fallaba el RPC next_project_id). Asegúrate de aplicar las '
        'migraciones SQL en Supabase. Si persiste: cierra sesión y vuelve a '
        'entrar. Detalle: $s',
      );
    }
    if (e is Exception) throw e;
    throw Exception(s);
  }

  ProjectMemberRole? _roleFromDb(String? role) {
    if (role == null) return null;
    for (final value in ProjectMemberRole.values) {
      if (value.dbValue == role) {
        return value;
      }
    }
    return null;
  }

  ProjectMember _projectMemberFromRow(Map<String, dynamic> row) {
    return ProjectMember(
      projectId: (row['project_id'] as num).toInt(),
      userId: (row['user_id'] as String?) ?? '',
      role: _roleFromDb(row['role'] as String?) ?? ProjectMemberRole.viewer,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Future<ProjectMemberRole?> _getCurrentUserRoleForProject({
    required int projectId,
    required String ownerId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return null;
    }
    if (ownerId == userId) {
      return ProjectMemberRole.owner;
    }
    final member = await _client
        .from(_projectMembersTable)
        .select('role')
        .eq('project_id', projectId)
        .eq('user_id', userId)
        .maybeSingle();

    if (member == null) return null;
    return _roleFromDb(member['role'] as String?);
  }

  Future<Project> _projectFromRow(Map<String, dynamic> row) async {
    final statusValue = (row['status'] as String?) ?? ProjectStatus.planning.dbValue;
    final status = ProjectStatus.values.firstWhere(
      (s) => s.dbValue == statusValue,
      orElse: () => ProjectStatus.planning,
    );
    final ownerId = row['owner_id'] as String?;
    final projectId = (row['id'] as num).toInt();
    final currentUserRole = await _getCurrentUserRoleForProject(
      projectId: projectId,
      ownerId: ownerId ?? '',
    );

    return Project(
      id: projectId,
      title: (row['title'] as String?) ?? '',
      description: (row['description'] as String?) ?? '',
      status: status,
      ownerId: ownerId,
      currentUserRole: currentUserRole,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  Map<String, dynamic> _projectToRow(Project project, {required String userId}) {
    final trimmed = project.ownerId?.trim();
    final ownerId = (trimmed != null && trimmed.isNotEmpty) ? trimmed : userId;
    return {
      'id': project.id,
      'title': project.title,
      'description': project.description,
      'status': project.status.dbValue,
      'owner_id': ownerId,
      'created_at': project.createdAt.toIso8601String(),
      'updated_at': project.updatedAt.toIso8601String(),
    };
  }

  Task _taskFromRow(Map<String, dynamic> row) {
    final statusValue = (row['status'] as String?) ?? TaskStatus.pending.dbValue;
    final status = TaskStatus.values.firstWhere(
      (s) => s.dbValue == statusValue,
      orElse: () => TaskStatus.pending,
    );

    final complexityValue =
        (row['complexity'] as String?) ?? TaskComplexity.simple.dbValue;
    final complexity = TaskComplexity.values.firstWhere(
      (c) => c.dbValue == complexityValue,
      orElse: () => TaskComplexity.simple,
    );

    final tagsRaw = row['tags'];
    final tags = (tagsRaw is List)
        ? tagsRaw.map((e) => e.toString()).toList()
        : <String>[];

    final subtasksRaw = row['subtasks'];
    final subtasks = (subtasksRaw is List)
        ? subtasksRaw
            .whereType<Map>()
            .map((e) => Subtask.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <Subtask>[];

    final dueDateRaw = row['due_date'];

    return Task(
      id: (row['id'] as num).toInt(),
      projectId: (row['project_id'] as num).toInt(),
      title: (row['title'] as String?) ?? '',
      description: (row['description'] as String?) ?? '',
      status: status,
      dueDate: dueDateRaw == null ? null : DateTime.parse(dueDateRaw as String),
      kanbanPosition: (row['kanban_position'] as num?)?.toDouble() ?? 1.0,
      estimatedHours: (row['estimated_hours'] as num?)?.toInt(),
      complexity: complexity,
      tags: tags,
      subtasks: subtasks,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  Map<String, dynamic> _taskToRow(Task task) {
    return {
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
      'subtasks': task.subtasks.map((s) => s.toJson()).toList(),
      'created_at': task.createdAt.toIso8601String(),
      'updated_at': task.updatedAt.toIso8601String(),
    };
  }

  @override
  Future<List<Project>> getProjects() async {
    await _ensureJwtForRls();
    final res = await _client.from(_projectsTable).select().order('id');
    final rows = (res as List)
        .whereType<Map>()
        .map((e) => _projectFromRow(Map<String, dynamic>.from(e)))
        .toList();
    return Future.wait(rows);
  }

  @override
  Future<Project?> getProject(int id) async {
    await _ensureJwtForRls();
    final res = await _client
        .from(_projectsTable)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return _projectFromRow(Map<String, dynamic>.from(res));
  }

  @override
  Future<Project> saveProject(Project project) async {
    await _ensureJwtForRls();
    final userId = _requireCurrentUserId();
    final ownerMissing = project.ownerId == null || project.ownerId!.trim().isEmpty;
    final projectToPersist =
        ownerMissing ? project.copyWith(ownerId: userId) : project;
    try {
      final res = await _client
          .from(_projectsTable)
          .upsert(_projectToRow(projectToPersist, userId: userId), onConflict: 'id')
          .select()
          .maybeSingle();
      if (res == null) {
        throw Exception('No se pudo guardar el proyecto');
      }
      return await _projectFromRow(Map<String, dynamic>.from(res));
    } catch (e) {
      _mapProjectsRlsError(e);
    }
  }

  @override
  Future<Project> createProject(Project project) async {
    await _ensureJwtForRls();
    _requireCurrentUserId();
    try {
      final res = await _client.rpc(
        'create_project',
        params: {
          'p_title': project.title,
          'p_description': project.description,
          'p_status': project.status.dbValue,
        },
      );
      if (res == null) {
        throw Exception('No se pudo crear el proyecto');
      }
      final Map<String, dynamic> row;
      if (res is Map) {
        row = Map<String, dynamic>.from(res);
      } else if (res is List && res.isNotEmpty && res.first is Map) {
        row = Map<String, dynamic>.from(res.first as Map);
      } else {
        throw Exception('Respuesta inesperada de create_project: $res');
      }
      return await _projectFromRow(row);
    } catch (e) {
      _mapProjectsRlsError(e);
    }
  }

  @override
  Future<void> deleteProject(int id) async {
    await _ensureJwtForRls();
    await _client.from(_projectsTable).delete().eq('id', id);
  }

  @override
  Future<int> getNextProjectId() async {
    await _ensureJwtForRls();
    final dynamic raw;
    try {
      raw = await _client.rpc('next_project_id');
    } catch (e) {
      throw Exception(
        'No se pudo obtener el siguiente id de proyecto. La función SQL '
        'next_project_id() debe existir en Supabase (migración '
        '20260321100000_projects_rls_insert_fix.sql). Sin ella, un usuario '
        'sin proyectos visibles obtenía id=1 y el guardado chocaba con filas '
        'de otros usuarios. Detalle: $e',
      );
    }
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    throw Exception(
      'Respuesta inesperada de next_project_id: $raw. Revisa la función en la base de datos.',
    );
  }

  @override
  Future<List<AppUser>> getRegisteredUsers() async {
    await _ensureJwtForRls();
    final response = await _client.rpc('list_registered_users');
    final rows = (response as List).whereType<Map>();
    return rows.map((row) {
      final data = Map<String, dynamic>.from(row);
      return AppUser(
        id: (data['user_id'] as String?) ?? '',
        email: (data['email'] as String?) ?? '',
      );
    }).where((u) => u.id.isNotEmpty && u.email.isNotEmpty).toList();
  }

  @override
  Future<List<ProjectMember>> getProjectMembers(int projectId) async {
    await _ensureJwtForRls();
    final res = await _client
        .from(_projectMembersTable)
        .select()
        .eq('project_id', projectId)
        .order('created_at');
    return (res as List)
        .whereType<Map>()
        .map((e) => _projectMemberFromRow(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<ProjectMember> addProjectMember({
    required int projectId,
    required String userId,
    required ProjectMemberRole role,
  }) async {
    await _ensureJwtForRls();
    final invitedBy = _requireCurrentUserId();
    final row = {
      'project_id': projectId,
      'user_id': userId,
      'role': role.dbValue,
      'invited_by': invitedBy,
    };
    final res = await _client
        .from(_projectMembersTable)
        .upsert(row, onConflict: 'project_id,user_id')
        .select()
        .maybeSingle();
    if (res == null) {
      throw Exception('No se pudo agregar al colaborador');
    }
    return _projectMemberFromRow(Map<String, dynamic>.from(res));
  }

  @override
  Future<ProjectMember> updateProjectMemberRole({
    required int projectId,
    required String userId,
    required ProjectMemberRole role,
  }) async {
    await _ensureJwtForRls();
    final res = await _client
        .from(_projectMembersTable)
        .update({'role': role.dbValue})
        .eq('project_id', projectId)
        .eq('user_id', userId)
        .select()
        .maybeSingle();
    if (res == null) {
      throw Exception('No se pudo actualizar el rol');
    }
    return _projectMemberFromRow(Map<String, dynamic>.from(res));
  }

  @override
  Future<void> removeProjectMember({
    required int projectId,
    required String userId,
  }) async {
    await _ensureJwtForRls();
    await _client
        .from(_projectMembersTable)
        .delete()
        .eq('project_id', projectId)
        .eq('user_id', userId);
  }

  @override
  Future<bool> canEditProject(int projectId) async {
    final project = await getProject(projectId);
    final role = project?.currentUserRole;
    return role?.canEdit ?? false;
  }

  @override
  Future<List<Task>> getTasks() async {
    await _ensureJwtForRls();
    final res = await _client.from(_tasksTable).select().order('id');
    return (res as List)
        .whereType<Map>()
        .map((e) => _taskFromRow(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<Task>> getTasksByProject(int projectId) async {
    await _ensureJwtForRls();
    final res = await _client
        .from(_tasksTable)
        .select()
        .eq('project_id', projectId)
        .order('kanban_position');
    return (res as List)
        .whereType<Map>()
        .map((e) => _taskFromRow(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<Task?> getTask(int id) async {
    await _ensureJwtForRls();
    final res =
        await _client.from(_tasksTable).select().eq('id', id).maybeSingle();
    if (res == null) return null;
    return _taskFromRow(Map<String, dynamic>.from(res));
  }

  @override
  Future<Task> saveTask(Task task) async {
    await _ensureJwtForRls();
    final res = await _client
        .from(_tasksTable)
        .upsert(_taskToRow(task), onConflict: 'id')
        .select()
        .maybeSingle();
    if (res == null) {
      throw Exception('No se pudo guardar la tarea');
    }
    return _taskFromRow(Map<String, dynamic>.from(res));
  }

  @override
  Future<void> deleteTask(int id) async {
    await _ensureJwtForRls();
    await _client.from(_tasksTable).delete().eq('id', id);
  }

  @override
  Future<int> getNextTaskId() async {
    await _ensureJwtForRls();
    final res = await _client
        .from(_tasksTable)
        .select('id')
        .order('id', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return 1;
    return ((res['id'] as num).toInt()) + 1;
  }
}

