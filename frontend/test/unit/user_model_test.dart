import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/user.dart';

void main() {
  group('User Model Tests', () {
    test('User can be created with required fields', () {
      final user = User(
        id: 1,
        fullName: 'Test User',
        email: 'test@example.com',
        role: UserRole.student,
        status: UserStatus.active,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(user.id, equals('1'));
      expect(user.fullName, equals('Test User'));
      expect(user.email, equals('test@example.com'));
      expect(user.role, equals(UserRole.student));
      expect(user.status, equals(UserStatus.active));
    });

    test('User can be created with optional fields', () {
      final user = User(
        id: 2,
        fullName: 'Test User 2',
        email: 'test2@example.com',
        role: UserRole.tutor,
        status: UserStatus.active,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        nre: '12345678A',
        phone: '+34 123 456 789',
        biography: 'Test biography',
      );

      expect(user.nre, equals('12345678A'));
      expect(user.phone, equals('+34 123 456 789'));
      expect(user.biography, equals('Test biography'));
    });

    test('User copyWith works correctly', () {
      final originalUser = User(
        id: 1,
        fullName: 'Original User',
        email: 'original@example.com',
        role: UserRole.student,
        status: UserStatus.active,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final updatedUser = originalUser.copyWith(
        fullName: 'Updated User',
        email: 'updated@example.com',
      );

      expect(updatedUser.id, equals('1'));
      expect(updatedUser.fullName, equals('Updated User'));
      expect(updatedUser.email, equals('updated@example.com'));
      expect(updatedUser.role, equals(UserRole.student));
      expect(updatedUser.status, equals(UserStatus.active));
    });

    test('User equality works correctly', () {
      final user1 = User(
        id: 1,
        fullName: 'Test User',
        email: 'test@example.com',
        role: UserRole.student,
        status: UserStatus.active,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final user2 = User(
        id: 1,
        fullName: 'Different Name',
        email: 'different@example.com',
        role: UserRole.admin,
        status: UserStatus.inactive,
        createdAt: DateTime(2024, 2, 1),
        updatedAt: DateTime(2024, 2, 1),
      );

      final user3 = User(
        id: 2,
        fullName: 'Test User',
        email: 'test@example.com',
        role: UserRole.student,
        status: UserStatus.active,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(user1, equals(user2)); // Same ID
      expect(user1, isNot(equals(user3))); // Different ID
    });

    test('UserRole enum values are correct', () {
      expect(UserRole.admin.toString(), contains('admin'));
      expect(UserRole.tutor.toString(), contains('tutor'));
      expect(UserRole.student.toString(), contains('student'));
    });

    test('UserStatus enum values are correct', () {
      expect(UserStatus.active.toString(), contains('active'));
      expect(UserStatus.inactive.toString(), contains('inactive'));
    });

    test('UserRole extension displayName works', () {
      expect(UserRole.admin.displayName, equals('Administrador'));
      expect(UserRole.tutor.displayName, equals('Tutor'));
      expect(UserRole.student.displayName, equals('Alumno'));
    });
  });
}
