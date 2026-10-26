import '../../../../core/storage/storage_service.dart';
import '../models/task_model.dart';
import 'tasks_data_source.dart';

/// Tareas del modo local, en la colección `tasks` de [StorageService].
class TasksLocalDataSource implements TasksDataSource {
  TasksLocalDataSource(this._storage);

  static const collection = 'tasks';

  final StorageService _storage;

  List<TaskModel> _all() =>
      _storage.readCollection(collection).map(TaskModel.fromJson).toList();

  @override
  Future<List<TaskModel>> getTasks() async => _all();

  @override
  Future<List<TaskModel>> getTasksByProject(int projectId) async =>
      _all().where((t) => t.projectId == projectId).toList();

  @override
  Future<TaskModel?> getTask(int id) async {
    for (final t in _all()) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Al actualizar se renueva `updatedAt`; una tarea nueva se guarda tal cual.
  @override
  Future<TaskModel> saveTask(TaskModel task) async {
    final tasks = _all();
    final index = tasks.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      tasks[index] = task.copyWith(updatedAt: DateTime.now());
    } else {
      tasks.add(task);
    }
    await _storage.writeCollection(
      collection,
      tasks.map((t) => t.toJson()).toList(),
    );
    return task;
  }

  @override
  Future<void> deleteTask(int id) async {
    await _storage.writeCollection(
      collection,
      _all().where((t) => t.id != id).map((t) => t.toJson()).toList(),
    );
  }

  @override
  Future<int> getNextTaskId() async => _storage.nextId(collection);
}
