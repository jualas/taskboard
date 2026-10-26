# Plantillas — Clean Architecture (frontend TaskBoard)

Copiar el estilo de `features/tasks/`. Rutas relativas desde `features/<f>/…`.

## Caso de uso (`domain/usecases/get_project.dart`)

```dart
import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/project.dart';
import '../repositories/projects_repository.dart';

class GetProject implements UseCase<Project?, int> {
  GetProject(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<Project?>> call(int id) => _repo.getProject(id);
}
```

Sin parámetros: `UseCase<List<Project>, NoParams>` y `call(NoParams params)`. Varios parámetros: clase `XxxParams` inmutable en su propio fichero si la comparten varios casos de uso.

## Repositorio

```dart
// domain/repositories/projects_repository.dart
abstract class ProjectsRepository {
  Future<Result<Project?>> getProject(int id);
}

// data/repositories/projects_repository_impl.dart
class ProjectsRepositoryImpl implements ProjectsRepository {
  ProjectsRepositoryImpl(this._dataSource);
  final ProjectsDataSource _dataSource;

  @override
  Future<Result<Project?>> getProject(int id) async {
    try {
      return Success(await _dataSource.getProject(id));
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }
}

// data/datasources/projects_api_data_source.dart
class ProjectsApiDataSource implements ProjectsDataSource {
  ProjectsApiDataSource(this._client);
  final TaskboardApiClient _client;

  @override
  Future<Project?> getProject(int id) =>
      guardApiCall('Obtener proyecto', () async {
        final res = await _client.get('/api/projects/$id');
        if (res.statusCode == 404) return null;
        ensureSuccess(res, 'Obtener proyecto');
        return ProjectModel.fromApiJson(decodeJsonMap(res.body)).toEntity();
      });
}
```

## DI (`core/di/injection.dart`)

```dart
sl
  ..registerLazySingleton<ProjectsDataSource>(
    () => client != null
        ? ProjectsApiDataSource(client)
        : ProjectsLocalDataSource(sl<StorageService>()),
  )
  ..registerLazySingleton<ProjectsRepository>(() => ProjectsRepositoryImpl(sl()))
  ..registerLazySingleton(() => GetProject(sl()))
  ..registerFactory(() => ProjectsBloc(getProject: sl() /* … */));
```

En la UI: `BlocProvider(create: (_) => sl<ProjectsBloc>())` y nada más de `sl` en widgets.

## Tests

```dart
// test/unit/<f>_usecases_test.dart
class _MockRepo extends Mock implements ProjectsRepository {}

test('GetProject devuelve el proyecto', () async {
  final repo = _MockRepo();
  when(() => repo.getProject(1)).thenAnswer((_) async => Success(project));
  expect(await GetProject(repo)(1), isA<Success<Project?>>());
});

// BLoC
blocTest<ProjectsBloc, ProjectsState>(
  'carga proyectos',
  build: () => ProjectsBloc(getProjects: getProjects /* … */),
  act: (b) => b.add(LoadProjects()),
  expect: () => [isA<ProjectsLoading>(), isA<ProjectsLoaded>()],
);
```

Nombres de eventos/estados: comprobar los reales del BLoC antes de copiar.
