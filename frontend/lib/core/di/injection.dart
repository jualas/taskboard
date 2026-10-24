import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/auth_usecases.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/projects/data/datasources/projects_remote_data_source.dart';
import '../../features/projects/data/repositories/projects_repository_impl.dart';
import '../../features/projects/domain/repositories/projects_repository.dart';
import '../../features/projects/domain/usecases/projects_usecases.dart';
import '../../features/projects/presentation/bloc/projects_bloc.dart';
import '../../features/tasks/data/datasources/tasks_remote_data_source.dart';
import '../../features/tasks/data/repositories/tasks_repository_impl.dart';
import '../../features/tasks/domain/repositories/tasks_repository.dart';
import '../../features/tasks/domain/usecases/tasks_usecases.dart';
import '../../features/tasks/presentation/bloc/tasks_bloc.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/api/api_data_source.dart';
import '../../utils/workspace_remote_settings.dart';
import '../network/taskboard_api_client.dart';
import '../storage/storage_service.dart';
import '../usecase/usecase.dart';
import '../../services/taskboard_data_source.dart';

final sl = GetIt.instance;

class AppDependencies {
  const AppDependencies({
    required this.dataSource,
    required this.isAuthenticated,
    required this.authChanges,
  });

  final TaskboardDataSource dataSource;

  /// Para el redirect del router (síncrono).
  final bool Function() isAuthenticated;

  /// Emite al iniciar o cerrar sesión.
  final Stream<Object?> authChanges;
}

AppDependencies _appDependencies() {
  final auth = sl<AuthRepository>();
  return AppDependencies(
    dataSource: sl<TaskboardDataSource>(),
    isAuthenticated: () => auth.currentUser != null,
    authChanges: auth.sessionChanges,
  );
}

/// Con [apiUrl] valida contra el API; sin él, modo local de demostración.
void _registerAuthStack(SharedPreferences prefs, {String? apiUrl}) {
  if (apiUrl != null) {
    sl.registerLazySingleton<AuthLocalDataSource>(
      () => AuthLocalDataSourceImpl(prefs),
    );
    sl.registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(baseUrl: apiUrl),
    );
  } else {
    sl.registerLazySingleton<AuthLocalDataSource>(
      () => DemoAuthLocalDataSource(prefs),
    );
  }
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      local: sl<AuthLocalDataSource>(),
      remote: sl.isRegistered<AuthRemoteDataSource>()
          ? sl<AuthRemoteDataSource>()
          : null,
    ),
  );
  AuthRepository repo() => sl<AuthRepository>();
  sl.registerLazySingleton(() => RestoreSession(repo()));
  sl.registerLazySingleton(() => Login(repo()));
  sl.registerLazySingleton(() => Logout(repo()));
  sl.registerLazySingleton(() => ChangePassword(repo()));
  sl.registerFactory(
    () => AuthBloc(
      restoreSession: sl<RestoreSession>(),
      login: sl<Login>(),
      logout: sl<Logout>(),
      changePassword: sl<ChangePassword>(),
    ),
  );
}

void _registerProjectsStack() {
  sl.registerLazySingleton<ProjectsRemoteDataSource>(
    () => ProjectsRemoteDataSourceImpl(sl<TaskboardDataSource>()),
  );
  sl.registerLazySingleton<ProjectsRepository>(
    () => ProjectsRepositoryImpl(sl<ProjectsRemoteDataSource>()),
  );
  ProjectsRepository repo() => sl<ProjectsRepository>();
  sl.registerLazySingleton(() => GetProjects(repo()));
  sl.registerLazySingleton(() => GetProject(repo()));
  sl.registerLazySingleton(() => CreateProject(repo()));
  sl.registerLazySingleton(() => UpdateProject(repo()));
  sl.registerLazySingleton(() => DeleteProject(repo()));
  sl.registerLazySingleton(() => UpdateProjectStatus(repo()));
  sl.registerLazySingleton(() => PreviewWorkspaceSnapshot(repo()));
  sl.registerLazySingleton(() => GetWorkspaceSuggestions(repo()));
  sl.registerLazySingleton(() => ApplyWorkspaceSuggestion(repo()));
  sl.registerLazySingleton(() => DismissWorkspaceSuggestion(repo()));
  sl.registerLazySingleton(() => SyncProjectWorkspace(repo()));
  sl.registerLazySingleton(() => GetWorkspaceInventory(repo()));
  sl.registerLazySingleton(() => ExportTaskboardMd(repo()));
  sl.registerLazySingleton(() => PrepareIdeSession(repo()));
  sl.registerLazySingleton(() => GetProjectMembers(repo()));
  sl.registerLazySingleton(() => GetRegisteredUsers(repo()));
  sl.registerLazySingleton(() => AddProjectMember(repo()));
  sl.registerLazySingleton(() => UpdateProjectMemberRole(repo()));
  sl.registerLazySingleton(() => RemoveProjectMember(repo()));
  sl.registerFactory(
    () => ProjectsBloc(
      getProjects: sl<GetProjects>(),
      createProject: sl<CreateProject>(),
      updateProject: sl<UpdateProject>(),
      deleteProject: sl<DeleteProject>(),
      updateProjectStatus: sl<UpdateProjectStatus>(),
      getProject: sl<GetProject>(),
      previewWorkspaceSnapshot: sl<PreviewWorkspaceSnapshot>(),
      getWorkspaceSuggestions: sl<GetWorkspaceSuggestions>(),
      applyWorkspaceSuggestion: sl<ApplyWorkspaceSuggestion>(),
      dismissWorkspaceSuggestion: sl<DismissWorkspaceSuggestion>(),
      syncProjectWorkspace: sl<SyncProjectWorkspace>(),
      getWorkspaceInventory: sl<GetWorkspaceInventory>(),
      exportTaskboardMd: sl<ExportTaskboardMd>(),
      prepareIdeSession: sl<PrepareIdeSession>(),
      getProjectMembers: sl<GetProjectMembers>(),
      getRegisteredUsers: sl<GetRegisteredUsers>(),
      addProjectMember: sl<AddProjectMember>(),
      updateProjectMemberRole: sl<UpdateProjectMemberRole>(),
      removeProjectMember: sl<RemoveProjectMember>(),
    ),
  );
}

