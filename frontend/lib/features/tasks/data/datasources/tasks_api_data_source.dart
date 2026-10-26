import '../../../../core/network/api_response.dart';
import '../../../../core/network/taskboard_api_client.dart';
import '../models/task_model.dart';
import 'tasks_data_source.dart';

class TasksApiDataSource implements TasksDataSource {
  TasksApiDataSource(this._client);

  final TaskboardApiClient _client;

  Future<List<TaskModel>> _list(String path, String action) =>
      guardApiCall(action, () async {
        final res = await _client.get(path);
        ensureSuccess(res, action);
        return decodeJsonList(res.body).map(TaskModel.fromApiJson).toList();
      });

  @override
  Future<List<TaskModel>> getTasks() => _list('/api/tasks', 'Listar tareas');

  @override
  Future<List<TaskModel>> getTasksByProject(int projectId) =>
      _list('/api/tasks/by-project/$projectId', 'Tareas del proyecto');

  @override
  Future<TaskModel?> getTask(int id) => guardApiCall('Obtener tarea', () async {
    final res = await _client.get('/api/tasks/$id');
    if (res.statusCode == 404) return null;
    ensureSuccess(res, 'Obtener tarea');
    return TaskModel.fromApiJson(decodeJsonMap(res.body));
  });

  @override
  Future<TaskModel> saveTask(TaskModel task) =>
      guardApiCall('Guardar tarea', () async {
        final res = await _client.put('/api/tasks', body: task.toApiJson());
        ensureSuccess(res, 'Guardar tarea');
        return TaskModel.fromApiJson(decodeJsonMap(res.body));
      });

  @override
  Future<void> deleteTask(int id) => guardApiCall('Eliminar tarea', () async {
    final res = await _client.delete('/api/tasks/$id');
    ensureSuccess(res, 'Eliminar tarea');
  });

  @override
  Future<int> getNextTaskId() => guardApiCall('next-task-id', () async {
    final res = await _client.get('/api/meta/next-task-id');
    ensureSuccess(res, 'next-task-id');
    return parsePlainInt(res.body, 'next-task-id');
  });
}
