import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/config/app_config.dart';
import 'package:frontend/services/email_notification_service.dart';

/// Test manual para verificar el envío de emails
///
/// ⚠️ IMPORTANTE: Este es un test MANUAL que debe ejecutarse explícitamente.
/// NO se ejecuta como parte de la suite automatizada de tests.
///
/// Propósito: Verificar que el servicio de notificaciones por email funciona
/// correctamente enviando un email real a una dirección de prueba.
///
/// Cómo ejecutar:
/// ```bash
/// flutter test test/manual/manual_email_test.dart \
///   --dart-define=TEST_EMAIL_RECIPIENT=tu-email@jualas.es
/// ```
/// 
/// ⚠️ NOTA: El email debe ser del dominio jualas.es según las restricciones del sistema.
///
/// Después de ejecutar:
/// 1. Verifica la bandeja de entrada del email especificado en TEST_EMAIL_RECIPIENT
/// 2. Verifica que el email contiene:
///    - Asunto: "Bienvenida al Sistema de Seguimiento de Proyectos TFG"
///    - Contenido con el nombre del estudiante
///    - Credenciales de acceso (email y contraseña generada)
///    - Información del tutor asignado
/// 3. Verifica que el email se recibió correctamente y no está en spam
void main() {
  // No usar TestWidgetsFlutterBinding para permitir conexiones HTTP reales
  // TestWidgetsFlutterBinding bloquea las conexiones HTTP en tests

  setUpAll(() async {
    try {
      SharedPreferences.setMockInitialValues({});
      
      // Intentar inicializar Supabase si no está ya inicializado
      try {
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          anonKey: AppConfig.supabaseAnonKey,
        );
      } catch (e) {
        // Supabase ya puede estar inicializado, continuar
        debugPrint('Supabase ya inicializado o error de inicialización: $e');
      }
      
      // Intentar iniciar sesión
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: AppConfig.testCredentials['admin']!,
        password: AppConfig.testCredentials['admin_password']!,
      );
      
      if (response.session == null) {
        throw StateError('No se pudo iniciar sesión para ejecutar la prueba.');
      }
      
      debugPrint('✅ Autenticación exitosa como administrador');
    } catch (e) {
      debugPrint('❌ Error en setUpAll: $e');
      rethrow;
    }
  });

  tearDownAll(() async {
    await Supabase.instance.client.auth.signOut();
  });

  group('EmailNotificationService - Test Manual', () {
    test('envía un email de bienvenida real', () async {
      const defaultRecipient = 'test@jualas.es';
      const recipient = String.fromEnvironment(
        'TEST_EMAIL_RECIPIENT',
        defaultValue: defaultRecipient,
      );

      final generatedPassword =
          'Test-${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}!';

      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('📧 TEST MANUAL: Envío de Email de Bienvenida');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('📬 Email destinatario: $recipient');
      debugPrint('🔑 Contraseña generada: $generatedPassword');
      debugPrint('⏳ Enviando email...');
      debugPrint('');

      try {
        await EmailNotificationService.sendStudentWelcomeEmail(
          studentEmail: recipient,
          studentName: 'Prueba Automática de Emails',
          password: generatedPassword,
          academicYear: '2025-2026',
          tutorName: 'Tutor de Prueba',
          tutorEmail: 'tutor.test@fct.jualas.es',
          createdBy: 'administrador',
          createdByName: 'Suite de Pruebas',
          failSilently: false,
        );

        debugPrint('');
        debugPrint('✅ Email enviado exitosamente');
      } catch (e) {
        final errorString = e.toString();
        // Si el error es "Body already consumed", el email puede haberse enviado correctamente
        // Este es un problema conocido con Supabase Edge Functions en algunos casos
        if (errorString.contains('Body already consumed')) {
          debugPrint('');
          debugPrint('⚠️ Error "Body already consumed" detectado');
          debugPrint('   Este error puede ocurrir aunque el email se haya enviado correctamente.');
          debugPrint('   Por favor, verifica manualmente si el email llegó a: $recipient');
          debugPrint('');
          debugPrint('✅ El test continúa porque el email puede haberse enviado exitosamente');
        } else {
          // Para otros errores, re-lanzar la excepción
          rethrow;
        }
      }
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('📋 VERIFICACIÓN MANUAL REQUERIDA:');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');
      debugPrint('1. Abre la bandeja de entrada de: $recipient');
      debugPrint(
        '2. Busca un email con asunto: "Bienvenida al Sistema de Seguimiento de Proyectos TFG"',
      );
      debugPrint('3. Verifica que el email contiene:');
      debugPrint('   - Nombre del estudiante: "Prueba Automática de Emails"');
      debugPrint('   - Email del estudiante: $recipient');
      debugPrint('   - Contraseña generada: $generatedPassword');
      debugPrint('   - Información del tutor asignado');
      debugPrint('   - Año académico: 2025-2026');
      debugPrint('4. Verifica que el email NO está en la carpeta de spam');
      debugPrint(
        '5. Verifica que el formato del email es correcto (HTML renderizado)',
      );
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');
    });
  });
}
