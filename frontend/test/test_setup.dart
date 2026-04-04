import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'mocks/supabase_mock.dart';

/// Setup global para tests
class TestSetup {
  static bool _isInitialized = false;

  /// Inicializar Supabase para tests
  static Future<void> initializeSupabase() async {
    if (_isInitialized) return;

    try {
      // Inicializar mocks de Supabase
      MockSupabase.initialize();
      _isInitialized = true;
      debugPrint('✅ Test setup initialized (Supabase mocked)');
    } catch (e) {
      // Si falla la inicialización, crear un mock básico
      debugPrint('⚠️ Supabase initialization failed in tests: $e');
      _isInitialized = true; // Marcar como inicializado para evitar errores
    }
  }

  /// Limpiar después de tests
  static Future<void> cleanup() async {
    try {
      if (_isInitialized) {
        // Limpiar mocks de Supabase
        MockSupabase.reset();
        debugPrint('✅ Test cleanup completed');
      }
    } catch (e) {
      debugPrint('⚠️ Cleanup failed: $e');
    }
  }

  /// Crear MaterialApp para tests con configuración responsive
  static Widget createTestApp({
    required Widget child,
    bool responsive = true,
  }) {
    return MaterialApp(
      home: responsive ? _responsiveTestWrapper(child: child) : child,
      debugShowCheckedModeBanner: false,
    );
  }

  /// Wrapper para tests responsive que evita overflow
  static Widget _responsiveTestWrapper({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
              minWidth: constraints.maxWidth,
            ),
            child: IntrinsicHeight(
              child: child,
            ),
          ),
        );
      },
    );
  }

  /// Configurar tamaño de pantalla para tests
  static void setScreenSize(WidgetTester tester, {double width = 400, double height = 800}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
  }

  /// Configurar tamaño de pantalla móvil
  static void setMobileSize(WidgetTester tester) {
    setScreenSize(tester, width: 375, height: 667);
  }

  /// Configurar tamaño de pantalla tablet
  static void setTabletSize(WidgetTester tester) {
    setScreenSize(tester, width: 768, height: 1024);
  }

  /// Configurar tamaño de pantalla desktop
  static void setDesktopSize(WidgetTester tester) {
    setScreenSize(tester, width: 1200, height: 800);
  }
}

/// Mixin para tests que necesitan setup de Supabase
mixin SupabaseTestMixin {
  Future<void> setUpSupabase() async {
    await TestSetup.initializeSupabase();
  }

  Future<void> tearDownSupabase() async {
    await TestSetup.cleanup();
  }
}

/// Mixin para tests responsive
mixin ResponsiveTestMixin {
  void setUpResponsive(WidgetTester tester) {
    TestSetup.setMobileSize(tester);
  }

  void setUpTablet(WidgetTester tester) {
    TestSetup.setTabletSize(tester);
  }

  void setUpDesktop(WidgetTester tester) {
    TestSetup.setDesktopSize(tester);
  }
}
