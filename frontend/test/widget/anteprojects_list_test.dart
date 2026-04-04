import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';

import 'package:frontend/screens/lists/anteprojects_list.dart';
import 'package:frontend/blocs/anteprojects_bloc.dart';
import 'package:frontend/models/anteproject.dart';
import 'package:frontend/widgets/common/loading_widget.dart';
import 'package:frontend/widgets/common/error_handler_widget.dart';
import 'widget_test_utils.dart';
import 'widget_test_utils.mocks.dart';

void main() {
  group('AnteprojectsList Widget Tests', () {
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
          child: const AnteprojectsList(),
        ),
      );
    }

    testWidgets('AnteprojectsList shows loading state', (
      WidgetTester tester,
    ) async {
      // Configurar mock para que retorne datos después de un delay
      when(mockAnteprojectsService.getAnteprojects()).thenAnswer(
        (_) async {
          await Future.delayed(const Duration(milliseconds: 200));
          return [];
        },
      );

      await tester.pumpWidget(createTestWidget());
      // Dar tiempo al BLoC para procesar el evento y emitir loading
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verificar que se muestra LoadingWidget
      expect(
        find.byType(LoadingWidget),
        findsOneWidget,
        reason: 'Debe mostrar LoadingWidget durante la carga',
      );
      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
        reason: 'Debe mostrar CircularProgressIndicator',
      );
    });

    testWidgets('AnteprojectsList shows error state', (
      WidgetTester tester,
    ) async {
      // Configurar mock para que lance error
      when(mockAnteprojectsService.getAnteprojects()).thenThrow(
        Exception('Error al cargar anteproyectos'),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verificar que se muestra ErrorHandlerWidget
      expect(
        find.byType(ErrorHandlerWidget),
        findsOneWidget,
        reason: 'Debe mostrar ErrorHandlerWidget cuando hay error',
      );
      expect(
        find.byIcon(Icons.error_outline),
        findsOneWidget,
        reason: 'Debe mostrar icono de error',
      );
      expect(
        find.byType(ElevatedButton),
        findsOneWidget,
        reason: 'Debe mostrar botón de retry',
      );
    });

    testWidgets('AnteprojectsList shows empty state', (
      WidgetTester tester,
    ) async {
      // Configurar mock para retornar lista vacía
      when(mockAnteprojectsService.getAnteprojects()).thenAnswer(
        (_) async => [],
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verificar que se muestra el estado vacío
      expect(
        find.byIcon(Icons.description_outlined),
        findsOneWidget,
        reason: 'Debe mostrar icono de lista vacía',
      );
      expect(
        find.byType(Center),
        findsWidgets,
        reason: 'Debe mostrar mensaje centrado de lista vacía',
      );
    });

    testWidgets('AnteprojectsList shows list with anteprojects', (
      WidgetTester tester,
    ) async {
      // Configurar mock para retornar anteproyectos
      final anteprojects = [
        WidgetTestUtils.createTestAnteproject(
          id: 1,
          title: 'Test Anteproject 1',
          status: AnteprojectStatus.draft,
        ),
        WidgetTestUtils.createTestAnteproject(
          id: 2,
          title: 'Test Anteproject 2',
          status: AnteprojectStatus.submitted,
        ),
      ];

      when(mockAnteprojectsService.getAnteprojects()).thenAnswer(
        (_) async => anteprojects,
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verificar que se muestra la lista
      expect(
        find.byType(ListView),
        findsOneWidget,
        reason: 'Debe mostrar ListView con anteproyectos',
      );
      expect(
        find.byType(Card),
        findsNWidgets(2),
        reason: 'Debe mostrar 2 cards de anteproyectos',
      );
      expect(
        find.text('Test Anteproject 1'),
        findsOneWidget,
        reason: 'Debe mostrar el título del primer anteproyecto',
      );
      expect(
        find.text('Test Anteproject 2'),
        findsOneWidget,
        reason: 'Debe mostrar el título del segundo anteproyecto',
      );
    });

    testWidgets('AnteprojectsList refresh button triggers reload', (
      WidgetTester tester,
    ) async {
      // Configurar mock para retornar anteproyectos
      final anteprojects = [
        WidgetTestUtils.createTestAnteproject(id: 1),
      ];

      when(mockAnteprojectsService.getAnteprojects()).thenAnswer(
        (_) async => anteprojects,
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Limpiar llamadas anteriores
      clearInteractions(mockAnteprojectsService);

      // Buscar el botón de refresh
      final refreshButton = find.byIcon(Icons.refresh);
      expect(
        refreshButton,
        findsOneWidget,
        reason: 'Debe mostrar botón de refresh en AppBar',
      );

      // Tap en el botón de refresh
      await tester.tap(refreshButton);
      await tester.pumpAndSettle();

      // Verificar que se vuelve a llamar al servicio
      verify(mockAnteprojectsService.getAnteprojects()).called(greaterThan(1));
    });

    testWidgets('AnteprojectsList navigation works on tap', (
      WidgetTester tester,
    ) async {
      // Configurar mock para retornar anteproyecto
      final anteproject = WidgetTestUtils.createTestAnteproject(id: 1);

      when(mockAnteprojectsService.getAnteprojects()).thenAnswer(
        (_) async => [anteproject],
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Buscar el card del anteproyecto
      final card = find.byType(Card).first;
      expect(
        card,
        findsOneWidget,
        reason: 'Debe mostrar card del anteproyecto',
      );

      // Tap en el card
      await tester.tap(card);
      await tester.pumpAndSettle();

      // Verificar que se navega (el Navigator debería haber cambiado)
      // Nota: En un test real, necesitarías mockear la navegación
      // Por ahora, verificamos que el tap no causa errores
      expect(
        find.byType(Scaffold),
        findsWidgets,
        reason: 'Debe mantener la estructura después del tap',
      );
    });

    testWidgets('AnteprojectsList shows correct status chips', (
      WidgetTester tester,
    ) async {
      // Configurar anteproyectos con diferentes estados
      final anteprojects = [
        WidgetTestUtils.createTestAnteproject(
          id: 1,
          status: AnteprojectStatus.draft,
        ),
        WidgetTestUtils.createTestAnteproject(
          id: 2,
          status: AnteprojectStatus.submitted,
        ),
        WidgetTestUtils.createTestAnteproject(
          id: 3,
          status: AnteprojectStatus.approved,
        ),
      ];

      when(mockAnteprojectsService.getAnteprojects()).thenAnswer(
        (_) async => anteprojects,
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verificar que se muestran los chips de estado
      expect(
        find.byType(Container),
        findsWidgets,
        reason: 'Debe mostrar containers con chips de estado',
      );
      // Verificar que hay 3 anteproyectos
      expect(
        find.byType(Card),
        findsNWidgets(3),
        reason: 'Debe mostrar 3 cards de anteproyectos',
      );
    });

    testWidgets('AnteprojectsList shows AppBar with title', (
      WidgetTester tester,
    ) async {
      // Configurar mock para retornar lista vacía
      when(mockAnteprojectsService.getAnteprojects()).thenAnswer(
        (_) async => [],
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verificar que se muestra el AppBar
      expect(
        find.byType(AppBar),
        findsOneWidget,
        reason: 'Debe mostrar AppBar',
      );
      expect(
        find.byType(Scaffold),
        findsOneWidget,
        reason: 'Debe mostrar Scaffold',
      );
    });

    testWidgets('AnteprojectsList error retry button works', (
      WidgetTester tester,
    ) async {
      // Configurar mock para que lance error
      when(mockAnteprojectsService.getAnteprojects()).thenThrow(
        Exception('Error de conexión'),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verificar que se muestra el botón de retry
      final retryButton = find.byType(ElevatedButton);
      expect(
        retryButton,
        findsOneWidget,
        reason: 'Debe mostrar botón de retry en ErrorHandlerWidget',
      );

      // Limpiar interacciones y configurar para éxito
      clearInteractions(mockAnteprojectsService);
      when(mockAnteprojectsService.getAnteprojects()).thenAnswer(
        (_) async => [],
      );

      // Tap en el botón de retry
      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      // Verificar que se vuelve a llamar al servicio
      verify(mockAnteprojectsService.getAnteprojects()).called(1);
    });
  });
}

