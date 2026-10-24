import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_taskboard/core/error/failures.dart';
import 'package:personal_taskboard/core/error/result.dart';
import 'package:personal_taskboard/core/usecase/usecase.dart';
import 'package:personal_taskboard/features/projects/domain/entities/project.dart';
import 'package:personal_taskboard/features/projects/domain/entities/project_member.dart';
import 'package:personal_taskboard/features/projects/domain/repositories/projects_repository.dart';
import 'package:personal_taskboard/features/projects/domain/usecases/projects_usecases.dart';

class _MockRepo extends Mock implements ProjectsRepository {}

final _t = DateTime(2026, 1, 1);

Project _project({int id = 1}) => Project(
      id: id,
      title: 'P$id',
      description: '',
      status: ProjectStatus.planning,
      createdAt: _t,
      updatedAt: _t,
    );

void main() {
  late _MockRepo repo;

  setUpAll(() {
    registerFallbackValue(_project());
    registerFallbackValue(ProjectStatus.planning);
    registerFallbackValue(ProjectMemberRole.viewer);
  });

  setUp(() => repo = _MockRepo());

  test('GetProjects éxito y fallo', () async {
    when(() => repo.getProjects()).thenAnswer((_) async => Success([_project()]));
    final ok = await GetProjects(repo)(const NoParams());
    expect(ok.valueOrNull, hasLength(1));

    when(() => repo.getProjects()).thenAnswer(
      (_) async => const ResultFailure(NetworkFailure('offline')),
    );
    final fail = await GetProjects(repo)(const NoParams());
    expect(fail.failureOrNull, isA<NetworkFailure>());
  });

  test('CreateProject construye la entidad y propaga el fallo', () async {
    when(() => repo.createProject(any())).thenAnswer((invocation) async {
      return Success(invocation.positionalArguments.first as Project);
    });
    final created = await CreateProject(repo)(
      const CreateProjectParams(title: 'Nuevo', description: 'd'),
    );
    final project = created.valueOrNull!;
    expect(project.id, 0);
    expect(project.title, 'Nuevo');
    expect(project.status, ProjectStatus.planning);

    when(() => repo.createProject(any())).thenAnswer(
      (_) async => const ResultFailure(ServerFailure(message: 'dup')),
    );
    final fail = await CreateProject(repo)(const CreateProjectParams(title: 'X'));
    expect(fail.failureOrNull, isA<ServerFailure>());
  });

  test('UpdateProjectStatus devuelve no encontrado si no hay proyecto', () async {
    when(() => repo.getProject(4)).thenAnswer((_) async => const Success(null));
    final result = await UpdateProjectStatus(repo)(
      const UpdateProjectStatusParams(id: 4, status: ProjectStatus.completed),
    );
    expect(result.failureOrNull, isA<NotFoundFailure>());
  });

  test('UpdateProjectStatus guarda el estado nuevo', () async {
    when(() => repo.getProject(1)).thenAnswer((_) async => Success(_project()));
    when(() => repo.updateProject(any())).thenAnswer((invocation) async {
      return Success(invocation.positionalArguments.first as Project);
    });
    final result = await UpdateProjectStatus(repo)(
      const UpdateProjectStatusParams(id: 1, status: ProjectStatus.development),
    );
    expect(result.valueOrNull?.status, ProjectStatus.development);
  });

  test('DeleteProject éxito y fallo', () async {
    when(() => repo.deleteProject(3)).thenAnswer((_) async => const Success(null));
    expect((await DeleteProject(repo)(3)).isSuccess, isTrue);

    when(() => repo.deleteProject(3)).thenAnswer(
      (_) async => const ResultFailure(UnauthorizedFailure()),
    );
    expect((await DeleteProject(repo)(3)).failureOrNull, isA<UnauthorizedFailure>());
  });

  test('AddProjectMember éxito y fallo', () async {
    final member = ProjectMember(
      projectId: 1,
      userId: 'u',
      role: ProjectMemberRole.editor,
      createdAt: _t,
    );
    when(
      () => repo.addProjectMember(
        projectId: any(named: 'projectId'),
        userId: any(named: 'userId'),
        role: any(named: 'role'),
      ),
    ).thenAnswer((_) async => Success(member));
    final ok = await AddProjectMember(repo)(
      const MemberChangeParams(projectId: 1, userId: 'u', role: ProjectMemberRole.editor),
    );
    expect(ok.valueOrNull?.role, ProjectMemberRole.editor);

    when(
      () => repo.addProjectMember(
        projectId: any(named: 'projectId'),
        userId: any(named: 'userId'),
        role: any(named: 'role'),
      ),
    ).thenAnswer((_) async => const ResultFailure(NotFoundFailure()));
    final fail = await AddProjectMember(repo)(
      const MemberChangeParams(projectId: 1, userId: 'u', role: ProjectMemberRole.editor),
    );
    expect(fail.failureOrNull, isA<NotFoundFailure>());
  });

  test('ApplyWorkspaceSuggestion éxito y fallo', () async {
    when(() => repo.applyWorkspaceSuggestion(1, 9)).thenAnswer(
      (_) async => const Success(null),
    );
    final ok = await ApplyWorkspaceSuggestion(repo)(
      const SuggestionActionParams(projectId: 1, suggestionId: 9),
    );
    expect(ok.isSuccess, isTrue);

    when(() => repo.applyWorkspaceSuggestion(1, 9)).thenAnswer(
      (_) async => const ResultFailure(NetworkFailure()),
    );
    final fail = await ApplyWorkspaceSuggestion(repo)(
      const SuggestionActionParams(projectId: 1, suggestionId: 9),
    );
    expect(fail.failureOrNull, isA<NetworkFailure>());
  });
}
