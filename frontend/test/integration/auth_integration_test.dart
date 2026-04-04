import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/utils/app_exception.dart';
import 'integration_test_setup.dart';

/// Tests de integración para autenticación
///
/// ⚠️ REQUISITOS:
/// - Variables de entorno SUPABASE_URL y SUPABASE_ANON_KEY deben estar configuradas
/// - Usuario de prueba debe tener email del dominio jualas.es
///
/// Ejemplo de ejecución:
/// ```bash
/// flutter test test/integration/auth_integration_test.dart \
///   --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=tu_clave_anon_key \
///   --dart-define=TEST_USER_EMAIL=usuario@jualas.es \
///   --dart-define=TEST_USER_PASSWORD=password123
/// ```
void main() {
  group('Auth Integration Tests', () {
    late AuthService authService;
    late String testUserId;

    setUpAll(() async {
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🚀 Iniciando tests de integración de autenticación');
      debugPrint('═══════════════════════════════════════════════════════════');
      
      // Inicializar Supabase usando variables de entorno
      // initializeSupabase() ahora incluye verificación automática de conexión
      // y lanzará StateError si el backend no está disponible
      await IntegrationTestSetup.initializeSupabase();
      
      debugPrint('✅ Setup completado. Iniciando tests...');
      debugPrint('');
    });

    setUp(() async {
      authService = AuthService();
      await IntegrationTestSetup.cleanupTestData();
    });

    tearDown(() async {
      if (testUserId.isNotEmpty) {
        await IntegrationTestSetup.deleteTestUser(testUserId);
      }
      await IntegrationTestSetup.cleanupTestData();
    });

    test('Backend connection is working', () async {
      final isConnected = await IntegrationTestSetup.testBackendConnection();
      expect(
        isConnected,
        isTrue,
        reason:
            'Backend debe estar disponible. Verifica SUPABASE_URL y SUPABASE_ANON_KEY',
      );
    });

    test('Can create and authenticate test user', () async {
      // CORRECCIÓN: Sin try-catch - si falla, el test debe fallar
      // Crear usuario de testing (con dominio jualas.es)
      final testUser = await IntegrationTestSetup.createTestUser();
      expect(
        testUser.user,
        isNotNull,
        reason: 'Usuario de prueba debe ser creado correctamente',
      );
      expect(
        testUser.user!.email,
        contains('@jualas.es'),
        reason: 'Usuario debe tener email del dominio jualas.es',
      );

      testUserId = testUser.user!.id;

      // Verificar que el usuario se creó correctamente
      final isAuthenticated = authService.isAuthenticated;
      expect(
        isAuthenticated,
        isTrue,
        reason: 'Usuario debe estar autenticado después de la creación',
      );
    });

    test('Can sign in with existing credentials', () async {
      // CORRECCIÓN: Sin try-catch - si falla, el test debe fallar
      // Usar credenciales de prueba desde variables de entorno o valores por defecto
      // Configurar con: --dart-define=TEST_USER_EMAIL=... --dart-define=TEST_USER_PASSWORD=...
      const testEmail = String.fromEnvironment(
        'TEST_USER_EMAIL',
        defaultValue: 'carlos.lopez@jualas.es',
      );
      const testPassword = String.fromEnvironment(
        'TEST_USER_PASSWORD',
        defaultValue: 'password123',
      );

      final response = await authService.signIn(
        email: testEmail,
        password: testPassword,
      );

      expect(
        response['success'],
        isTrue,
        reason: 'Sign in debe ser exitoso con credenciales válidas',
      );
      expect(
        response['user'],
        isNotNull,
        reason: 'Respuesta debe contener información del usuario',
      );
      expect(
        response['user']['email'],
        equals(testEmail),
        reason: 'Email del usuario en la respuesta debe coincidir',
      );

      // Verificar estado de autenticación
      expect(
        authService.isAuthenticated,
        isTrue,
        reason: 'Usuario debe estar autenticado después de sign in',
      );

      // Verificar que se puede obtener el perfil del usuario
      final userProfile = await authService.getCurrentUserProfile();
      expect(
        userProfile,
        isNotNull,
        reason: 'Debe ser posible obtener el perfil del usuario autenticado',
      );
      expect(
        userProfile!.email,
        equals(testEmail),
        reason: 'Email del perfil debe coincidir con el proporcionado',
      );
    });

    test('Can sign out successfully', () async {
      // CORRECCIÓN: Sin try-catch - si falla, el test debe fallar
      // Primero hacer sign in con credenciales desde variables de entorno
      const testEmail = String.fromEnvironment(
        'TEST_USER_EMAIL',
        defaultValue: 'carlos.lopez@jualas.es',
      );
      const testPassword = String.fromEnvironment(
        'TEST_USER_PASSWORD',
        defaultValue: 'password123',
      );

      await authService.signIn(email: testEmail, password: testPassword);

      // Verificar que está autenticado
      expect(
        authService.isAuthenticated,
        isTrue,
        reason: 'Usuario debe estar autenticado después de sign in',
      );

      // Hacer sign out
      await authService.signOut();

      // Verificar que ya no está autenticado
      expect(
        authService.isAuthenticated,
        isFalse,
        reason: 'Usuario no debe estar autenticado después de sign out',
      );
    });

    test('Can check user roles', () async {
      // CORRECCIÓN: Sin try-catch - si falla, el test debe fallar
      const testEmail = String.fromEnvironment(
        'TEST_USER_EMAIL',
        defaultValue: 'carlos.lopez@jualas.es',
      );
      const testPassword = String.fromEnvironment(
        'TEST_USER_PASSWORD',
        defaultValue: 'password123',
      );

      // Hacer sign in
      await authService.signIn(email: testEmail, password: testPassword);

      // Verificar roles
      final isStudent = await authService.isStudent;
      final isTutor = await authService.isTutor;
      final isAdmin = await authService.isAdmin;

      // Al menos uno debe ser true
      expect(
        isStudent || isTutor || isAdmin,
        isTrue,
        reason: 'Usuario debe tener al menos un rol asignado (student, tutor o admin)',
      );

      // Limpiar
      await authService.signOut();
    });

    test('Auth state changes stream works', () async {
      // Verificar que el stream está disponible
      expect(
        authService.authStateChanges,
        isA<Stream<AuthState>>(),
        reason: 'AuthService debe proporcionar un stream de cambios de estado',
      );

      // Escuchar cambios de estado
      final states = <AuthState>[];
      final subscription = authService.authStateChanges.listen(states.add);

      // Esperar un poco para capturar el estado inicial
      await Future.delayed(const Duration(milliseconds: 100));

      // Verificar que se recibió al menos un estado
      expect(
        states.isNotEmpty,
        isTrue,
        reason: 'Stream debe emitir al menos el estado inicial',
      );

      // Limpiar
      await subscription.cancel();
    });

    test('Sign in with invalid credentials throws exception', () async {
      // CORRECCIÓN: Test de caso de fallo - credenciales inválidas
      const invalidEmail = 'invalid.user@jualas.es';
      const invalidPassword = 'wrongpassword123';

      // Intentar sign in con credenciales inválidas
      // Debe lanzar una excepción de autenticación
      expect(
        () async => await authService.signIn(
          email: invalidEmail,
          password: invalidPassword,
        ),
        throwsA(isA<AuthenticationException>()),
        reason:
            'Sign in con credenciales inválidas debe lanzar AuthenticationException',
      );

      // Verificar que el usuario NO está autenticado después del fallo
      expect(
        authService.isAuthenticated,
        isFalse,
        reason: 'Usuario no debe estar autenticado después de fallo de sign in',
      );
    });

    test('Sign in with wrong password throws exception', () async {
      // CORRECCIÓN: Test de caso de fallo - contraseña incorrecta
      const testEmail = String.fromEnvironment(
        'TEST_USER_EMAIL',
        defaultValue: 'carlos.lopez@jualas.es',
      );
      const wrongPassword = 'wrongpassword123';

      // Intentar sign in con email válido pero contraseña incorrecta
      expect(
        () async => await authService.signIn(
          email: testEmail,
          password: wrongPassword,
        ),
        throwsA(isA<AuthenticationException>()),
        reason:
            'Sign in con contraseña incorrecta debe lanzar AuthenticationException',
      );

      // Verificar que el usuario NO está autenticado
      expect(
        authService.isAuthenticated,
        isFalse,
        reason:
            'Usuario no debe estar autenticado después de contraseña incorrecta',
      );
    });

    test('Sign in with non-existent email throws exception', () async {
      // CORRECCIÓN: Test de caso de fallo - email inexistente
      const nonExistentEmail = 'nonexistent.user@jualas.es';
      const anyPassword = 'anypassword123';

      // Intentar sign in con email que no existe
      expect(
        () async => await authService.signIn(
          email: nonExistentEmail,
          password: anyPassword,
        ),
        throwsA(isA<AuthenticationException>()),
        reason:
            'Sign in con email inexistente debe lanzar AuthenticationException',
      );

      // Verificar que el usuario NO está autenticado
      expect(
        authService.isAuthenticated,
        isFalse,
        reason:
            'Usuario no debe estar autenticado después de email inexistente',
      );
    });
  });
}
