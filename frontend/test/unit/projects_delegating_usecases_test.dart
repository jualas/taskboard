import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_taskboard/core/error/failures.dart';
import 'package:personal_taskboard/core/error/result.dart';
import 'package:personal_taskboard/core/usecase/usecase.dart';
import 'package:personal_taskboard/features/projects/domain/entities/project.dart';
import 'package:personal_taskboard/features/projects/domain/entities/project_member.dart';
import 'package:personal_taskboard/features/projects/domain/entities/workspace.dart';
import 'package:personal_taskboard/features/projects/domain/repositories/projects_repository.dart';
import 'package:personal_taskboard/features/projects/domain/usecases/projects_usecases.dart';

class _MockRepo extends Mock implements ProjectsRepository {}

final _t = DateTime(2026, 1, 1);
final _project = Project(
  id: 1,
  title: 'P',
  description: '',
  status: ProjectStatus.planning,
  createdAt: _t,
  updatedAt: _t,
);
final _member = ProjectMember(
  projectId: 1,
  userId: 'u1',
  role: ProjectMemberRole.viewer,
  createdAt: _t,
);
const _ide = IdePrompt(
  projectId: 1,
  projectTitle: 'P',
  workspacePath: '/ws',
  taskboardMd: 'TASKBOARD.md',
  statusMdPaths: [],
  fileReferences: [],
  prompt: 'p',
  taskCounts: {},
  focusTaskId: 5,
);
const _inventory = WorkspaceInventory(
  entries: [],
  orphanProjects: [],
  total: 0,
  linked: 0,
  unlinked: 0,
);

/// Casos de uso de projects que solo delegan en el repositorio: pasan los
/// parámetros tal cual y devuelven su resultado (incluido el fallo).
void main() {
  late _MockRepo repo;

  setUpAll(() => registerFallbackValue(_project));
  setUp(() => repo = _MockRepo());

  test('GetProject y UpdateProject', () async {
    when(() => repo.getProject(1)).thenAnswer((_) async => Success(_project));
    when(
      () => repo.updateProject(_project),
    ).thenAnswer((_) async => Success(_project));
    expect((await GetProject(repo)(1)).valueOrNull, _project);
    expect((await UpdateProject(repo)(_project)).valueOrNull, _project);
  });

  test('miembros: listar, cambiar rol y quitar', () async {
    when(
      () => repo.getProjectMembers(1),
    ).thenAnswer((_) async => Success([_member]));
    when(
      () => repo.updateProjectMemberRole(
        projectId: 1,
        userId: 'u1',
        role: ProjectMemberRole.editor,
      ),
    ).thenAnswer((_) async => Success(_member));
    when(
      () => repo.removeProjectMember(projectId: 1, userId: 'u1'),
    ).thenAnswer((_) async => const ResultFailure(ServerFailure()));
    when(() => repo.getRegisteredUsers()).thenAnswer(
      (_) async => const Success([AppUser(id: 'u1', email: 'a@b.c')]),
    );

    expect((await GetProjectMembers(repo)(1)).valueOrNull, [_member]);
    expect(
      (await UpdateProjectMemberRole(repo)(
        const MemberChangeParams(
          projectId: 1,
          userId: 'u1',
          role: ProjectMemberRole.editor,
        ),
      )).isSuccess,
      isTrue,
    );
    expect(
      (await RemoveProjectMember(repo)(
        const MemberRemoveParams(projectId: 1, userId: 'u1'),
      )).failureOrNull,
      isA<ServerFailure>(),
    );
    expect(
      (await GetRegisteredUsers(repo)(const NoParams())).valueOrNull!.single.id,
      'u1',
    );
  });

  test('workspace: vista previa, sugerencias, sync e inventario', () async {
    when(
      () => repo.previewWorkspaceSnapshot('/ws'),
    ).thenAnswer((_) async => const Success(WorkspacePreview('ok')));
    when(
      () => repo.getWorkspaceSuggestions(1, state: 'dismissed'),
    ).thenAnswer((_) async => const Success([]));
    when(
      () => repo.dismissWorkspaceSuggestion(1, 9),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repo.syncProjectWorkspace(1),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repo.getWorkspaceInventory(),
    ).thenAnswer((_) async => const Success(_inventory));

    expect(
      (await PreviewWorkspaceSnapshot(repo)('/ws')).valueOrNull!.summary,
      'ok',
    );
    expect(
      (await GetWorkspaceSuggestions(repo)(
        const WorkspaceSuggestionsParams(1, state: 'dismissed'),
      )).isSuccess,
      isTrue,
    );
    expect(
      (await DismissWorkspaceSuggestion(repo)(
        const SuggestionActionParams(projectId: 1, suggestionId: 9),
      )).isSuccess,
      isTrue,
    );
    expect((await SyncProjectWorkspace(repo)(1)).isSuccess, isTrue);
    expect(
      (await GetWorkspaceInventory(repo)(const NoParams())).valueOrNull,
      _inventory,
    );
  });

  test('export de TASKBOARD.md y sesión IDE', () async {
    when(
      () => repo.exportTaskboardMd(1, dryRun: true, filename: 'X.md'),
    ).thenAnswer(
      (_) async => const Success(
        TaskboardExport(filePath: '/ws/X.md', taskCountLabel: '3'),
      ),
    );
    when(
      () => repo.prepareIdeSession(1, focusTaskId: 5),
    ).thenAnswer((_) async => const Success(_ide));

    final export = await ExportTaskboardMd(repo)(
      const ExportTaskboardMdParams(
        projectId: 1,
        dryRun: true,
        filename: 'X.md',
      ),
    );
    expect(export.valueOrNull!.filePath, '/ws/X.md');
    final ide = await PrepareIdeSession(repo)(
      const PrepareIdeSessionParams(projectId: 1, focusTaskId: 5),
    );
    expect(ide.valueOrNull!.focusTaskId, 5);
  });
}
