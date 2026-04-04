# Tests de Widgets

Este directorio contiene los tests de widgets de la aplicación Flutter.

## Estructura

```
test/widget/
├── auth/
│   └── login_screen_bloc_test.dart
├── lists/
│   ├── anteprojects_list_test.dart
│   ├── tasks_list_test.dart
│   └── my_anteprojects_list_test.dart
├── dashboard/
│   ├── student_dashboard_test.dart
│   ├── tutor_dashboard_test.dart
│   └── admin_dashboard_test.dart
├── forms/
│   ├── anteproject_form_test.dart
│   └── task_form_test.dart
├── approval/
│   └── approval_screen_test.dart
├── messages/
│   └── conversation_threads_test.dart
└── common/
    ├── loading_widget_test.dart
    └── error_handler_widget_test.dart
```

## Cómo Ejecutar

### Ejecutar todos los tests de widgets

```bash
flutter test test/widget
```

### Ejecutar un test específico

```bash
flutter test test/widget/auth/login_screen_bloc_test.dart
```

### Ejecutar con cobertura

```bash
flutter test test/widget --coverage
```

## Guía de Escritura de Tests

### 1. Estructura Básica

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  group('NombreWidget Tests', () {
    testWidgets('descripción del test', (tester) async {
      // Arrange
      
      // Act
      
      // Assert
    });
  });
}
```

### 2. Testear Estados de BLoC

```dart
testWidgets('shows loading state', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<MiBloc>.value(
        value: mockBloc,
        child: MiWidget(),
      ),
    ),
  );
  
  expect(find.byType(LoadingWidget), findsOneWidget);
});
```

### 3. Testear Interacciones

```dart
testWidgets('calls onTap when button is pressed', (tester) async {
  bool tapped = false;
  
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ElevatedButton(
          onPressed: () => tapped = true,
          child: Text('Tap me'),
        ),
      ),
    ),
  );
  
  await tester.tap(find.text('Tap me'));
  await tester.pump();
  
  expect(tapped, isTrue);
});
```

### 4. Testear Formularios

```dart
testWidgets('validates required fields', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MiFormulario(),
      ),
    ),
  );
  
  await tester.tap(find.text('Guardar'));
  await tester.pump();
  
  expect(find.text('Este campo es obligatorio'), findsWidgets);
});
```

## Estados a Testear

Cada widget debe testear al menos estos estados:

1. **Loading** - Muestra indicador de carga
2. **Error** - Muestra mensaje de error
3. **Empty** - Muestra estado vacío
4. **Success** - Muestra datos correctamente

## Ver Análisis Completo

Para ver el análisis completo de widgets y prioridades, consulta:
- `ANALISIS_WIDGETS.md` - Análisis detallado de todos los widgets

