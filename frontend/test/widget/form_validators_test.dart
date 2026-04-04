import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/common/form_validators.dart';
import 'package:frontend/l10n/app_localizations.dart';

void main() {
  group('FormValidators Tests', () {
    setUp(() {
      // No necesitamos setUp para estos tests
    });

    testWidgets('required validator works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('es', 'ES'),
        home: Scaffold(body: Text('Test')),
      ));

      final context = tester.element(find.byType(Scaffold));

      // Test con valor vacío
      expect(FormValidators.required('', context), isNotNull);
      expect(FormValidators.required(null, context), isNotNull);
      expect(FormValidators.required('   ', context), isNotNull);

      // Test con valor válido
      expect(FormValidators.required('test', context), isNull);
      expect(FormValidators.required('  test  ', context), isNull);
    });

    testWidgets('email validator works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('es', 'ES'),
        home: Scaffold(body: Text('Test')),
      ));

      final context = tester.element(find.byType(Scaffold));

      // Test con valor vacío
      expect(FormValidators.email('', context), isNotNull);
      expect(FormValidators.email(null, context), isNotNull);

      // Test con email inválido
      expect(FormValidators.email('invalid', context), isNotNull);
      expect(FormValidators.email('test@', context), isNotNull);
      expect(FormValidators.email('@test.com', context), isNotNull);

      // Test con email válido
      expect(FormValidators.email('test@example.com', context), isNull);
      expect(FormValidators.email('user.name@domain.co.uk', context), isNull);
    });

    testWidgets('url validator works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('es', 'ES'),
        home: Scaffold(body: Text('Test')),
      ));

      final context = tester.element(find.byType(Scaffold));

      // Test con valor vacío (debe ser válido ya que es opcional)
      expect(FormValidators.url('', context), isNull);
      expect(FormValidators.url(null, context), isNull);

      // Test con URL inválida
      expect(FormValidators.url('invalid', context), isNotNull);
      expect(FormValidators.url('not-a-url', context), isNotNull);

      // Test con URL válida
      expect(FormValidators.url('https://example.com', context), isNull);
      expect(FormValidators.url('http://test.org', context), isNull);
    });

    testWidgets('number validator works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('es', 'ES'),
        home: Scaffold(body: Text('Test')),
      ));

      final context = tester.element(find.byType(Scaffold));

      // Test con valor vacío (es opcional, debe retornar null)
      expect(FormValidators.number('', context), isNull);
      expect(FormValidators.number(null, context), isNull);

      // Test con número inválido
      expect(FormValidators.number('abc', context), isNotNull);
      expect(FormValidators.number('12.34.56', context), isNotNull);

      // Test con número válido
      expect(FormValidators.number('123', context), isNull);
      expect(FormValidators.number('12.34', context), isNull);
      expect(FormValidators.number('-45', context), isNull);
    });

    testWidgets('anteproject validators work correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('es', 'ES'),
        home: Scaffold(body: Text('Test')),
      ));

      final context = tester.element(find.byType(Scaffold));

      // Test anteprojectTitle
      expect(FormValidators.anteprojectTitle('', context), isNotNull);
      expect(FormValidators.anteprojectTitle('Test Title', context), isNull);

      // Test anteprojectDescription
      expect(FormValidators.anteprojectDescription('', context), isNotNull);
      expect(FormValidators.anteprojectDescription('Test Description', context), isNull);

      // Test academicYear
      expect(FormValidators.academicYear('', context), isNotNull);
      expect(FormValidators.academicYear('2024-2025', context), isNull);

      // Test tutorId
      expect(FormValidators.tutorId('', context), isNotNull);
      expect(FormValidators.tutorId('abc', context), isNotNull);
      expect(FormValidators.tutorId('123', context), isNull);
    });

    testWidgets('githubRepositoryUrl validator works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('es', 'ES'),
        home: Scaffold(body: Text('Test')),
      ));

      final context = tester.element(find.byType(Scaffold));

      // Test con valor vacío (debe ser válido ya que es opcional)
      expect(FormValidators.githubRepositoryUrl('', context), isNull);
      expect(FormValidators.githubRepositoryUrl(null, context), isNull);

      // Test con URLs inválidas
      expect(FormValidators.githubRepositoryUrl('invalid', context), isNotNull);
      expect(FormValidators.githubRepositoryUrl('not-a-url', context), isNotNull);
      expect(FormValidators.githubRepositoryUrl('https://gitlab.com/user/repo', context), isNotNull);
      expect(FormValidators.githubRepositoryUrl('https://github.com', context), isNotNull);
      expect(FormValidators.githubRepositoryUrl('https://github.com/user', context), isNotNull);
      expect(FormValidators.githubRepositoryUrl('https://github.com/user/', context), isNotNull);
      expect(FormValidators.githubRepositoryUrl('https://example.com/user/repo', context), isNotNull);

      // Test con URLs válidas de GitHub
      expect(FormValidators.githubRepositoryUrl('https://github.com/user/repo', context), isNull);
      expect(FormValidators.githubRepositoryUrl('https://github.com/user/repo.git', context), isNull);
      expect(FormValidators.githubRepositoryUrl('https://www.github.com/user/repo', context), isNull);
      expect(FormValidators.githubRepositoryUrl('http://github.com/user/repo', context), isNull);
      expect(FormValidators.githubRepositoryUrl('https://github.com/user-name/repo-name', context), isNull);
      expect(FormValidators.githubRepositoryUrl('https://github.com/user.name/repo.name', context), isNull);
      expect(FormValidators.githubRepositoryUrl('https://github.com/user_name/repo_name', context), isNull);

      // Test con caracteres inválidos en usuario o repositorio
      expect(FormValidators.githubRepositoryUrl('https://github.com/user space/repo', context), isNotNull);
      expect(FormValidators.githubRepositoryUrl('https://github.com/user@invalid/repo', context), isNotNull);

      // Test con longitudes excesivas
      final longUsername = 'a' * 40; // 40 caracteres (máximo es 39)
      expect(
        FormValidators.githubRepositoryUrl('https://github.com/$longUsername/repo', context),
        isNotNull,
      );

      final longRepo = 'a' * 101; // 101 caracteres (máximo es 100)
      expect(
        FormValidators.githubRepositoryUrl('https://github.com/user/$longRepo', context),
        isNotNull,
      );
    });
  });
}
