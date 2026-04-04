import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:frontend/services/auth_service.dart';

// Generar mocks con: flutter packages pub run build_runner build
@GenerateMocks(
  [AuthService],
  customMocks: [MockSpec<AuthService>(as: #MockAuthServiceForTests)],
)
import 'auth_service_mock.mocks.dart';

/// Helper para crear mocks de AuthService
class AuthServiceMockHelper {
  static MockAuthServiceForTests createMockAuthService() {
    final mock = MockAuthServiceForTests();

    when(mock.isAuthenticated).thenReturn(false);
    when(mock.currentUser).thenReturn(null);
    when(mock.authStateChanges).thenAnswer((_) => const Stream.empty());

    return mock;
  }
}
