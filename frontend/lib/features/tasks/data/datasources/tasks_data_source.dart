import '../models/task_model.dart';

/// Acceso a las tareas. Dos implementaciones: `TasksApiDataSource` (API
/// TaskBoard) y `TasksLocalDataSource` (modo local sin API).
abstract class TasksDataSource {
  Future<List<TaskModel>> getTasks();
  Future<List<TaskModel>> getTasksByProject(int projectId);
  Future<TaskModel?> getTask(int id);

  /// Crea o actualiza por `id`.
  Future<TaskModel> saveTask(TaskModel task);
  Future<void> deleteTask(int id);
  Future<int> getNextTaskId();
}
