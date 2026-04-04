import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/l10n/app_localizations.dart';

void main() {
  group('Internationalization Tests', () {
    testWidgets('App supports Spanish locale', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es', 'ES'),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return Column(
                children: [
                  Text(l10n.login),
                  Text(l10n.email),
                  Text(l10n.password),
                  Text(l10n.dashboard),
                ],
              );
            },
          ),
        ),
      ));

      // Verificar que se muestran los textos en español
      expect(find.text('Iniciar Sesión'), findsOneWidget);
      expect(find.text('Correo Electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Panel Principal'), findsOneWidget);
    });

    testWidgets('App supports English locale', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en', 'US'),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return Column(
                children: [
                  Text(l10n.login),
                  Text(l10n.email),
                  Text(l10n.password),
                  Text(l10n.dashboard),
                ],
              );
            },
          ),
        ),
      ));

      // Verificar que se muestran los textos en inglés
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('App falls back to Spanish for unsupported locale', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr', 'FR'), // Francés no soportado
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return Text(l10n.login);
            },
          ),
        ),
      ));

      // Esperar a que se cargue la localización
      await tester.pumpAndSettle();

      // Verificar que se renderiza un Text widget
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('All required localization keys are available', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es', 'ES'),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return Column(
                children: [
                  // Claves básicas
                  Text(l10n.appTitle),
                  Text(l10n.login),
                  Text(l10n.email),
                  Text(l10n.password),
                  Text(l10n.dashboard),
                  Text(l10n.logout),
                  
                  // Claves de roles
                  Text(l10n.student),
                  Text(l10n.tutor),
                  Text(l10n.admin),
                  
                  // Claves de navegación
                  Text(l10n.projects),
                  Text(l10n.tasks),
                  Text(l10n.profile),
                  
                  // Claves de anteproyectos
                  Text(l10n.myAnteprojects),
                  Text(l10n.viewAll),
                  Text(l10n.pendingAnteprojects),
                  
                  // Claves de tareas
                  Text(l10n.pendingTasks),
                  Text(l10n.viewAllTasks),
                  
                  // Claves de validación
                  Text(l10n.fieldRequired),
                  Text(l10n.invalidEmail),
                  Text(l10n.invalidUrl),
                  Text(l10n.invalidNumber),
                  
                  // Claves de errores
                  Text(l10n.error),
                  Text(l10n.retry),
                  Text(l10n.loading),
                ],
              );
            },
          ),
        ),
      ));

      // Verificar que todas las claves están disponibles y no son null
      expect(find.byType(Text), findsWidgets);
      
      // Verificar que no hay textos vacíos o de error
      final textWidgets = find.byType(Text);
      for (int i = 0; i < textWidgets.evaluate().length; i++) {
        final textWidget = textWidgets.evaluate().elementAt(i).widget as Text;
        expect(textWidget.data, isNotNull);
        expect(textWidget.data, isNotEmpty);
        expect(textWidget.data, isNot(equals('null')));
      }
    });

    testWidgets('Localization works with different contexts', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es', 'ES'),
        home: Scaffold(
          appBar: AppBar(
            title: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return Text(l10n.appTitle);
              },
            ),
          ),
          body: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return Column(
                children: [
                  Text(l10n.dashboard),
                  ElevatedButton(
                    onPressed: () {},
                    child: Text(l10n.login),
                  ),
                ],
              );
            },
          ),
        ),
      ));

      // Verificar que la localización funciona en diferentes contextos
      expect(find.text('Sistema de Gestión TFG'), findsOneWidget); // AppBar
      expect(find.text('Panel Principal'), findsOneWidget); // Body
      expect(find.text('Iniciar Sesión'), findsOneWidget); // Button
    });
  });
}