void _registerTasksStack() {
  sl.registerLazySingleton<TasksRemoteDataSource>(
    () => TasksRemoteDataSourceImpl(sl<TaskboardDataSource>()),
  );
  sl.registerLazySingleton<TasksRepository>(
    () => TasksRepositoryImpl(sl<TasksRemoteDataSource>()),
  );
  sl.registerLazySingleton(() => GetTasksByProject(sl<TasksRepository>()));
  sl.registerLazySingleton(() => CreateTask(sl<TasksRepository>()));
  sl.registerLazySingleton(() => UpdateTask(sl<TasksRepository>()));
  sl.registerLazySingleton(() => DeleteTask(sl<TasksRepository>()));
  sl.registerLazySingleton(() => UpdateTaskStatus(sl<TasksRepository>()));
  sl.registerLazySingleton(() => MoveTask(sl<TasksRepository>()));
  sl.registerFactory(
    () => TasksBloc(
      getTasksByProject: sl<GetTasksByProject>(),
      createTask: sl<CreateTask>(),
      updateTask: sl<UpdateTask>(),
      deleteTask: sl<DeleteTask>(),
      updateTaskStatus: sl<UpdateTaskStatus>(),
      moveTask: sl<MoveTask>(),
    ),
  );
}

Future<AppDependencies> configureDependencies(
  StorageService storageService,
) async {
  if (sl.isRegistered<TaskboardDataSource>()) {
    return _appDependencies();
  }

  sl.registerSingleton<StorageService>(storageService);

  const envApi = String.fromEnvironment('TASKBOARD_API_URL');
  const envApiProxy = bool.fromEnvironment(
    'TASKBOARD_API_SAME_ORIGIN_PROXY',
    defaultValue: false,
  );

  final bundled = await storageService.getConfig();
  final wr = bundled.workspaceRemote;
  WorkspaceRemoteSettings.apply(host: wr?.sshHost, user: wr?.sshUser);
  final apiCfg = bundled.taskboardApi;

  var apiUrl = envApi.trim();
  final useApiProxy = envApiProxy || (apiCfg?.useSameOriginProxy ?? false);
  final taskboardFromConfig = apiCfg != null &&
      (apiCfg.baseUrl.trim().isNotEmpty || (useApiProxy && kIsWeb));

  if (apiUrl.isEmpty && taskboardFromConfig) {
    apiUrl = apiCfg.baseUrl.trim();
  }

  final useTaskboardApi = apiUrl.isNotEmpty ||
      (useApiProxy && kIsWeb && apiCfg != null);

  final prefs = storageService.prefs;
  if (prefs == null) {
    throw StateError('StorageService.prefs no disponible');
  }

  late TaskboardDataSource dataSource;

  if (useTaskboardApi) {
    if (useApiProxy && kIsWeb) {
      final raw = apiCfg?.proxyPrefix ?? '/api-taskboard';
      final path = raw.startsWith('/') ? raw : '/$raw';
      apiUrl = Uri.parse(Uri.base.origin).resolve(path).toString();
    }

    _registerAuthStack(prefs, apiUrl: apiUrl);
    final client = TaskboardApiClient(
      baseUrl: apiUrl,
      tokenProvider: sl<AuthLocalDataSource>(),
    );
    AiAssistantService.configureApi(client);

    dataSource = ApiDataSource(client);
  } else {
    _registerAuthStack(prefs);
    AiAssistantService.configureDisabled();
    dataSource = storageService;
  }

  sl.registerSingleton<TaskboardDataSource>(dataSource);

  _registerProjectsStack();
  _registerTasksStack();

  await sl<RestoreSession>()(const NoParams());

  return _appDependencies();
}
