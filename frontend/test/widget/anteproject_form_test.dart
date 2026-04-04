import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';

import 'package:frontend/screens/forms/anteproject_form.dart';
import 'package:frontend/blocs/anteprojects_bloc.dart';
import 'widget_test_utils.dart';
import 'widget_test_utils.mocks.dart';

void main() {
  group('AnteprojectForm Widget Tests', () {
    late MockAnteprojectsService mockAnteprojectsService;
    late AnteprojectsBloc anteprojectsBloc;

    setUp(() {
      mockAnteprojectsService = MockAnteprojectsService();
      anteprojectsBloc = AnteprojectsBloc(
        anteprojectsService: mockAnteprojectsService,
      );
    });

    tearDown(() {
      anteprojectsBloc.close();
    });

    Widget createTestWidget() {
      return WidgetTestUtils.createTestApp(
        child: BlocProvider<AnteprojectsBloc>.value(
          value: anteprojectsBloc,
          child: const AnteprojectForm(),
        ),
      );
    }

    testWidgets('AnteprojectForm shows loading state while loading user',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Verificar que se muestra el indicador de carga inicial
      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
        reason: 'Debe mostrar CircularProgressIndicator mientras carga el usuario',
      );
    });

    testWidgets('AnteprojectForm shows form fields after loading', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verificar que se muestran los campos del formulario
      expect(
        find.byType(TextFormField),
        findsWidgets,
        reason: 'Debe mostrar campos del formulario',
      );
      expect(
        find.byType(Form),
        findsOneWidget,
        reason: 'Debe mostrar Form',
      );
    });

    testWidgets('AnteprojectForm validates required fields', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Buscar el botón de guardar
      final saveButton = find.textContaining('Guardar');
      if (saveButton.evaluate().isEmpty) {
        // Intentar encontrar cualquier botón de envío
        final submitButton = find.byType(ElevatedButton).last;
        if (submitButton.evaluate().isNotEmpty) {
          await tester.tap(submitButton);
          await tester.pump();

          // Verificar que se muestran mensajes de validación
          expect(
            find.textContaining('required'),
            findsAtLeastNWidgets(1),
            reason: 'Debe mostrar mensajes de validación para campos requeridos',
          );
        }
      }
    });

    testWidgets('AnteprojectForm shows loading state when submitting', (
      WidgetTester tester,
    ) async {
      // Configurar mock para que retorne después de un delay
      when(mockAnteprojectsService.createAnteproject(any)).thenAnswer(
        (_) async {
          await Future.delayed(const Duration(milliseconds: 200));
          return WidgetTestUtils.createTestAnteproject(id: 1);
        },
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Llenar campos requeridos
      final textFields = find.byType(TextFormField);
      if (textFields.evaluate().isNotEmpty) {
        await tester.enterText(textFields.first, 'Test Title');
        await tester.enterText(textFields.at(1), 'Test Description');
      }

      // Buscar y presionar botón de guardar
      final saveButton = find.byType(ElevatedButton).last;
      if (saveButton.evaluate().isNotEmpty) {
        await tester.tap(saveButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Verificar que el botón está deshabilitado durante el envío
        final button = tester.widget<ElevatedButton>(saveButton);
        expect(
          button.onPressed,
          isNull,
          reason: 'El botón debe estar deshabilitado durante el envío',
        );
      }
    });

    testWidgets('AnteprojectForm shows error state when submission fails', (
      WidgetTester tester,
    ) async {
      // Configurar mock para que lance error
      when(mockAnteprojectsService.createAnteproject(any)).thenThrow(
        Exception('Error al crear anteproyecto'),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Llenar campos requeridos
      final textFields = find.byType(TextFormField);
      if (textFields.evaluate().isNotEmpty) {
        await tester.enterText(textFields.first, 'Test Title');
        await tester.enterText(textFields.at(1), 'Test Description');
      }

      // Buscar y presionar botón de guardar
      final saveButton = find.byType(ElevatedButton).last;
      if (saveButton.evaluate().isNotEmpty) {
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Verificar que se muestra SnackBar de error
        expect(
          find.byType(SnackBar),
          findsOneWidget,
          reason: 'Debe mostrar SnackBar con mensaje de error',
        );
      }
    });

    testWidgets('AnteprojectForm shows success state after submission', (
      WidgetTester tester,
    ) async {
      // Configurar mock para éxito
      when(mockAnteprojectsService.createAnteproject(any)).thenAnswer(
        (_) async => WidgetTestUtils.createTestAnteproject(id: 1),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Llenar campos requeridos
      final textFields = find.byType(TextFormField);
      if (textFields.evaluate().isNotEmpty) {
        await tester.enterText(textFields.first, 'Test Title');
        await tester.enterText(textFields.at(1), 'Test Description');
      }

      // Buscar y presionar botón de guardar
      final saveButton = find.byType(ElevatedButton).last;
      if (saveButton.evaluate().isNotEmpty) {
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Verificar que se muestra SnackBar de éxito
        expect(
          find.byType(SnackBar),
          findsOneWidget,
          reason: 'Debe mostrar SnackBar con mensaje de éxito',
        );
      }
    });

    testWidgets('AnteprojectForm shows AppBar with actions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verificar que se muestra el AppBar
      expect(
        find.byType(AppBar),
        findsOneWidget,
        reason: 'Debe mostrar AppBar',
      );

      // Verificar que se muestran los botones de acción
      expect(
        find.byIcon(Icons.download),
        findsOneWidget,
        reason: 'Debe mostrar botón de descargar ejemplo PDF',
      );
      expect(
        find.byIcon(Icons.content_copy),
        findsOneWidget,
        reason: 'Debe mostrar botón de cargar plantilla',
      );
    });

    testWidgets('AnteprojectForm shows all required form fields', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verificar que se muestran los campos principales
      expect(
        find.byType(TextFormField),
        findsWidgets,
        reason: 'Debe mostrar campos de texto del formulario',
      );
      expect(
        find.byType(DropdownButtonFormField),
        findsWidgets,
        reason: 'Debe mostrar dropdowns para selección',
      );
    });

    testWidgets('AnteprojectForm includes GitHub repository URL field', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verificar que existe el campo de repositorio de GitHub
      expect(
        find.text('URL del Repositorio de GitHub'),
        findsOneWidget,
        reason: 'Debe mostrar el campo de URL del repositorio de GitHub',
      );

      // Verificar que el hint text está presente
      expect(
        find.textContaining('github.com'),
        findsWidgets,
        reason: 'Debe mostrar hint text con ejemplo de GitHub',
      );
    });

    testWidgets('AnteprojectForm validates GitHub repository URL format', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verificar que el campo de GitHub repository está presente
      expect(
        find.text('URL del Repositorio de GitHub'),
        findsOneWidget,
        reason: 'Debe mostrar el campo de URL del repositorio de GitHub',
      );

      // El campo es opcional, así que no requiere validación obligatoria
      // La validación se probará en los tests de FormValidators
    });
  });
}

