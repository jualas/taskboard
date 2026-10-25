import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:personal_taskboard/core/error/exceptions.dart';
import 'package:personal_taskboard/core/network/taskboard_api_client.dart';
import 'package:personal_taskboard/core/network/token_provider.dart';
import 'package:personal_taskboard/core/storage/storage_service.dart';
import 'package:personal_taskboard/features/tasks/data/datasources/tasks_api_data_source.dart';
import 'package:personal_taskboard/features/tasks/data/datasources/tasks_local_data_source.dart';
import 'package:personal_taskboard/features/tasks/data/models/task_model.dart';
import 'package:personal_taskboard/features/tasks/domain/entities/task.dart';

class _Token implements TokenProvider {
  @override
  String? get accessToken => 'jwt';
}

Map<String, dynamic> _apiTask(int id, {int projectId = 10}) => {
  'id': id,
  'project_id': projectId,
  'title': 'T$id',
  'description': '',
  'status': 'in_progress',
  'due_date': null,
  'kanban_position': 2,
  'estimated_hours': 3,
  'complexity': 'complex',
  'tags': ['a'],
  'subtasks': [
    {'id': 1, 'title': 's', 'is_done': true},
  ],
  'created_at': '2026-01-01T00:00:00.000',
  'updated_at': '2026-01-02T00:00:00.000',
};

/// Tarea guardada por la versión anterior de la app (modelo json_serializable).
const _legacyLocalJson = '''
{"projects": [], "tasks": [
  {"id": 4, "projectId": 2, "title": "Antigua", "description": "d",
   "status": "completed", "dueDate": null, "kanbanPosition": 1.0,
   "estimatedHours": null, "complexity": "medium", "tags": [],
   "subtasks": [{"id": 1, "title": "paso", "isDone": false}],
   "createdAt": "2025-05-01T10:00:00.000", "updatedAt": "2025-05-01T10:00:00.000"}
]}
''';

void main() {
  group('TasksApiDataSource', () {
    TasksApiDataSource build(MockClientHandler handler) => TasksApiDataSource(
      TaskboardApiClient(
        baseUrl: 'https://api.test',
        tokenProvider: _Token(),
        httpClient: MockClient(handler),
      ),
    );

    test('lee el JSON del API (snake_case, is_done)', () async {
      late http.Request sent;
      final ds = build((req) async {
        sent = req;
        return http.Response(jsonEncode([_apiTask(1)]), 200);
      });

      final tasks = await ds.getTasksByProject(10);

      expect(sent.url.path, '/api/tasks/by-project/10');
      expect(sent.headers['Authorization'], 'Bearer jwt');
      final t = tasks.single.toEntity();
      expect(t.status, TaskStatus.inProgress);
      expect(t.complexity, TaskComplexity.complex);
      expect(t.kanbanPosition, 2.0);
      expect(t.subtasks.single.isDone, isTrue);
    });

    test('saveTask hace PUT con el cuerpo del API', () async {
      late http.Request sent;
      final ds = build((req) async {
        sent = req;
        return http.Response(jsonEncode(_apiTask(7)), 200);
      });
      final model = TaskModel.fromApiJson(_apiTask(7));

      final saved = await ds.saveTask(model);

      expect(sent.method, 'PUT');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['project_id'], 10);
      expect(body['status'], 'in_progress');
      expect((body['subtasks'] as List).single['is_done'], isTrue);
      expect(saved.id, 7);
    });

    test('getTask devuelve null con 404', () async {
      final ds = build((_) async => http.Response('', 404));
      expect(await ds.getTask(1), isNull);
    });

    test('401 se traduce a UnauthorizedException', () async {
      final ds = build((_) async => http.Response('', 401));
      expect(ds.getTasks(), throwsA(isA<UnauthorizedException>()));
    });

    test('403 lleva el código y la operación', () async {
      final ds = build((_) async => http.Response('', 403));
      expect(
        ds.deleteTask(1),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.message, 'message', contains('Eliminar tarea')),
        ),
      );
    });

    test('getNextTaskId lee texto plano', () async {
      final ds = build((_) async => http.Response('42', 200));
      expect(await ds.getNextTaskId(), 42);
    });

    test('un fallo de red llega como AppException', () async {
      final ds = build((_) async => throw http.ClientException('offline'));
      expect(ds.getTasks(), throwsA(isA<AppException>()));
    });
  });

  group('TasksLocalDataSource', () {
    late StorageService storage;
    late TasksLocalDataSource ds;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'app_data': _legacyLocalJson});
      storage = StorageService();
      await storage.init();
      ds = TasksLocalDataSource(storage);
    });

    test('lee las tareas guardadas por la versión anterior', () async {
      final t = (await ds.getTasksByProject(2)).single.toEntity();
      expect(t.title, 'Antigua');
      expect(t.status, TaskStatus.completed);
      expect(t.subtasks.single.title, 'paso');
    });

    test('crea, actualiza y borra; el siguiente id sigue al máximo', () async {
      expect(await ds.getNextTaskId(), 5);
      final nueva = TaskModel.fromApiJson(_apiTask(5, projectId: 2));
      await ds.saveTask(nueva);
      expect((await ds.getTasksByProject(2)).map((t) => t.id), [4, 5]);

      await ds.saveTask(TaskModel.fromApiJson(_apiTask(5, projectId: 2)));
      final updated = await ds.getTask(5);
      expect(updated!.updatedAt.isAfter(DateTime(2026, 1, 2)), isTrue);

      await ds.deleteTask(4);
      expect((await ds.getTasks()).map((t) => t.id), [5]);
    });

    test('los datos persisten con el mismo formato', () async {
      await ds.saveTask(TaskModel.fromApiJson(_apiTask(5, projectId: 2)));
      final prefs = await SharedPreferences.getInstance();
      final data = jsonDecode(prefs.getString('app_data')!) as Map;
      final stored = (data['tasks'] as List).last as Map;
      expect(stored['projectId'], 2);
      expect(stored['status'], 'in_progress');
      expect(data.containsKey('projects'), isTrue);
    });
  });
}
