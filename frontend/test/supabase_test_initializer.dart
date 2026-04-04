import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mocks/supabase_mock.dart';

/// Inicializador de Supabase para tests
class SupabaseTestInitializer {
  static bool _isInitialized = false;

  /// Inicializar Supabase para tests
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Inicializar mocks primero
      SupabaseMock.initializeMocks();

      // Inicializar Supabase real con configuración de test
      // Usar variables de entorno si están disponibles
      const envUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
      const envAnonKey = String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: '',
      );

      final supabaseUrl = envUrl.isNotEmpty ? envUrl : 'http://localhost:54321';

      final supabaseAnonKey = envAnonKey.isNotEmpty
          ? envAnonKey
          : '***REMOVED***';

      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

      _isInitialized = true;
      debugPrint('✅ SupabaseTestInitializer: Supabase initialized for tests');
    } catch (e) {
      debugPrint(
        '⚠️ SupabaseTestInitializer: Failed to initialize Supabase: $e',
      );
      // Continuar sin Supabase para tests que no lo necesiten
      _isInitialized = true;
    }
  }

  /// Verificar si está inicializado
  static bool get isInitialized => _isInitialized;

  /// Limpiar después de tests
  static Future<void> cleanup() async {
    try {
      if (_isInitialized) {
        SupabaseMock.resetMocks();
        _isInitialized = false;
        debugPrint('✅ SupabaseTestInitializer: Cleanup completed');
      }
    } catch (e) {
      debugPrint('⚠️ SupabaseTestInitializer: Cleanup failed: $e');
    }
  }
}

/// Mixin para tests que necesitan Supabase inicializado
mixin SupabaseTestInitializerMixin {
  Future<void> setUpSupabase() async {
    await SupabaseTestInitializer.initialize();
  }

  Future<void> tearDownSupabase() async {
    await SupabaseTestInitializer.cleanup();
  }
}
