import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_taskboard/core/error/exceptions.dart';
import 'package:personal_taskboard/core/error/failures.dart';
import 'package:personal_taskboard/features/tasks/data/datasources/tasks_remote_data_source.dart';
import 'package:personal_taskboard/features/tasks/data/models/task_model.dart';
import 'package:personal_taskboard/features/tasks/data/repositories/tasks_repository_impl.dart';
import 'package:personal_taskboard/features/tasks/domain/entities/task.dart';

class _MockRemote extends Mock implements TasksRemoteDataSource {}

final _t = DateTime(2026, 1, 1);

TaskModel _model({required int id, required double position}) => TaskModel(
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
  late _MockRemote remote;
  late TasksRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    repo = TasksRepositoryImpl(remote);
  });

  test('getTasksByProject mapea sin reordenar', () async {
    when(() => remote.getTasksByProject(10)).thenAnswer(
      (_) async => [_model(id: 2, position: 5), _model(id: 1, position: 1)],
    );
    final result = await repo.getTasksByProject(10);
    expect(result.valueOrNull?.map((t) => t.id).toList(), [2, 1]);
  });

  test('getTasksByProject traduce UnauthorizedException', () async {
    when(() => remote.getTasksByProject(10)).thenThrow(
      const UnauthorizedException('caducada'),
    );
    final result = await repo.getTasksByProject(10);
    expect(result.failureOrNull, isA<UnauthorizedFailure>());
  });

  test('getTask devuelve null si el data source no encuentra', () async {
    when(() => remote.getTask(4)).thenAnswer((_) async => null);
    final result = await repo.getTask(4);
    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, isNull);
  });
}
