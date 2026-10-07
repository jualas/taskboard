import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Utilidades comunes para tests (sin backend externo).
class TestSetup {
  static bool _isInitialized = false;

  static Future<void> initializeTests() async {
    if (_isInitialized) return;
    _isInitialized = true;
    debugPrint('✅ Test setup inicializado');
  }

  static Future<void> cleanup() async {}

  static Widget createTestApp({
    required Widget child,
    bool responsive = true,
  }) {
    return MaterialApp(
      home: responsive ? _responsiveTestWrapper(child: child) : child,
      debugShowCheckedModeBanner: false,
    );
  }

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

  static void setScreenSize(WidgetTester tester, {double width = 400, double height = 800}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
  }

  static void setMobileSize(WidgetTester tester) {
    setScreenSize(tester, width: 375, height: 667);
  }

  static void setTabletSize(WidgetTester tester) {
    setScreenSize(tester, width: 768, height: 1024);
  }

  static void setDesktopSize(WidgetTester tester) {
    setScreenSize(tester, width: 1200, height: 800);
  }
}

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
