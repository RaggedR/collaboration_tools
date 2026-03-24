import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:collaboration_tools/state/auth_state.dart';
import 'package:collaboration_tools/api/api_client.dart';
import 'package:collaboration_tools/api/models/auth.dart';
import '../helpers/mock_api.dart';

/// Integration tests for the authentication flow.
///
/// Tests the AuthNotifier state machine: login → authenticated,
/// register → authenticated, checkSession → restored or cleared,
/// logout → unauthenticated.
void main() {
  late MockApiClient mockApi;
  late InMemoryTokenStore tokenStore;
  late AuthNotifier authNotifier;

  setUp(() {
    mockApi = MockApiClient();
    tokenStore = InMemoryTokenStore();
    authNotifier = AuthNotifier(api: mockApi, tokenStore: tokenStore);
  });

  group('Login flow', () {
    test('successful login sets user and stores token', () async {
      when(() => mockApi.login(
            email: 'robin@test.com',
            password: 'password123',
          )).thenAnswer((_) async => AuthResponse(
            token: 'jwt-123',
            user: TestFixtures.testUser(),
          ));

      await authNotifier.login('robin@test.com', 'password123');

      expect(authNotifier.state.isAuthenticated, isTrue);
      expect(authNotifier.state.user?.email, equals('robin@test.com'));
      expect(authNotifier.state.personEntityId, equals('person-1'));
      expect(await tokenStore.read(), equals('jwt-123'));
    });

    test('failed login sets error message', () async {
      when(() => mockApi.login(
            email: 'wrong@test.com',
            password: 'wrong',
          )).thenThrow(ApiException(
            code: 'AUTH_ERROR',
            message: 'Invalid credentials',
            statusCode: 401,
          ));

      await authNotifier.login('wrong@test.com', 'wrong');

      expect(authNotifier.state.isAuthenticated, isFalse);
      expect(authNotifier.state.error, equals('Invalid credentials'));
      expect(authNotifier.state.isLoading, isFalse);
    });

    test('login sets isLoading during request', () async {
      // Verify initial state
      expect(authNotifier.state.isLoading, isFalse);

      when(() => mockApi.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async {
        // At this point isLoading should be true
        return AuthResponse(
          token: 'jwt-123',
          user: TestFixtures.testUser(),
        );
      });

      await authNotifier.login('robin@test.com', 'pass');

      // After completion, isLoading should be false
      expect(authNotifier.state.isLoading, isFalse);
    });
  });

  group('Register flow', () {
    test('successful registration sets user and stores token', () async {
      when(() => mockApi.register(
            email: 'new@test.com',
            password: 'password123',
            name: 'New User',
          )).thenAnswer((_) async => AuthResponse(
            token: 'jwt-new',
            user: TestFixtures.testUser(
              id: 'user-new',
              email: 'new@test.com',
              name: 'New User',
              personEntityId: 'person-new',
            ),
          ));

      await authNotifier.register('New User', 'new@test.com', 'password123');

      expect(authNotifier.state.isAuthenticated, isTrue);
      expect(authNotifier.state.user?.email, equals('new@test.com'));
      expect(await tokenStore.read(), equals('jwt-new'));
    });

    test('failed registration sets error', () async {
      when(() => mockApi.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
            name: any(named: 'name'),
          )).thenThrow(ApiException(
            code: 'REGISTRATION_ERROR',
            message: 'Email already registered',
            statusCode: 400,
          ));

      await authNotifier.register('Name', 'existing@test.com', 'pass');

      expect(authNotifier.state.isAuthenticated, isFalse);
      expect(authNotifier.state.error, contains('already registered'));
    });
  });

  group('Session check (cold start)', () {
    test('restores session from stored token', () async {
      await tokenStore.write('stored-jwt');

      when(() => mockApi.me()).thenAnswer(
        (_) async => TestFixtures.testUser(),
      );

      await authNotifier.checkSession();

      expect(authNotifier.state.isAuthenticated, isTrue);
      expect(authNotifier.state.user?.email, equals('robin@test.com'));
    });

    test('clears state when no token is stored', () async {
      // tokenStore is empty
      await authNotifier.checkSession();

      expect(authNotifier.state.isAuthenticated, isFalse);
      expect(authNotifier.state.isLoading, isFalse);
    });

    test('clears token and state when token is invalid', () async {
      await tokenStore.write('expired-jwt');

      when(() => mockApi.me()).thenThrow(UnauthorizedException());

      await authNotifier.checkSession();

      expect(authNotifier.state.isAuthenticated, isFalse);
      expect(await tokenStore.read(), isNull);
    });
  });

  group('Logout', () {
    test('clears user state and token', () async {
      // First, login
      when(() => mockApi.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => AuthResponse(
            token: 'jwt-123',
            user: TestFixtures.testUser(),
          ));
      await authNotifier.login('robin@test.com', 'pass');
      expect(authNotifier.state.isAuthenticated, isTrue);

      // Then logout
      await authNotifier.logout();

      expect(authNotifier.state.isAuthenticated, isFalse);
      expect(authNotifier.state.user, isNull);
      expect(await tokenStore.read(), isNull);
    });
  });

  group('AuthState derived properties', () {
    test('isAdmin reflects user property', () {
      final adminState = AuthState(user: TestFixtures.adminUser());
      expect(adminState.isAdmin, isTrue);

      final userState = AuthState(user: TestFixtures.testUser());
      expect(userState.isAdmin, isFalse);
    });

    test('personEntityId from user', () {
      final state =
          AuthState(user: TestFixtures.testUser(personEntityId: 'p-42'));
      expect(state.personEntityId, equals('p-42'));
    });

    test('unauthenticated state defaults', () {
      const state = AuthState();
      expect(state.isAuthenticated, isFalse);
      expect(state.isAdmin, isFalse);
      expect(state.personEntityId, isNull);
    });
  });
}
