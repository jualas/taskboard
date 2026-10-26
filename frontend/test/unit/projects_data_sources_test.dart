import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:personal_taskboard/core/error/exceptions.dart';
import 'package:personal_taskboard/core/network/taskboard_api_client.dart';
import 'package:personal_taskboard/core/network/token_provider.dart';
import 'package:personal_taskboard/core/storage/storage_service.dart';
import 'package:personal_taskboard/features/projects/data/datasources/projects_api_data_source.dart';
import 'package:personal_taskboard/features/projects/data/datasources/projects_local_data_source.dart';
import 'package:personal_taskboard/features/projects/data/models/project_model.dart';
import 'package:personal_taskboard/features/projects/domain/entities/project.dart';
import 'package:personal_taskboard/features/projects/domain/entities/project_member.dart';

class _Token implements TokenProvider {
  @override
  String? get accessToken => 'jwt';
}

Map<String, dynamic> _apiProject(int id) => {
  'id': id,
  'title': 'P$id',
  'description': 'd',
  'status': 'development',
  'owner_id': '',
  'current_user_role': 'editor',
  'workspace_path': '/ws',
  'pending_workspace_suggestions': 2,
  'created_at': '2026-01-01T00:00:00.000',
  'updated_at': '2026-01-01T00:00:00.000',
};

const _legacyLocalJson = '''
{"projects": [
  {"id": 3, "title": "Local", "description": "", "status": "planning",
   "ownerId": "local-user", "currentUserRole": "owner", "workspacePath": "",
   "pendingWorkspaceSuggestions": 0,
   "createdAt": "2025-05-01T10:00:00.000", "updatedAt": "2025-05-01T10:00:00.000"}
], "tasks": [
  {"id": 1, "projectId": 3, "title": "t", "description": "", "status": "pending",
   "kanbanPosition": 1.0, "complexity": "simple", "tags": [], "subtasks": [],
   "createdAt": "2025-05-01T10:00:00.000", "updatedAt": "2025-05-01T10:00:00.000"}
]}
''';

void main() {
  group('ProjectsApiDataSource', () {
    ProjectsApiDataSource build(MockClientHandler handler) =>
        ProjectsApiDataSource(
          TaskboardApiClient(
            baseUrl: 'https://api.test',
            tokenProvider: _Token(),
            httpClient: MockClient(handler),
          ),
        );

    test('getProjects lee el JSON del API; owner vacío pasa a null', () async {
      final ds = build(
        (_) async => http.Response(jsonEncode([_apiProject(1)]), 200),
      );
      final p = (await ds.getProjects()).single;
      expect(p.status, ProjectStatus.development);
      expect(p.ownerId, isNull);
      expect(p.currentUserRole, ProjectMemberRole.editor);
      expect(p.pendingWorkspaceSuggestions, 2);
    });

    test('createProject envía solo los campos editables', () async {
      late http.Request sent;
      final ds = build((req) async {
        sent = req;
        return http.Response(jsonEncode(_apiProject(9)), 201);
      });
      await ds.createProject(
        ProjectModel.fromApiJson(_apiProject(1)).toEntity(),
      );
      expect(sent.method, 'POST');
      expect(jsonDecode(sent.body), {
        'title': 'P1',
        'description': 'd',
        'status': 'development',
        'workspace_path': '/ws',
      });
    });

    test('miembros, usuarios e inventario', () async {
      final ds = build((req) async {
        switch (req.url.path) {
          case '/api/projects/1/members':
            return http.Response(
              jsonEncode([
                {
                  'project_id': 1,
                  'user_id': 'u1',
                  'role': 'viewer',
                  'created_at': '2026-01-01T00:00:00.000',
                },
              ]),
              200,
            );
          case '/api/users':
            return http.Response(
              jsonEncode([
                {'user_id': 'u1', 'email': 'a@b.c'},
                {'user_id': '', 'email': 'sin-id@b.c'},
              ]),
              200,
            );
          default:
            return http.Response(
              jsonEncode({
                'entries': [
                  {'path': '/ws/a', 'name': 'a', 'root': 'ws', 'has_git': true},
                ],
                'orphan_projects': [],
                'total': 1,
                'linked': 0,
                'unlinked': 1,
              }),
              200,
            );
        }
      });

      expect(
        (await ds.getProjectMembers(1)).single.role,
        ProjectMemberRole.viewer,
      );
      expect((await ds.getRegisteredUsers()).map((u) => u.id), ['u1']);
      final inv = await ds.getWorkspaceInventory();
      expect(inv.entries.single.hasGit, isTrue);
      expect(inv.unlinked, 1);
    });

    test('403 se traduce a ServerException con la operación', () async {
      final ds = build((_) async => http.Response('', 403));
      expect(
        ds.syncProjectWorkspace(1),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('Sync workspace'),
          ),
        ),
      );
    });

    test('canEditProject según el rol del usuario', () async {
      final ds = build(
        (_) async => http.Response(jsonEncode(_apiProject(1)), 200),
      );
      expect(await ds.canEditProject(1), isTrue);
    });
  });

  group('ProjectsLocalDataSource', () {
    late ProjectsLocalDataSource ds;
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'app_data': _legacyLocalJson});
      storage = StorageService();
      await storage.init();
      ds = ProjectsLocalDataSource(storage);
    });

    test('lee los proyectos guardados por la versión anterior', () async {
      final p = (await ds.getProjects()).single;
      expect(p.title, 'Local');
      expect(p.currentUserRole, ProjectMemberRole.owner);
    });

    test('crear asigna id y propietario local', () async {
      await ds.createProject(
        Project(
          id: 0,
          title: 'Nuevo',
          description: '',
          status: ProjectStatus.planning,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
      final created = (await ds.getProjects()).last;
      expect(created.id, 4);
      expect(created.ownerId, 'local-user');
    });

    test('borrar un proyecto borra también sus tareas', () async {
      await ds.deleteProject(3);
      expect(await ds.getProjects(), isEmpty);
      expect(storage.readCollection('tasks'), isEmpty);
    });
  });
}
