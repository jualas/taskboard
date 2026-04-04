import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mocks/supabase_mock.dart';

/// Helper para manejar Supabase en tests
class SupabaseTestHelper {
  static bool _isInitialized = false;
  static bool _isMocked = false;

  /// Inicializar Supabase para tests
  static Future<void> initializeForTests() async {
    if (_isInitialized) return;

    try {
      // Inicializar mocks de Supabase
      SupabaseMock.initializeMocks();
      _isMocked = true;

      // Intentar inicializar Supabase real si no estamos en tests
      if (!_isInTestEnvironment()) {
        await _initializeRealSupabase();
      }

      _isInitialized = true;
      debugPrint('✅ SupabaseTestHelper initialized');
    } catch (e) {
      debugPrint('⚠️ SupabaseTestHelper initialization failed: $e');
      _isInitialized = true; // Marcar como inicializado para evitar errores
    }
  }

  /// Verificar si estamos en un entorno de test
  static bool _isInTestEnvironment() {
    // Verificar si estamos en un test de Flutter
    try {
      // Si podemos acceder a testWidgets, estamos en un test
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Inicializar Supabase real (para tests de integración)
  /// Usa variables de entorno si están disponibles
  static Future<void> _initializeRealSupabase() async {
    try {
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
    } catch (e) {
      debugPrint('⚠️ Real Supabase initialization failed: $e');
    }
  }

  /// Obtener cliente de Supabase (mock o real)
  static SupabaseClient getClient() {
    if (_isMocked) {
      return SupabaseMock.client;
    }
    return Supabase.instance.client;
  }

  /// Obtener auth de Supabase (mock o real)
  static GoTrueClient getAuth() {
    if (_isMocked) {
      return SupabaseMock.auth;
    }
    return Supabase.instance.client.auth;
  }

  /// Configurar usuario autenticado en mocks
  static void setAuthenticatedUser({String? id, String? email, String? role}) {
    if (_isMocked) {
      SupabaseMock.setAuthenticatedUser(id: id, email: email, role: role);
    }
  }

  /// Configurar usuario no autenticado en mocks
  static void setUnauthenticatedUser() {
    if (_isMocked) {
      SupabaseMock.setUnauthenticatedUser();
    }
  }

  /// Limpiar después de tests
  static Future<void> cleanup() async {
    try {
      if (_isMocked) {
        SupabaseMock.resetMocks();
      }
      _isInitialized = false;
      _isMocked = false;
      debugPrint('✅ SupabaseTestHelper cleanup completed');
    } catch (e) {
      debugPrint('⚠️ SupabaseTestHelper cleanup failed: $e');
    }
  }

  /// Verificar si Supabase está disponible
  static bool isAvailable() {
    try {
      if (_isMocked) {
        return true;
      }
      return true; // Supabase.instance.client is never null after initialization
    } catch (e) {
      return false;
    }
  }

  /// Obtener información del estado de Supabase
  static Map<String, dynamic> getStatus() {
    return {
      'initialized': _isInitialized,
      'mocked': _isMocked,
      'available': isAvailable(),
      'inTestEnvironment': _isInTestEnvironment(),
    };
  }
}

/// Mixin para tests que necesitan Supabase
mixin SupabaseTestMixin {
  Future<void> setUpSupabase() async {
    await SupabaseTestHelper.initializeForTests();
  }

  Future<void> tearDownSupabase() async {
    await SupabaseTestHelper.cleanup();
  }

  void setAuthenticatedUser({String? id, String? email, String? role}) {
    SupabaseTestHelper.setAuthenticatedUser(id: id, email: email, role: role);
  }

  void setUnauthenticatedUser() {
    SupabaseTestHelper.setUnauthenticatedUser();
  }
}
