import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/ai_assistant/data/datasources/ai_assistant_remote_data_source.dart';
import '../../features/ai_assistant/data/repositories/ai_assistant_repository_impl.dart';
import '../../features/ai_assistant/domain/repositories/ai_assistant_repository.dart';
import '../../features/ai_assistant/domain/usecases/ai_assistant_usecases.dart';
import '../../features/ai_assistant/presentation/bloc/project_ai_chat_cubit.dart';
import '../../features/ai_assistant/presentation/bloc/task_ai_suggestion_cubit.dart';
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/auth_usecases.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/projects/data/datasources/projects_api_data_source.dart';
import '../../features/projects/data/datasources/projects_data_source.dart';
import '../../features/projects/data/datasources/projects_local_data_source.dart';
import '../../features/projects/data/repositories/projects_repository_impl.dart';
import '../../features/projects/domain/repositories/projects_repository.dart';
import '../../features/projects/domain/usecases/projects_usecases.dart';
import '../../features/projects/presentation/bloc/projects_bloc.dart';
import '../../features/tasks/data/datasources/tasks_api_data_source.dart';
import '../../features/tasks/data/datasources/tasks_data_source.dart';
import '../../features/tasks/data/datasources/tasks_local_data_source.dart';
import '../../features/tasks/data/repositories/tasks_repository_impl.dart';
import '../../features/tasks/domain/repositories/tasks_repository.dart';
import '../../features/tasks/domain/usecases/tasks_usecases.dart';
import '../../features/tasks/presentation/bloc/tasks_bloc.dart';
import '../network/taskboard_api_client.dart';
import '../storage/storage_service.dart';
import '../config/workspace_remote_settings.dart';
import '../usecase/usecase.dart';

final sl = GetIt.instance;

class AppDependencies {
  const AppDependencies({
    required this.isAuthenticated,
    required this.authChanges,
  });

  /// Para el redirect del router (síncrono).
  final bool Function() isAuthenticated;

  /// Emite al iniciar o cerrar sesión.
  final Stream<Object?> authChanges;
}

AppDependencies _appDependencies() {
  final auth = sl<AuthRepository>();
  return AppDependencies(
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

/// Sin [client] (no hay API Taskboard) proyectos y tareas se guardan en local.
void _registerProjectsStack({TaskboardApiClient? client}) {
  sl.registerLazySingleton<ProjectsDataSource>(
    () => client != null
        ? ProjectsApiDataSource(client)
        : ProjectsLocalDataSource(sl<StorageService>()),
  );
  sl.registerLazySingleton<ProjectsRepository>(
    () => ProjectsRepositoryImpl(sl<ProjectsDataSource>()),
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

void _registerTasksStack({TaskboardApiClient? client}) {
  sl.registerLazySingleton<TasksDataSource>(
    () => client != null
        ? TasksApiDataSource(client)
        : TasksLocalDataSource(sl<StorageService>()),
  );
  sl.registerLazySingleton<TasksRepository>(
    () => TasksRepositoryImpl(sl<TasksDataSource>()),
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

/// Sin [client] (no hay API Taskboard) el asistente queda desactivado.
void _registerAiAssistantStack({TaskboardApiClient? client}) {
  if (client != null) {
    sl.registerLazySingleton<AiAssistantRemoteDataSource>(
      () => AiAssistantRemoteDataSourceImpl(client),
    );
  }
  sl.registerLazySingleton<AiAssistantRepository>(
    () => AiAssistantRepositoryImpl(
      remote: client != null ? sl<AiAssistantRemoteDataSource>() : null,
    ),
  );
  sl.registerLazySingleton(() => SuggestTasks(sl<AiAssistantRepository>()));
  sl.registerLazySingleton(
    () => SuggestProjectPlan(sl<AiAssistantRepository>()),
  );
  sl.registerLazySingleton(
    () => SendProjectChatMessage(sl<AiAssistantRepository>()),
  );
  sl.registerLazySingleton(() => StreamAgentRun(sl<AiAssistantRepository>()));
  sl.registerLazySingleton(() => GetAgentSession(sl<AiAssistantRepository>()));
  sl.registerLazySingleton(
    () => ResetAgentSession(sl<AiAssistantRepository>()),
  );
  sl.registerLazySingleton(() => GetAgentRuns(sl<AiAssistantRepository>()));
  sl.registerLazySingleton(() => ApplyAiTaskSuggestions(sl<CreateTask>()));
  sl.registerFactory(
    () => TaskAiSuggestionCubit(suggestTasks: sl<SuggestTasks>()),
  );
  sl.registerFactory(
    () => ProjectAiChatCubit(
      suggestProjectPlan: sl<SuggestProjectPlan>(),
      sendProjectChatMessage: sl<SendProjectChatMessage>(),
      streamAgentRun: sl<StreamAgentRun>(),
      getAgentSession: sl<GetAgentSession>(),
      resetAgentSession: sl<ResetAgentSession>(),
      getAgentRuns: sl<GetAgentRuns>(),
      applyAiTaskSuggestions: sl<ApplyAiTaskSuggestions>(),
    ),
  );
}

Future<AppDependencies> configureDependencies(
  StorageService storageService,
) async {
  if (sl.isRegistered<StorageService>()) {
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

  TaskboardApiClient? apiClient;

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
    apiClient = client;
  } else {
    _registerAuthStack(prefs);
  }

  _registerProjectsStack(client: apiClient);
  _registerTasksStack(client: apiClient);
  _registerAiAssistantStack(client: apiClient);

  await sl<RestoreSession>()(const NoParams());

  return _appDependencies();
}
