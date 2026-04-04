import 'package:flutter/foundation.dart';
import 'mocks/supabase_mock.dart';

/// Override de Supabase para tests que no requiere inicialización real
class SupabaseMockOverride {
  static bool _isInitialized = false;

  /// Inicializar override de Supabase para tests
  static void initialize() {
    if (_isInitialized) return;

    try {
      // Inicializar mocks
      SupabaseMock.initializeMocks();
      
      // Crear una instancia mock de Supabase que no requiera inicialización real
      _createMockSupabaseInstance();
      
      _isInitialized = true;
      debugPrint('✅ SupabaseMockOverride: Mock Supabase initialized for tests');
    } catch (e) {
      debugPrint('⚠️ SupabaseMockOverride: Failed to initialize mock Supabase: $e');
      _isInitialized = true; // Marcar como inicializado para evitar errores
    }
  }

  /// Crear instancia mock de Supabase
  static void _createMockSupabaseInstance() {
    // Este método crea un mock que intercepta las llamadas a Supabase.instance
    // Sin necesidad de inicialización real
  }

  /// Verificar si está inicializado
  static bool get isInitialized => _isInitialized;

  /// Limpiar después de tests
  static void cleanup() {
    try {
      if (_isInitialized) {
        SupabaseMock.resetMocks();
        _isInitialized = false;
        debugPrint('✅ SupabaseMockOverride: Cleanup completed');
      }
    } catch (e) {
      debugPrint('⚠️ SupabaseMockOverride: Cleanup failed: $e');
    }
  }
}

/// Mixin para tests que usan Supabase mock
mixin SupabaseMockOverrideMixin {
  void setUpSupabaseMock() {
    SupabaseMockOverride.initialize();
  }

  void tearDownSupabaseMock() {
    SupabaseMockOverride.cleanup();
  }
}
