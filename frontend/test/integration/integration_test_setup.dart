import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuración para tests de integración
class IntegrationTestSetup {
  static bool _isInitialized = false;
  
  /// Timeout por defecto para operaciones de red en tests (30 segundos)
  static const Duration defaultNetworkTimeout = Duration(seconds: 30);
  
  /// Timeout corto para operaciones rápidas (5 segundos)
  static const Duration shortNetworkTimeout = Duration(seconds: 5);
  
  /// Lista de IDs de recursos creados durante los tests para limpieza
  static final List<String> _createdTestUserIds = [];
  static final List<int> _createdTestAnteprojectIds = [];
  static final List<int> _createdTestTaskIds = [];

  /// Inicializar Supabase para testing
  ///
  /// Usa variables de entorno si están disponibles:
  /// - SUPABASE_URL: URL del proyecto de Supabase (requerida para tests de integración)
  /// - SUPABASE_ANON_KEY: Anon key del proyecto (requerida para tests de integración)
  ///
  /// ⚠️ IMPORTANTE: Para tests de integración con Supabase real, estas variables DEBEN estar configuradas.
  /// Si no están disponibles, se usan valores por defecto para localhost (Supabase local).
  ///
  /// Este método incluye verificación automática de conexión con el backend.
  /// Si el backend no está disponible, lanza un `StateError` con instrucciones claras.
  ///
  /// Ejemplo de uso:
  /// ```bash
  /// flutter test test/integration/auth_integration_test.dart \
  ///   --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \
  ///   --dart-define=SUPABASE_ANON_KEY=tu_clave_anon_key
  /// ```
  static Future<void> initializeSupabase() async {
    if (_isInitialized) {
      // Verificar conexión si ya está inicializado
      final isConnected = await testBackendConnection();
      if (!isConnected) {
        throw StateError(_getBackendUnavailableMessage());
      }
      return;
    }

    try {
      // Intentar obtener desde variables de entorno (para CI/CD o tests con Supabase real)
      const envUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
      const envAnonKey = String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: '',
      );

      // Verificar que las variables de entorno están configuradas
      if (envUrl.isEmpty || envAnonKey.isEmpty) {
        debugPrint(
          '⚠️ Variables de entorno SUPABASE_URL o SUPABASE_ANON_KEY no configuradas',
        );
        debugPrint(
          '   Usando valores por defecto para Supabase local (http://localhost:54321)',
        );
        debugPrint(
          '   Para usar Supabase real, configura las variables con --dart-define',
        );
      }

      // Usar variables de entorno si están disponibles, sino usar valores por defecto (localhost)
      final supabaseUrl = envUrl.isNotEmpty
          ? envUrl
          : 'http://localhost:54321'; // Supabase local por defecto

      final supabaseAnonKey = envAnonKey.isNotEmpty
          ? envAnonKey
          : '***REMOVED***'; // Key de demo por defecto

      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      _isInitialized = true;
      debugPrint('✅ Supabase inicializado para testing');
      debugPrint(
        '   URL: ${envUrl.isNotEmpty ? envUrl : "Localhost (por defecto)"}',
      );
      debugPrint(
        '   Key: ${envAnonKey.isNotEmpty ? "Desde variable de entorno" : "Key de demo (por defecto)"}',
      );

      // Verificar conexión con backend después de inicializar
      debugPrint('🔍 Verificando conexión con backend...');
      final isConnected = await testBackendConnection();
      if (!isConnected) {
        throw StateError(_getBackendUnavailableMessage());
      }
      debugPrint('✅ Conexión con backend verificada exitosamente');
    } catch (e) {
      if (e is StateError) {
        rethrow;
      }
      debugPrint('❌ Error inicializando Supabase: $e');
      throw StateError(
        'Error al inicializar Supabase: $e\n\n${_getBackendUnavailableMessage()}',
      );
    }
  }

  /// Obtener mensaje de error cuando el backend no está disponible
  static String _getBackendUnavailableMessage() {
    const envUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    final isLocalhost = envUrl.isEmpty || envUrl.contains('localhost');

    if (isLocalhost) {
      return '''
❌ Backend no disponible. Los tests de integración requieren conexión con Supabase.

Para iniciar Supabase local:
  1. Asegúrate de tener Docker instalado y ejecutándose
  2. Ejecuta: supabase start
  3. Obtén las credenciales con: supabase status

Para usar Supabase en la nube:
  1. Configura las variables de entorno:
     --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co
     --dart-define=SUPABASE_ANON_KEY=tu_clave_anon_key
  2. Verifica que el proyecto esté activo en el dashboard de Supabase

Ejemplo completo:
  flutter test test/integration/auth_integration_test.dart \\
    --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \\
    --dart-define=SUPABASE_ANON_KEY=tu_clave_anon_key
''';
    } else {
      return '''
❌ Backend no disponible. Los tests de integración requieren conexión con Supabase.

Verifica:
  1. Que las variables SUPABASE_URL y SUPABASE_ANON_KEY estén configuradas correctamente
  2. Que el proyecto de Supabase esté activo en el dashboard
  3. Que tengas conexión a internet
  4. Que las credenciales sean válidas

Ejemplo de ejecución:
  flutter test test/integration/auth_integration_test.dart \\
    --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \\
    --dart-define=SUPABASE_ANON_KEY=tu_clave_anon_key
''';
    }
  }

  /// Limpiar datos de testing creados durante los tests
  ///
  /// Elimina específicamente los datos creados durante la ejecución de tests:
  /// - Usuarios de prueba creados con `createTestUser()`
  /// - Anteproyectos de prueba (si se añaden IDs a `_createdTestAnteprojectIds`)
  /// - Tareas de prueba (si se añaden IDs a `_createdTestTaskIds`)
  ///
  /// ⚠️ IMPORTANTE: Esta función solo limpia datos marcados como de test.
  /// No elimina datos de producción o datos creados manualmente.
  static Future<void> cleanupTestData() async {
    if (!_isInitialized) {
      debugPrint('⚠️ Supabase no inicializado, saltando limpieza');
      return;
    }

    try {
      final client = Supabase.instance.client;
      int cleanedCount = 0;

      // Limpiar tareas de prueba
      for (final taskId in _createdTestTaskIds) {
        try {
          await client
              .from('tasks')
              .delete()
              .eq('id', taskId)
              .timeout(shortNetworkTimeout);
          cleanedCount++;
        } catch (e) {
          debugPrint('⚠️ Error eliminando tarea de prueba $taskId: $e');
        }
      }
      _createdTestTaskIds.clear();

      // Limpiar anteproyectos de prueba
      for (final anteprojectId in _createdTestAnteprojectIds) {
        try {
          // Eliminar relaciones primero
          await client
              .from('anteproject_students')
              .delete()
              .eq('anteproject_id', anteprojectId)
              .timeout(shortNetworkTimeout);

          // Eliminar comentarios
          await client
              .from('anteproject_comments')
              .delete()
              .eq('anteproject_id', anteprojectId)
              .timeout(shortNetworkTimeout);

          // Eliminar el anteproyecto
          await client
              .from('anteprojects')
              .delete()
              .eq('id', anteprojectId)
              .timeout(shortNetworkTimeout);
          cleanedCount++;
        } catch (e) {
          debugPrint(
            '⚠️ Error eliminando anteproyecto de prueba $anteprojectId: $e',
          );
        }
      }
      _createdTestAnteprojectIds.clear();

      // Limpiar usuarios de prueba (requiere admin)
      for (final userId in _createdTestUserIds) {
        try {
          await client.auth.admin
              .deleteUser(userId)
              .timeout(shortNetworkTimeout, onTimeout: () {
            throw TimeoutException(
              'Timeout eliminando usuario de prueba',
              shortNetworkTimeout,
            );
          });
          cleanedCount++;
        } catch (e) {
          debugPrint('⚠️ Error eliminando usuario de prueba $userId: $e');
        }
      }
      _createdTestUserIds.clear();

      if (cleanedCount > 0) {
        debugPrint('✅ Limpieza completada: $cleanedCount recursos eliminados');
      } else {
        debugPrint('✅ No hay datos de prueba para limpiar');
      }
    } catch (e) {
      debugPrint('⚠️ Error general limpiando datos de testing: $e');
      // No relanzar el error para no interrumpir otros tests
    }
  }

  /// Registrar un ID de anteproyecto creado durante los tests para limpieza posterior
  static void registerTestAnteprojectId(int id) {
    if (!_createdTestAnteprojectIds.contains(id)) {
      _createdTestAnteprojectIds.add(id);
    }
  }

  /// Registrar un ID de tarea creada durante los tests para limpieza posterior
  static void registerTestTaskId(int id) {
    if (!_createdTestTaskIds.contains(id)) {
      _createdTestTaskIds.add(id);
    }
  }

  /// Limpiar todos los registros de IDs de test (útil para resetear entre suites)
  static void clearTestIdRegistries() {
    _createdTestUserIds.clear();
    _createdTestAnteprojectIds.clear();
    _createdTestTaskIds.clear();
    debugPrint('✅ Registros de IDs de test limpiados');
  }

  /// Crear usuario de testing
  ///
  /// ⚠️ IMPORTANTE: El email debe ser del dominio `jualas.es` según las restricciones del sistema.
  ///
  /// El usuario creado se registra automáticamente para limpieza posterior.
  ///
  /// Usa un timeout de 30 segundos para la operación de creación.
  static Future<AuthResponse> createTestUser() async {
    try {
      // Crear usuario temporal para testing con dominio jualas.es
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final testEmail = 'test_$timestamp@jualas.es';
      const testPassword = 'TestPassword123!';

      final response = await Supabase.instance.client.auth
          .signUp(
            email: testEmail,
            password: testPassword,
          )
          .timeout(defaultNetworkTimeout);

      // Validar que el usuario se creó correctamente
      if (response.user == null) {
        throw StateError(
          'No se pudo crear el usuario de prueba. Respuesta: $response',
        );
      }

      // Registrar el ID para limpieza posterior
      _createdTestUserIds.add(response.user!.id);

      debugPrint('✅ Usuario de testing creado: ${response.user?.email}');
      return response;
    } catch (e) {
      debugPrint('❌ Error creando usuario de testing: $e');
      debugPrint(
        '   Verifica que el email sea del dominio jualas.es y que las políticas RLS permitan la creación',
      );
      rethrow;
    }
  }

  /// Eliminar usuario de testing
  ///
  /// Usa un timeout de 10 segundos para la operación de eliminación.
  static Future<void> deleteTestUser(String userId) async {
    try {
      await Supabase.instance.client.auth.admin
          .deleteUser(userId)
          .timeout(const Duration(seconds: 10));

      // Remover de la lista de IDs registrados si está presente
      _createdTestUserIds.remove(userId);

      debugPrint('✅ Usuario de testing eliminado: $userId');
    } catch (e) {
      debugPrint('⚠️ Error eliminando usuario de testing: $e');
      // No relanzar el error para no interrumpir otros tests
    }
  }

  /// Verificar conexión con backend
  ///
  /// Verifica que las variables de entorno SUPABASE_URL y SUPABASE_ANON_KEY
  /// están configuradas y que la conexión con Supabase funciona.
  ///
  /// Retorna `true` si la conexión es exitosa, `false` en caso contrario.
  ///
  /// Usa un timeout de 5 segundos para evitar esperas indefinidas.
  static Future<bool> testBackendConnection() async {
    try {
      // Verificar que Supabase está inicializado
      if (!_isInitialized) {
        debugPrint('❌ Supabase no está inicializado');
        return false;
      }

      // Intentar una consulta simple para verificar conexión
      // Usamos una tabla que debería existir (users) con una consulta mínima
      await Supabase.instance.client
          .from('users')
          .select('count')
          .limit(1)
          .timeout(shortNetworkTimeout);

      return true;
    } catch (e) {
      debugPrint('❌ Error de conexión con backend: $e');
      return false;
    }
  }

  /// Sembrar la base de datos con datos de prueba conocidos
  ///
  /// Crea un estado inicial predecible para los tests. Esto es útil para
  /// tests que requieren datos específicos en la base de datos.
  ///
  /// ⚠️ IMPORTANTE: Los datos creados deben limpiarse después de los tests
  /// usando `cleanupTestData()`.
  ///
  /// Retorna un mapa con los IDs de los recursos creados para referencia.
  static Future<Map<String, dynamic>> seedTestData({
    bool createTestUser = false,
    bool createTestAnteproject = false,
    bool createTestTask = false,
  }) async {
    final createdIds = <String, dynamic>{};

    try {
      if (createTestUser) {
        debugPrint('🌱 Sembrando usuario de prueba...');
        final testUser = await IntegrationTestSetup.createTestUser();
        if (testUser.user != null) {
          _createdTestUserIds.add(testUser.user!.id);
          createdIds['testUserId'] = testUser.user!.id;
          createdIds['testUserEmail'] = testUser.user!.email;
          debugPrint('✅ Usuario de prueba creado: ${testUser.user!.email}');
        }
      }

      // Nota: La creación de anteproyectos y tareas requiere autenticación
      // y se debe hacer en los tests individuales si es necesario

      debugPrint('✅ Datos de prueba sembrados exitosamente');
      return createdIds;
    } catch (e) {
      debugPrint('❌ Error sembrando datos de prueba: $e');
      rethrow;
    }
  }
}

/// Mixin para tests de integración
mixin IntegrationTestMixin {
  /// Setup común para tests de integración
  Future<void> setUpIntegrationTest() async {
    await IntegrationTestSetup.initializeSupabase();
    await IntegrationTestSetup.cleanupTestData();
  }

  /// Teardown común para tests de integración
  Future<void> tearDownIntegrationTest() async {
    await IntegrationTestSetup.cleanupTestData();
  }
}
