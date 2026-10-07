/// Modelo que representa la configuración de la aplicación.
class AppConfig {
  final TaskboardApiConfig? taskboardApi;
  final WorkspaceRemoteConfig? workspaceRemote;

  const AppConfig({this.taskboardApi, this.workspaceRemote});

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        taskboardApi: json['taskboardApi'] == null
            ? null
            : TaskboardApiConfig.fromJson(
                json['taskboardApi'] as Map<String, dynamic>,
              ),
        workspaceRemote: json['workspaceRemote'] == null
            ? null
            : WorkspaceRemoteConfig.fromJson(
                json['workspaceRemote'] as Map<String, dynamic>,
              ),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (taskboardApi != null) 'taskboardApi': taskboardApi!.toJson(),
        if (workspaceRemote != null) 'workspaceRemote': workspaceRemote!.toJson(),
      };
}

/// Mini PC para Remote SSH desde el portátil (misma LAN).
class WorkspaceRemoteConfig {
  final String sshHost;
  final String sshUser;

  const WorkspaceRemoteConfig({
    this.sshHost = '',
    this.sshUser = '',
  });

  factory WorkspaceRemoteConfig.fromJson(Map<String, dynamic> json) =>
      WorkspaceRemoteConfig(
        sshHost: json['sshHost'] as String? ?? '',
        sshUser: json['sshUser'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sshHost': sshHost,
        'sshUser': sshUser,
      };
}

/// Backend TaskBoard (FastAPI + Postgres).
class TaskboardApiConfig {
  final String baseUrl;

  /// En web, usar el origen actual + [proxyPrefix] como base del API (evita CORS).
  final bool useSameOriginProxy;

  final String proxyPrefix;

  const TaskboardApiConfig({
    required this.baseUrl,
    this.useSameOriginProxy = false,
    this.proxyPrefix = '/api-taskboard',
  });

  factory TaskboardApiConfig.fromJson(Map<String, dynamic> json) =>
      TaskboardApiConfig(
        baseUrl: json['baseUrl'] as String? ?? '',
        useSameOriginProxy: json['useSameOriginProxy'] as bool? ?? false,
        proxyPrefix: json['proxyPrefix'] as String? ?? '/api-taskboard',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'baseUrl': baseUrl,
        'useSameOriginProxy': useSameOriginProxy,
        'proxyPrefix': proxyPrefix,
      };

  /// Coincide con la lógica de [main]: web puede usar solo proxy sin `baseUrl`.
  bool get isEnabled => baseUrl.trim().isNotEmpty || useSameOriginProxy;
}
