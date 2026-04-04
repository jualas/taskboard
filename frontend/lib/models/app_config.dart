/// Modelo que representa la configuración de la aplicación.
class AppConfig {
  final SupabaseConfig? supabase;
  final TaskboardApiConfig? taskboardApi;

  const AppConfig({this.supabase, this.taskboardApi});

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        supabase: json['supabase'] == null
            ? null
            : SupabaseConfig.fromJson(
                json['supabase'] as Map<String, dynamic>,
              ),
        taskboardApi: json['taskboardApi'] == null
            ? null
            : TaskboardApiConfig.fromJson(
                json['taskboardApi'] as Map<String, dynamic>,
              ),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (supabase != null) 'supabase': supabase!.toJson(),
        if (taskboardApi != null) 'taskboardApi': taskboardApi!.toJson(),
      };
}

/// Configuración (client-safe) para conectar con Supabase desde la app.
class SupabaseConfig {
  final String url;
  final String anonKey;

  /// En web, la app puede usar el origen actual más `proxyPrefix` como URL de Supabase
  /// en lugar de `url`, si `useSameOriginProxy` es true. Evita CORS cuando el edge
  /// devuelve errores sin cabeceras CORS. Nginx debe hacer proxy de esa ruta hacia `url`.
  final bool useSameOriginProxy;

  /// Ruta bajo el mismo host que sirve la app (p. ej. `/supabase`). Debe coincidir con `location` en Nginx.
  final String proxyPrefix;

  const SupabaseConfig({
    required this.url,
    required this.anonKey,
    this.useSameOriginProxy = false,
    this.proxyPrefix = '/supabase',
  });

  factory SupabaseConfig.fromJson(Map<String, dynamic> json) => SupabaseConfig(
        url: json['url'] as String,
        anonKey: json['anonKey'] as String,
        useSameOriginProxy: json['useSameOriginProxy'] as bool? ?? false,
        proxyPrefix: json['proxyPrefix'] as String? ?? '/supabase',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'url': url,
        'anonKey': anonKey,
        'useSameOriginProxy': useSameOriginProxy,
        'proxyPrefix': proxyPrefix,
      };

  bool get isEnabled => url.trim().isNotEmpty && anonKey.trim().isNotEmpty;
}

/// Backend TaskBoard (FastAPI + Postgres). Si está habilitado, sustituye a Supabase.
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
