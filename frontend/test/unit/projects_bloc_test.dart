import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_taskboard/core/error/failures.dart';
import 'package:personal_taskboard/core/error/result.dart';
import 'package:personal_taskboard/core/usecase/usecase.dart';
import 'package:personal_taskboard/features/projects/domain/entities/project.dart';
import 'package:personal_taskboard/features/projects/domain/usecases/projects_usecases.dart';
import 'package:personal_taskboard/features/projects/presentation/bloc/projects_bloc.dart';

class _GetProjects extends Mock implements GetProjects {}

class _Create extends Mock implements CreateProject {}

class _Update extends Mock implements UpdateProject {}

class _Delete extends Mock implements DeleteProject {}

class _Status extends Mock implements UpdateProjectStatus {}

class _GetOne extends Mock implements GetProject {}

class _Preview extends Mock implements PreviewWorkspaceSnapshot {}

class _Suggestions extends Mock implements GetWorkspaceSuggestions {}

class _Apply extends Mock implements ApplyWorkspaceSuggestion {}

class _Dismiss extends Mock implements DismissWorkspaceSuggestion {}

class _Sync extends Mock implements SyncProjectWorkspace {}

class _Inventory extends Mock implements GetWorkspaceInventory {}

class _Export extends Mock implements ExportTaskboardMd {}

class _Ide extends Mock implements PrepareIdeSession {}

class _Members extends Mock implements GetProjectMembers {}

class _Users extends Mock implements GetRegisteredUsers {}

class _Add extends Mock implements AddProjectMember {}

class _Role extends Mock implements UpdateProjectMemberRole {}

class _Remove extends Mock implements RemoveProjectMember {}

final _t = DateTime(2026, 1, 1);

ProjectsBloc _bloc(_GetProjects getProjects) => ProjectsBloc(
      getProjects: getProjects,
      createProject: _Create(),
      updateProject: _Update(),
      deleteProject: _Delete(),
      updateProjectStatus: _Status(),
      getProject: _GetOne(),
      previewWorkspaceSnapshot: _Preview(),
      getWorkspaceSuggestions: _Suggestions(),
      applyWorkspaceSuggestion: _Apply(),
      dismissWorkspaceSuggestion: _Dismiss(),
      syncProjectWorkspace: _Sync(),
      getWorkspaceInventory: _Inventory(),
      exportTaskboardMd: _Export(),
      prepareIdeSession: _Ide(),
      getProjectMembers: _Members(),
      getRegisteredUsers: _Users(),
      addProjectMember: _Add(),
      updateProjectMemberRole: _Role(),
      removeProjectMember: _Remove(),
    );

void main() {
  setUpAll(() => registerFallbackValue(const NoParams()));

  late _GetProjects getProjects;
  late ProjectsBloc bloc;

  setUp(() {
    getProjects = _GetProjects();
    bloc = _bloc(getProjects);
  });

  tearDown(() => bloc.close());

  blocTest<ProjectsBloc, ProjectsState>(
    'carga proyectos',
    build: () {
      when(() => getProjects(any())).thenAnswer(
        (_) async => Success([
          Project(
            id: 1,
            title: 'P',
            description: '',
            status: ProjectStatus.planning,
            createdAt: _t,
            updatedAt: _t,
          ),
        ]),
      );
      return bloc;
    },
    act: (b) => b.add(ProjectsLoadRequested()),
    expect: () => [isA<ProjectsLoading>(), isA<ProjectsLoaded>()],
  );

  blocTest<ProjectsBloc, ProjectsState>(
    'informa el fallo de carga',
    build: () {
      when(() => getProjects(any())).thenAnswer(
        (_) async => const ResultFailure(NetworkFailure('offline')),
      );
      return bloc;
    },
    act: (b) => b.add(ProjectsLoadRequested()),
    expect: () => [
      isA<ProjectsLoading>(),
      isA<ProjectsFailure>().having(
        (s) => s.message,
        'message',
        contains('offline'),
      ),
    ],
  );
}
