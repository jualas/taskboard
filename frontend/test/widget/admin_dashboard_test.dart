import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/screens/dashboard/admin_dashboard.dart';
import 'package:frontend/services/admin_stats_service.dart';
import 'package:frontend/models/user.dart';
import 'widget_test_utils.dart';

class FakeAdminStatsService implements AdminStatsRepository {
  final AdminStats stats;
  final List<User> users;
  final Duration? delay;
  final bool throwError;

  const FakeAdminStatsService({
    required this.stats,
    required this.users,
    this.delay,
    this.throwError = false,
  });

  Future<T> _maybeDelay<T>(T Function() producer) async {
    if (throwError) {
      throw Exception('Error de estadísticas simulada');
    }
    if (delay != null) {
      await Future.delayed(delay!);
    }
    return producer();
  }

  @override
  Future<AdminStats> getSystemStats() => _maybeDelay(() => stats);

  @override
  Future<List<User>> getRecentUsers() => _maybeDelay(() => users);
}

void main() {
  const defaultStats = AdminStats(
    totalUsers: 10,
    totalStudents: 5,
    totalTutors: 3,
    totalAnteprojects: 4,
    activeAnteprojects: 2,
    approvedAnteprojects: 1,
    pendingAnteprojects: 1,
  );

  FakeAdminStatsService createService({
    AdminStats stats = defaultStats,
    List<User>? users,
    Duration? delay,
    bool throwError = false,
  }) {
    return FakeAdminStatsService(
      stats: stats,
      users: users ?? [WidgetTestUtils.createTestUser(email: 'admin@test.com')],
      delay: delay,
      throwError: throwError,
    );
  }

  Widget createTestWidget(FakeAdminStatsService service) {
    return WidgetTestUtils.createTestApp(
      child: AdminDashboard(
        user: WidgetTestUtils.createTestUser(role: UserRole.admin),
        statsService: service,
      ),
    );
  }

  group('AdminDashboard Widget Tests', () {
    testWidgets('AdminDashboard shows correct title and structure', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(createService()));
      await WidgetTestUtils.waitForAnimation(tester);

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.textContaining('Dashboard'), findsOneWidget);
    });

    testWidgets('AdminDashboard shows admin-specific information', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(createService()));
      await WidgetTestUtils.waitForAnimation(tester);

      expect(find.byType(Card), findsWidgets);
      expect(find.textContaining('admin@test.com'), findsOneWidget);
    });

    testWidgets('AdminDashboard shows system overview section', (tester) async {
      await tester.pumpWidget(createTestWidget(createService()));
      await WidgetTestUtils.waitForAnimation(tester);

      expect(find.textContaining('Usuarios'), findsWidgets);
    });

    testWidgets('AdminDashboard shows user management options', (tester) async {
      await tester.pumpWidget(createTestWidget(createService()));
      await WidgetTestUtils.waitForAnimation(tester);

      expect(find.byType(TextButton), findsWidgets);
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('AdminDashboard shows system statistics', (tester) async {
      await tester.pumpWidget(createTestWidget(createService()));
      await WidgetTestUtils.waitForAnimation(tester);

      expect(find.text('10'), findsWidgets);
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('AdminDashboard handles empty state gracefully', (
      tester,
    ) async {
      const emptyStats = AdminStats(
        totalUsers: 0,
        totalStudents: 0,
        totalTutors: 0,
        totalAnteprojects: 0,
        activeAnteprojects: 0,
        approvedAnteprojects: 0,
        pendingAnteprojects: 0,
      );
      await tester.pumpWidget(
        createTestWidget(createService(stats: emptyStats, users: const [])),
      );
      await WidgetTestUtils.waitForAnimation(tester);

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('AdminDashboard shows loading state', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          createService(delay: const Duration(milliseconds: 100)),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('AdminDashboard shows error state', (tester) async {
      await tester.pumpWidget(
        createTestWidget(createService(throwError: true)),
      );
      await WidgetTestUtils.waitForAnimation(tester);

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('AdminDashboard navigation works correctly', (tester) async {
      await tester.pumpWidget(createTestWidget(createService()));
      await WidgetTestUtils.waitForAnimation(tester);

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.admin_panel_settings), findsOneWidget);
    });

    testWidgets('AdminDashboard shows correct user role information', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(createService()));
      await WidgetTestUtils.waitForAnimation(tester);

      expect(find.text('Rol: Administrador'), findsOneWidget);
    });

    testWidgets('AdminDashboard responsive design works', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      await tester.pumpWidget(createTestWidget(createService()));
      await WidgetTestUtils.waitForAnimation(tester);

      expect(find.byType(Scaffold), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });
  });
}
