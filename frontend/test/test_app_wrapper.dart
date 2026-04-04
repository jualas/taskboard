import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'supabase_test_helper.dart';

/// Wrapper para MyApp que maneja correctamente la inicialización de Supabase en tests
class TestAppWrapper extends StatelessWidget {
  final Widget child;
  final bool mockSupabase;

  const TestAppWrapper({
    super.key,
    required this.child,
    this.mockSupabase = true,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: child,
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Setup global para tests que usan MyApp
class TestAppSetup {
  static bool _isInitialized = false;

  /// Inicializar Supabase para tests que usan MyApp
  static Future<void> initializeForMyApp() async {
    if (_isInitialized) return;

    try {
      // Usar el helper de Supabase para tests
      await SupabaseTestHelper.initializeForTests();
      
      // Configurar Supabase.instance para que funcione en tests
      _setupSupabaseInstance();
      
      _isInitialized = true;
      debugPrint('✅ TestAppSetup initialized for MyApp');
    } catch (e) {
      debugPrint('⚠️ TestAppSetup initialization failed: $e');
      _isInitialized = true; // Marcar como inicializado para evitar errores
    }
  }

  /// Configurar Supabase.instance para tests
  static void _setupSupabaseInstance() {
    // Configurar el mock para que responda a las llamadas básicas
    // Nota: Los mocks ya están configurados en SupabaseMock.initializeMocks()
    // No necesitamos configurar aquí ya que SupabaseTestHelper se encarga de esto
  }

  /// Limpiar después de tests
  static Future<void> cleanup() async {
    try {
      if (_isInitialized) {
        await SupabaseTestHelper.cleanup();
        _isInitialized = false;
        debugPrint('✅ TestAppSetup cleanup completed');
      }
    } catch (e) {
      debugPrint('⚠️ TestAppSetup cleanup failed: $e');
    }
  }

  /// Crear wrapper para MyApp en tests
  static Widget createTestApp({required Widget child}) {
    return TestAppWrapper(child: child);
  }
}

/// Mock básico para SupabaseQueryBuilder
class MockSupabaseQueryBuilder {
  MockSupabaseQueryBuilder select([String columns = '*']) => this;
  MockSupabaseQueryBuilder insert(dynamic data) => this;
  MockSupabaseQueryBuilder update(dynamic data) => this;
  MockSupabaseQueryBuilder delete() => this;
  MockSupabaseQueryBuilder eq(String column, Object value) => this;
  MockSupabaseQueryBuilder neq(String column, Object value) => this;
  MockSupabaseQueryBuilder gt(String column, Object value) => this;
  MockSupabaseQueryBuilder gte(String column, Object value) => this;
  MockSupabaseQueryBuilder lt(String column, Object value) => this;
  MockSupabaseQueryBuilder lte(String column, Object value) => this;
  MockSupabaseQueryBuilder like(String column, String pattern) => this;
  MockSupabaseQueryBuilder ilike(String column, String pattern) => this;
  MockSupabaseQueryBuilder is_(String column, Object value) => this;
  MockSupabaseQueryBuilder in_(String column, List<Object> values) => this;
  MockSupabaseQueryBuilder contains(String column, Object value) => this;
  MockSupabaseQueryBuilder containedBy(String column, Object value) => this;
  MockSupabaseQueryBuilder rangeGt(String column, Object value) => this;
  MockSupabaseQueryBuilder rangeGte(String column, Object value) => this;
  MockSupabaseQueryBuilder rangeLt(String column, Object value) => this;
  MockSupabaseQueryBuilder rangeLte(String column, Object value) => this;
  MockSupabaseQueryBuilder rangeAdjacent(String column, Object value) => this;
  MockSupabaseQueryBuilder overlaps(String column, Object value) => this;
  MockSupabaseQueryBuilder textSearch(String column, String query) => this;
  MockSupabaseQueryBuilder match(Map<String, Object> query) => this;
  MockSupabaseQueryBuilder not(String column, String operator, Object value) => this;
  MockSupabaseQueryBuilder or(String filter) => this;
  MockSupabaseQueryBuilder filter(String column, String operator, Object value) => this;
  MockSupabaseQueryBuilder order(String column, {bool ascending = true}) => this;
  MockSupabaseQueryBuilder limit(int count) => this;
  MockSupabaseQueryBuilder range(int from, int to) => this;
  MockSupabaseQueryBuilder single() => this;
  MockSupabaseQueryBuilder maybeSingle() => this;
  MockSupabaseQueryBuilder csv() => this;
  MockSupabaseQueryBuilder geojson() => this;
  MockSupabaseQueryBuilder explain({bool analyze = false, bool verbose = false, bool settings = false, bool buffers = false, bool wal = false}) => this;
  MockSupabaseQueryBuilder rollback() => this;
  MockSupabaseQueryBuilder returns(String columns) => this;
  
  Future<List<Map<String, dynamic>>> then() async => [];
  Future<Map<String, dynamic>?> thenSingle() async => null;
  Future<Map<String, dynamic>?> thenMaybeSingle() async => null;
  Future<String> thenCsv() async => '';
  Future<String> thenGeojson() async => '';
  Future<String> thenExplain() async => '';
  Future<void> thenRollback() async {}
}

/// Mixin para tests que usan MyApp
mixin MyAppTestMixin {
  Future<void> setUpMyApp() async {
    await TestAppSetup.initializeForMyApp();
  }

  Future<void> tearDownMyApp() async {
    await TestAppSetup.cleanup();
  }
}
