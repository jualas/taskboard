import '../../../../core/error/result.dart';
import '../entities/task.dart';

abstract class TasksRepository {
  Future<Result<List<Task>>> getTasksByProject(int projectId);
  Future<Result<Task?>> getTask(int id);
  Future<Result<Task>> createTask({
    required int projectId,
    required String title,
    String description,
    TaskStatus status,
    DateTime? dueDate,
    int? estimatedHours,
    TaskComplexity complexity,
    List<String> tags,
    List<Subtask> subtasks,
  });
  Future<Result<Task>> updateTask(Task task);
  Future<Result<void>> deleteTask(int id);
  Future<Result<Task>> updateTaskStatus(int id, TaskStatus status);
  Future<Result<Task>> moveTask({
    required int taskId,
    required TaskStatus newStatus,
    required int targetIndex,
  });
}
