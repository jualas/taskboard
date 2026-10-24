import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_taskboard/core/error/failures.dart';
import 'package:personal_taskboard/core/error/result.dart';
import 'package:personal_taskboard/features/tasks/domain/entities/task.dart';
import 'package:personal_taskboard/features/tasks/domain/repositories/tasks_repository.dart';
import 'package:personal_taskboard/features/tasks/domain/usecases/tasks_usecases.dart';

class _MockTasksRepository extends Mock implements TasksRepository {}

final _t = DateTime(2026, 1, 1);

Task _task({required int id, required double position}) => Task(
      id: id,
      projectId: 10,
      title: 'T$id',
      description: '',
      status: TaskStatus.pending,
      kanbanPosition: position,
      complexity: TaskComplexity.simple,
      tags: const [],
      createdAt: _t,
      updatedAt: _t,
    );

void main() {
  late _MockTasksRepository repo;

  setUpAll(() {
    registerFallbackValue(TaskStatus.pending);
    registerFallbackValue(TaskComplexity.simple);
    registerFallbackValue(<String>[]);
    registerFallbackValue(<Subtask>[]);
    registerFallbackValue(_task(id: 0, position: 0));
  });

  setUp(() => repo = _MockTasksRepository());

  test('GetTasksByProject ordena por kanbanPosition', () async {
    when(() => repo.getTasksByProject(10)).thenAnswer(
      (_) async => Success([_task(id: 2, position: 3), _task(id: 1, position: 1)]),
    );
    final result = await GetTasksByProject(repo)(const GetTasksByProjectParams(10));
    final tasks = result.valueOrNull!;
    expect(tasks.map((t) => t.id).toList(), [1, 2]);
  });

  test('GetTasksByProject propaga el fallo', () async {
    when(() => repo.getTasksByProject(10)).thenAnswer(
      (_) async => const ResultFailure(NetworkFailure('offline')),
    );
    final result = await GetTasksByProject(repo)(const GetTasksByProjectParams(10));
    expect(result.failureOrNull, isA<NetworkFailure>());
  });

  test('CreateTask éxito y fallo', () async {
    final created = _task(id: 9, position: 1);
    when(
      () => repo.createTask(
        projectId: any(named: 'projectId'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        status: any(named: 'status'),
        dueDate: any(named: 'dueDate'),
        estimatedHours: any(named: 'estimatedHours'),
        complexity: any(named: 'complexity'),
        tags: any(named: 'tags'),
        subtasks: any(named: 'subtasks'),
      ),
    ).thenAnswer((_) async => Success(created));

    final ok = await CreateTask(repo)(
      const CreateTaskParams(projectId: 10, title: 'Nueva'),
    );
    expect(ok.valueOrNull?.id, 9);

    when(
      () => repo.createTask(
        projectId: any(named: 'projectId'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        status: any(named: 'status'),
        dueDate: any(named: 'dueDate'),
        estimatedHours: any(named: 'estimatedHours'),
        complexity: any(named: 'complexity'),
        tags: any(named: 'tags'),
        subtasks: any(named: 'subtasks'),
      ),
    ).thenAnswer(
      (_) async => const ResultFailure(UnexpectedFailure('no')),
    );
    final bad = await CreateTask(repo)(
      const CreateTaskParams(projectId: 10, title: 'Nueva'),
    );
    expect(bad.failureOrNull, isA<UnexpectedFailure>());
  });

  test('UpdateTask, DeleteTask, UpdateTaskStatus y MoveTask', () async {
    final task = _task(id: 1, position: 1);
    when(() => repo.updateTask(task)).thenAnswer((_) async => Success(task));
    expect((await UpdateTask(repo)(task)).isSuccess, isTrue);

    when(() => repo.updateTask(task)).thenAnswer(
      (_) async => const ResultFailure(NotFoundFailure()),
    );
    expect((await UpdateTask(repo)(task)).failureOrNull, isA<NotFoundFailure>());

    when(() => repo.deleteTask(1)).thenAnswer((_) async => const Success(null));
    expect((await DeleteTask(repo)(const DeleteTaskParams(1))).isSuccess, isTrue);
    when(() => repo.deleteTask(1)).thenAnswer(
      (_) async => const ResultFailure(NetworkFailure()),
    );
    expect(
      (await DeleteTask(repo)(const DeleteTaskParams(1))).failureOrNull,
      isA<NetworkFailure>(),
    );

    when(() => repo.updateTaskStatus(1, TaskStatus.completed)).thenAnswer(
      (_) async => Success(task),
    );
    expect(
      (await UpdateTaskStatus(repo)(
        const UpdateTaskStatusParams(taskId: 1, status: TaskStatus.completed),
      ))
          .isSuccess,
      isTrue,
    );
    when(() => repo.updateTaskStatus(1, TaskStatus.completed)).thenAnswer(
      (_) async => const ResultFailure(UnauthorizedFailure()),
    );
    expect(
      (await UpdateTaskStatus(repo)(
        const UpdateTaskStatusParams(taskId: 1, status: TaskStatus.completed),
      ))
          .failureOrNull,
      isA<UnauthorizedFailure>(),
    );

    when(
      () => repo.moveTask(
        taskId: 1,
        newStatus: TaskStatus.inProgress,
        targetIndex: 0,
      ),
    ).thenAnswer((_) async => Success(task));
    expect(
      (await MoveTask(repo)(
        const MoveTaskParams(
          taskId: 1,
          newStatus: TaskStatus.inProgress,
          targetIndex: 0,
        ),
      ))
          .isSuccess,
      isTrue,
    );
    when(
      () => repo.moveTask(
        taskId: 1,
        newStatus: TaskStatus.inProgress,
        targetIndex: 0,
      ),
    ).thenAnswer((_) async => const ResultFailure(ServerFailure()));
    expect(
      (await MoveTask(repo)(
        const MoveTaskParams(
          taskId: 1,
          newStatus: TaskStatus.inProgress,
          targetIndex: 0,
        ),
      ))
          .failureOrNull,
      isA<ServerFailure>(),
    );
  });
}
