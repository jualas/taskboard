import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:frontend/screens/auth/login_screen_bloc.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/blocs/auth_bloc.dart';
import 'package:frontend/services/auth_service.dart';
import 'widget_test_utils.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  setUpAll(() {
    registerFallbackValue(const Stream<AuthState>.empty());
  });

  group('LoginScreen Improved Tests', () {
    late MockAuthService mockAuthService;
    late AuthBloc authBloc;

    setUp(() {
      mockAuthService = MockAuthService();
      authBloc = AuthBloc(authService: mockAuthService);

      when(() => mockAuthService.isAuthenticated).thenReturn(false);
      when(
        () => mockAuthService.authStateChanges,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockAuthService.signOut()).thenAnswer((_) async {});
      when(
        () => mockAuthService.getCurrentUserFromSupabase(),
      ).thenAnswer((_) async => null);
      when(
        () => mockAuthService.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => {
          'success': true,
          'user': WidgetTestUtils.createTestUser().toJson(),
        },
      );
      when(
        () => mockAuthService.createUserFromLoginResponse(any()),
      ).thenReturn(WidgetTestUtils.createTestUser());
    });

    tearDown(() {
      authBloc.close();
    });

    Widget createTestWidget() {
      return WidgetTestUtils.createTestApp(
        child: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const LoginScreenBloc(),
        ),
      );
    }

    testWidgets('LoginScreen shows login form with proper structure', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.byType(LoginScreenBloc), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('LoginScreen shows localized text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      final l10n = AppLocalizations.of(
        tester.element(find.byType(LoginScreenBloc)),
      );

      expect(find.text(l10n.login), findsOneWidget);
      expect(find.text(l10n.email), findsOneWidget);
      expect(find.text(l10n.password), findsOneWidget);
    });

    testWidgets('LoginScreen handles form validation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(LoginScreenBloc)),
      );
      expect(find.text(l10n.fieldRequired), findsAtLeastNWidgets(1));
    });

    testWidgets('LoginScreen handles successful login', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField).first, 'test@example.com');
      await tester.enterText(find.byType(TextField).last, 'password123');

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      verify(
        () => mockAuthService.signIn(
          email: 'test@example.com',
          password: 'password123',
        ),
      ).called(1);
    });

    testWidgets('LoginScreen handles login error', (WidgetTester tester) async {
      when(
        () => mockAuthService.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(Exception('Invalid credentials'));

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField).first, 'test@example.com');
      await tester.enterText(find.byType(TextField).last, 'wrongpassword');

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('LoginScreen is responsive', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      await tester.pumpWidget(createTestWidget());

      expect(find.byType(LoginScreenBloc), findsOneWidget);
      await tester.binding.setSurfaceSize(null);
    });
  });
}
