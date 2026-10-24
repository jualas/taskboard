import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/blocs.dart';
import 'core/di/injection.dart';
import 'services/services.dart';
import 'shared/router/app_router.dart';
import 'shared/themes/app_theme.dart';
import 'shared/ui/root_scaffold_messenger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final deps = await configureDependencies(storageService);

  runApp(
    TaskBoardApp(
      isAuthenticated: deps.isAuthenticated,
      authChanges: deps.authChanges,
    ),
  );
}

class TaskBoardApp extends StatefulWidget {
  final bool Function() isAuthenticated;
  final Stream<Object?> authChanges;

  const TaskBoardApp({
    super.key,
    required this.isAuthenticated,
    required this.authChanges,
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
      isAuthenticated: widget.isAuthenticated,
      authChanges: widget.authChanges,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<AuthBloc>()..add(AuthCheckRequested()),
        ),
        BlocProvider(create: (_) => sl<ProjectsBloc>()),
        BlocProvider(create: (_) => sl<TasksBloc>()),
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
