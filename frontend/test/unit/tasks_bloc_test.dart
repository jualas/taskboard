import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_taskboard/core/error/result.dart';
import 'package:personal_taskboard/features/tasks/domain/entities/task.dart';
import 'package:personal_taskboard/features/tasks/domain/usecases/tasks_usecases.dart';
import 'package:personal_taskboard/features/tasks/presentation/bloc/tasks_bloc.dart';

class _MockGetTasks extends Mock implements GetTasksByProject {}

class _MockCreate extends Mock implements CreateTask {}

class _MockUpdate extends Mock implements UpdateTask {}

class _MockDelete extends Mock implements DeleteTask {}

class _MockStatus extends Mock implements UpdateTaskStatus {}

class _MockMove extends Mock implements MoveTask {}

final _t = DateTime(2026, 1, 1);

void main() {
  setUpAll(() {
    registerFallbackValue(const GetTasksByProjectParams(0));
  });

  late _MockGetTasks getTasks;
  late TasksBloc bloc;

  setUp(() {
    getTasks = _MockGetTasks();
    bloc = TasksBloc(
      getTasksByProject: getTasks,
      createTask: _MockCreate(),
      updateTask: _MockUpdate(),
      deleteTask: _MockDelete(),
      updateTaskStatus: _MockStatus(),
      moveTask: _MockMove(),
    );
  });

  tearDown(() => bloc.close());

  blocTest<TasksBloc, TasksState>(
    'carga tareas del proyecto',
    build: () {
      when(() => getTasks(any())).thenAnswer(
        (_) async => Success([
          Task(
            id: 1,
            projectId: 10,
            title: 'T',
            description: '',
            status: TaskStatus.pending,
            kanbanPosition: 1,
            complexity: TaskComplexity.simple,
            tags: const [],
            createdAt: _t,
            updatedAt: _t,
          ),
        ]),
      );
      return bloc;
    },
    act: (b) => b.add(const TasksLoadRequested(projectId: 10)),
    expect: () => [
      isA<TasksLoading>(),
      isA<TasksLoaded>(),
    ],
  );
}
