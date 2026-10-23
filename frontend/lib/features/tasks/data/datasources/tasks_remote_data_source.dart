import '../../../../core/error/exception_to_failure.dart';
import '../../../../models/task.dart' as legacy;
import '../../../../services/taskboard_data_source.dart';
import '../models/task_model.dart';

abstract class TasksRemoteDataSource {
  Future<List<TaskModel>> getTasks();
  Future<List<TaskModel>> getTasksByProject(int projectId);
  Future<TaskModel?> getTask(int id);
  Future<TaskModel> saveTask(TaskModel task);
  Future<void> deleteTask(int id);
  Future<int> getNextTaskId();
}

class TasksRemoteDataSourceImpl implements TasksRemoteDataSource {
  TasksRemoteDataSourceImpl(this._dataSource);

  final TaskboardDataSource _dataSource;

  TaskModel _fromLegacy(legacy.Task task) =>
      TaskModel.fromLegacyJson(task.toJson());

  legacy.Task _toLegacy(TaskModel model) =>
      legacy.Task.fromJson(model.toJson());

  @override
  Future<List<TaskModel>> getTasks() async {
    try {
      final list = await _dataSource.getTasks();
      return list.map(_fromLegacy).toList();
    } catch (e) {
      rethrowAsAppException(e, context: 'getTasks');
    }
  }

  @override
  Future<List<TaskModel>> getTasksByProject(int projectId) async {
    try {
      final list = await _dataSource.getTasksByProject(projectId);
      return list.map(_fromLegacy).toList();
    } catch (e) {
      rethrowAsAppException(e, context: 'getTasksByProject');
    }
  }

  @override
  Future<TaskModel?> getTask(int id) async {
    try {
      final t = await _dataSource.getTask(id);
      return t == null ? null : _fromLegacy(t);
    } catch (e) {
      rethrowAsAppException(e, context: 'getTask');
    }
  }

  @override
  Future<TaskModel> saveTask(TaskModel task) async {
    try {
      final saved = await _dataSource.saveTask(_toLegacy(task));
      return _fromLegacy(saved);
    } catch (e) {
      rethrowAsAppException(e, context: 'saveTask');
    }
  }

  @override
  Future<void> deleteTask(int id) async {
    try {
      await _dataSource.deleteTask(id);
    } catch (e) {
      rethrowAsAppException(e, context: 'deleteTask');
    }
  }

  @override
  Future<int> getNextTaskId() async {
    try {
      return _dataSource.getNextTaskId();
    } catch (e) {
      rethrowAsAppException(e, context: 'getNextTaskId');
    }
  }
}
