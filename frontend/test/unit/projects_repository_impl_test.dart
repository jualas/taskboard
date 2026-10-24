import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_taskboard/core/error/exceptions.dart';
import 'package:personal_taskboard/core/error/failures.dart';
import 'package:personal_taskboard/features/projects/data/datasources/projects_remote_data_source.dart';
import 'package:personal_taskboard/features/projects/data/repositories/projects_repository_impl.dart';
import 'package:personal_taskboard/features/projects/domain/entities/project.dart';
import 'package:personal_taskboard/features/projects/domain/entities/workspace.dart';

class _MockRemote extends Mock implements ProjectsRemoteDataSource {}

final _t = DateTime(2026, 1, 1);

Project _project() => Project(
      id: 1,
      title: 'P',
      description: '',
      status: ProjectStatus.planning,
      createdAt: _t,
      updatedAt: _t,
    );

void main() {
  late _MockRemote remote;
  late ProjectsRepositoryImpl repo;

  setUpAll(() => registerFallbackValue(_project()));

  setUp(() {
    remote = _MockRemote();
    repo = ProjectsRepositoryImpl(remote);
  });

  test('getProjects devuelve las entidades del data source', () async {
    when(() => remote.getProjects()).thenAnswer((_) async => [_project()]);
    final result = await repo.getProjects();
    expect(result.valueOrNull?.single.title, 'P');
  });

  test('getProjects traduce UnauthorizedException', () async {
    when(() => remote.getProjects()).thenThrow(const UnauthorizedException());
    final result = await repo.getProjects();
    expect(result.failureOrNull, isA<UnauthorizedFailure>());
  });

  test('previewWorkspaceSnapshot lee summary', () async {
    when(() => remote.previewWorkspaceSnapshot('/tmp/ws')).thenAnswer(
      (_) async => {'summary': '  3 carpetas  '},
    );
    final result = await repo.previewWorkspaceSnapshot('/tmp/ws');
    expect(result.valueOrNull, isA<WorkspacePreview>());
    expect(result.valueOrNull?.summary, '3 carpetas');
  });

  test('exportTaskboardMd lee ruta y recuento', () async {
    when(
      () => remote.exportTaskboardMd(1, dryRun: false, filename: ''),
    ).thenAnswer(
      (_) async => {'file_path': 'TASKBOARD.md', 'task_count': 4},
    );
    final result = await repo.exportTaskboardMd(1);
    expect(result.valueOrNull?.filePath, 'TASKBOARD.md');
    expect(result.valueOrNull?.taskCountLabel, '4');
  });

  test('applyWorkspaceSuggestion ignora el mapa y confirma', () async {
    when(() => remote.applyWorkspaceSuggestion(1, 2)).thenAnswer(
      (_) async => {'ok': true},
    );
    final result = await repo.applyWorkspaceSuggestion(1, 2);
    expect(result.isSuccess, isTrue);
  });
}
