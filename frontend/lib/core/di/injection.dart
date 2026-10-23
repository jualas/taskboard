import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Listenable;
import 'package:get_it/get_it.dart';

import '../../features/projects/data/datasources/projects_remote_data_source.dart';
import '../../features/projects/data/repositories/projects_repository_impl.dart';
import '../../features/projects/domain/repositories/projects_repository.dart';
import '../../features/projects/domain/usecases/projects_usecases.dart';
import '../../features/tasks/data/datasources/tasks_remote_data_source.dart';
import '../../features/tasks/data/repositories/tasks_repository_impl.dart';
import '../../features/tasks/domain/repositories/tasks_repository.dart';
import '../../features/tasks/domain/usecases/tasks_usecases.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/api/api_data_source.dart';
import '../../services/auth/api_auth_service.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/local_auth_service.dart';
import '../../utils/workspace_remote_settings.dart';
import '../network/taskboard_api_client.dart';
import '../storage/storage_service.dart';
import '../../services/taskboard_data_source.dart';

final sl = GetIt.instance;

class AppDependencies {
  const AppDependencies({
    required this.dataSource,
    required this.authService,
    required this.authRefreshListenable,
  });

  final TaskboardDataSource dataSource;
  final AuthService authService;
  final Listenable? authRefreshListenable;
}

void _registerProjectsStack() {
  sl.registerLazySingleton<ProjectsRemoteDataSource>(
    () => ProjectsRemoteDataSourceImpl(sl<TaskboardDataSource>()),
  );
  sl.registerLazySingleton<ProjectsRepository>(
    () => ProjectsRepositoryImpl(sl<ProjectsRemoteDataSource>()),
  );
  final repo = () => sl<ProjectsRepository>();
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
}

Future<AppDependencies> configureDependencies(
  StorageService storageService,
) async {
  if (sl.isRegistered<TaskboardDataSource>()) {
    Listenable? authRefresh;
    if (sl.isRegistered<Listenable>(instanceName: 'authRefresh')) {
      authRefresh = sl<Listenable>(instanceName: 'authRefresh');
    }
    return AppDependencies(
      dataSource: sl<TaskboardDataSource>(),
      authService: sl<AuthService>(),
      authRefreshListenable: authRefresh,
    );
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

  late TaskboardDataSource dataSource;
  late AuthService authService;
  Listenable? authRefreshListenable;

  if (useTaskboardApi) {
    if (useApiProxy && kIsWeb) {
      final raw = apiCfg?.proxyPrefix ?? '/api-taskboard';
      final path = raw.startsWith('/') ? raw : '/$raw';
      apiUrl = Uri.parse(Uri.base.origin).resolve(path).toString();
    }

    final prefs = storageService.prefs;
    if (prefs == null) {
      throw StateError('StorageService.prefs no disponible');
    }
    final apiAuth = ApiAuthService(baseUrl: apiUrl, prefs: prefs);
    await apiAuth.init();

    final client = TaskboardApiClient(
      baseUrl: apiUrl,
      accessTokenProvider: () => apiAuth.accessToken,
    );
    AiAssistantService.configureApi(client);

    dataSource = ApiDataSource(client);
    authService = apiAuth;
    authRefreshListenable = apiAuth;
  } else {
    final prefs = storageService.prefs;
    if (prefs == null) {
      throw StateError('StorageService.prefs no disponible');
    }
    AiAssistantService.configureDisabled();
    dataSource = storageService;
    authService = LocalAuthService(prefs);
    authRefreshListenable = null;
  }

  sl.registerSingleton<TaskboardDataSource>(dataSource);
  sl.registerSingleton<AuthService>(authService);
  if (authRefreshListenable != null) {
    sl.registerSingleton<Listenable>(
      authRefreshListenable,
      instanceName: 'authRefresh',
    );
  }

  _registerProjectsStack();
  _registerTasksStack();

  return AppDependencies(
    dataSource: dataSource,
    authService: authService,
    authRefreshListenable: authRefreshListenable,
  );
}
