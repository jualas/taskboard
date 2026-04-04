import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Generar mocks con: flutter packages pub run build_runner build
@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  User,
  Session,
  AuthResponse,
])
import 'supabase_mock.mocks.dart';

/// Mock de Supabase para tests
class MockSupabase {
  static MockSupabaseClient? _mockClient;
  static MockGoTrueClient? _mockAuth;
  static MockUser? _mockUser;
  static MockSession? _mockSession;
  static MockAuthResponse? _mockAuthResponse;
  static bool _isInitialized = false;

  /// Inicializar mocks
  static void initialize() {
    if (_isInitialized) return;
    
    _mockClient = MockSupabaseClient();
    _mockAuth = MockGoTrueClient();
    _mockUser = MockUser();
    _mockSession = MockSession();
    _mockAuthResponse = MockAuthResponse();

    // Configurar mocks básicos
    when(_mockClient!.auth).thenReturn(_mockAuth!);
    when(_mockUser!.id).thenReturn('test-user-id');
    when(_mockUser!.email).thenReturn('test@example.com');
    when(_mockUser!.userMetadata).thenReturn({'role': 'student'});
    when(_mockSession!.user).thenReturn(_mockUser!);
    when(_mockSession!.accessToken).thenReturn('mock-access-token');
    when(_mockAuth!.currentUser).thenReturn(_mockUser);
    when(_mockAuth!.currentSession).thenReturn(_mockSession);
    when(_mockAuth!.signInWithPassword(
      email: anyNamed('email'),
      password: anyNamed('password'),
    )).thenAnswer((_) async => _mockAuthResponse!);
    when(_mockAuth!.signOut()).thenAnswer((_) async {});
    when(_mockAuthResponse!.user).thenReturn(_mockUser);
    when(_mockAuthResponse!.session).thenReturn(_mockSession);

    _isInitialized = true;
  }

  /// Obtener cliente mock
  static MockSupabaseClient get client => _mockClient!;
  
  /// Obtener auth mock
  static MockGoTrueClient get auth => _mockAuth!;
  
  /// Obtener usuario mock
  static MockUser get user => _mockUser!;
  
  /// Obtener sesión mock
  static MockSession get session => _mockSession!;

  /// Configurar usuario autenticado
  static void setAuthenticatedUser({
    String? id,
    String? email,
    String? role,
  }) {
    if (id != null) when(_mockUser!.id).thenReturn(id);
    if (email != null) when(_mockUser!.email).thenReturn(email);
    if (role != null) {
      when(_mockUser!.userMetadata).thenReturn({'role': role});
    }
    when(_mockAuth!.currentUser).thenReturn(_mockUser);
    when(_mockAuth!.currentSession).thenReturn(_mockSession);
  }

  /// Limpiar mocks
  static void reset() {
    if (_mockClient != null) resetMockitoState();
    if (_mockAuth != null) resetMockitoState();
    if (_mockUser != null) resetMockitoState();
    if (_mockSession != null) resetMockitoState();
    if (_mockAuthResponse != null) resetMockitoState();
    _isInitialized = false;
  }
}

/// Mock robusto de Supabase para tests de widgets
class SupabaseMock {
  static MockSupabaseClient? _mockClient;
  static MockGoTrueClient? _mockAuth;
  static MockUser? _mockUser;
  static MockSession? _mockSession;
  static MockAuthResponse? _mockAuthResponse;
  static bool _isInitialized = false;

  /// Inicializar mocks de Supabase
  static void initializeMocks() {
    if (_isInitialized) return;
    
    _mockClient = MockSupabaseClient();
    _mockAuth = MockGoTrueClient();
    _mockUser = MockUser();
    _mockSession = MockSession();
    _mockAuthResponse = MockAuthResponse();

    // Configurar mocks básicos
    when(_mockClient!.auth).thenReturn(_mockAuth!);

    // Configurar usuario mock
    when(_mockUser!.id).thenReturn('test-user-id');
    when(_mockUser!.email).thenReturn('test@example.com');
    when(_mockUser!.userMetadata).thenReturn({'role': 'student'});

    // Configurar sesión mock
    when(_mockSession!.user).thenReturn(_mockUser!);
    when(_mockSession!.accessToken).thenReturn('mock-access-token');

    // Configurar auth mock
    when(_mockAuth!.currentUser).thenReturn(_mockUser);
    when(_mockAuth!.currentSession).thenReturn(_mockSession);
    when(_mockAuth!.signInWithPassword(
      email: anyNamed('email'),
      password: anyNamed('password'),
    )).thenAnswer((_) async => _mockAuthResponse!);
    when(_mockAuth!.signOut()).thenAnswer((_) async {});

    // Configurar respuesta de autenticación
    when(_mockAuthResponse!.user).thenReturn(_mockUser);
    when(_mockAuthResponse!.session).thenReturn(_mockSession);
    
    _isInitialized = true;
  }

  /// Obtener cliente mock
  static MockSupabaseClient get client {
    if (_mockClient == null) {
      initializeMocks();
    }
    return _mockClient!;
  }

  /// Obtener auth mock
  static MockGoTrueClient get auth {
    if (_mockAuth == null) {
      initializeMocks();
    }
    return _mockAuth!;
  }

  /// Obtener usuario mock
  static MockUser get user {
    if (_mockUser == null) {
      initializeMocks();
    }
    return _mockUser!;
  }

  /// Obtener sesión mock
  static MockSession get session {
    if (_mockSession == null) {
      initializeMocks();
    }
    return _mockSession!;
  }

  /// Configurar usuario autenticado
  static void setAuthenticatedUser({
    String? id,
    String? email,
    String? role,
  }) {
    if (id != null) when(_mockUser!.id).thenReturn(id);
    if (email != null) when(_mockUser!.email).thenReturn(email);
    if (role != null) {
      when(_mockUser!.userMetadata).thenReturn({'role': role});
    }
    when(_mockAuth!.currentUser).thenReturn(_mockUser);
    when(_mockAuth!.currentSession).thenReturn(_mockSession);
  }

  /// Configurar usuario no autenticado
  static void setUnauthenticatedUser() {
    when(_mockAuth!.currentUser).thenReturn(null);
    when(_mockAuth!.currentSession).thenReturn(null);
  }

  /// Limpiar mocks
  static void resetMocks() {
    if (_mockClient != null) reset(_mockClient);
    if (_mockAuth != null) reset(_mockAuth);
    if (_mockUser != null) reset(_mockUser);
    if (_mockSession != null) reset(_mockSession);
    if (_mockAuthResponse != null) reset(_mockAuthResponse);
    _isInitialized = false;
    initializeMocks();
  }
}

/// Extensión para facilitar el uso de mocks en tests
extension SupabaseMockExtension on WidgetTester {
  /// Configurar Supabase mock para el test
  void setupSupabaseMock({
    String? userId,
    String? email,
    String? role,
    bool authenticated = true,
  }) {
    if (authenticated) {
      SupabaseMock.setAuthenticatedUser(
        id: userId ?? 'test-user-id',
        email: email ?? 'test@example.com',
        role: role ?? 'student',
      );
    } else {
      SupabaseMock.setUnauthenticatedUser();
    }
  }
}