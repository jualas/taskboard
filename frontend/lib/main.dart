import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/blocs.dart';
import 'services/services.dart';
import 'services/taskboard_data_source.dart';
import 'services/api/api_data_source.dart';
import 'services/api/taskboard_api_client.dart';
import 'services/ai_assistant_service.dart';
import 'router/app_router.dart';
import 'themes/app_theme.dart';
import 'ui/root_scaffold_messenger.dart';
import 'utils/workspace_remote_settings.dart';

class _AppBootstrap {
  const _AppBootstrap({
    required this.dataSource,
    required this.authService,
    this.authRefreshListenable,
  });

  final TaskboardDataSource dataSource;
  final AuthService authService;
  final Listenable? authRefreshListenable;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final boot = await _initBootstrap(storageService);

  final projectsService = ProjectsService(boot.dataSource);
  final tasksService = TasksService(boot.dataSource);

  runApp(
    TaskBoardApp(
      storageService: storageService,
      authService: boot.authService,
      authRefreshListenable: boot.authRefreshListenable,
      projectsService: projectsService,
      tasksService: tasksService,
    ),
  );
}

Future<_AppBootstrap> _initBootstrap(StorageService storageService) async {
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

    return _AppBootstrap(
      dataSource: ApiDataSource(client),
      authService: apiAuth,
      authRefreshListenable: apiAuth,
    );
  }

  final prefs = storageService.prefs;
  if (prefs == null) {
    throw StateError('StorageService.prefs no disponible');
  }
  AiAssistantService.configureDisabled();
  return _AppBootstrap(
    dataSource: storageService,
    authService: LocalAuthService(prefs),
    authRefreshListenable: null,
  );
}

class TaskBoardApp extends StatefulWidget {
  final StorageService storageService;
  final AuthService authService;
  final Listenable? authRefreshListenable;
  final ProjectsService projectsService;
  final TasksService tasksService;

  const TaskBoardApp({
    super.key,
    required this.storageService,
    required this.authService,
    required this.authRefreshListenable,
    required this.projectsService,
    required this.tasksService,
  });

  @override
  State<TaskBoardApp> createState() => _TaskBoardAppState();
}

class _TaskBoardAppState extends State<TaskBoardApp> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(
      authService: widget.authService,
      authRefreshListenable: widget.authRefreshListenable,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              AuthBloc(authService: widget.authService)
                ..add(AuthCheckRequested()),
        ),
        BlocProvider(
          create: (_) => ProjectsBloc(projectsService: widget.projectsService),
        ),
        BlocProvider(create: (_) => TasksBloc(tasksService: widget.tasksService)),
      ],
      child: MaterialApp.router(
        title: 'TaskBoard Personal',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        scaffoldMessengerKey: kRootScaffoldMessenger,
        routerConfig: _appRouter.router,
      ),
    );
  }
}
