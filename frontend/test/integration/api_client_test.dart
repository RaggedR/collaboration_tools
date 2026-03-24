import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:collaboration_tools/api/api_client.dart';
import '../helpers/mock_api.dart';

/// Integration tests for the ApiClient.
///
/// Uses http's MockClient to simulate server responses without a real
/// backend. Tests verify correct URL construction, header management,
/// JSON parsing, and error handling.
void main() {
  late InMemoryTokenStore tokenStore;

  setUp(() {
    tokenStore = InMemoryTokenStore();
  });

  ApiClient createClient(
      http.Response Function(http.Request) handler) {
    final mockClient = http_testing.MockClient(
        (request) async => handler(request));
    return ApiClient(
      baseUrl: 'http://localhost:8080',
      tokenStore: tokenStore,
      client: mockClient,
    );
  }

  group('Authentication', () {
    test('login sends correct request and parses response', () async {
      final client = createClient((request) {
        expect(request.url.path, equals('/api/auth/login'));
        expect(request.method, equals('POST'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], equals('robin@test.com'));
        expect(body['password'], equals('pass123'));

        return http.Response(
          jsonEncode({
            'token': 'jwt-token-123',
            'user': {
              'id': 'user-1',
              'email': 'robin@test.com',
              'name': 'Robin',
              'is_admin': false,
              'person_entity_id': 'person-1',
            },
          }),
          200,
        );
      });

      final response = await client.login(
        email: 'robin@test.com',
        password: 'pass123',
      );

      expect(response.token, equals('jwt-token-123'));
      expect(response.user.email, equals('robin@test.com'));
      expect(response.user.personEntityId, equals('person-1'));
    });

    test('attaches Bearer token to authenticated requests', () async {
      await tokenStore.write('my-jwt-token');

      final client = createClient((request) {
        expect(
          request.headers['Authorization'],
          equals('Bearer my-jwt-token'),
        );
        return http.Response(
          jsonEncode({
            'entities': [],
            'total': 0,
            'page': 1,
            'per_page': 50,
          }),
          200,
        );
      });

      await client.listEntities(type: 'task');
    });

    test('throws UnauthorizedException on 401', () async {
      final client = createClient((_) {
        return http.Response(
          jsonEncode({
            'error': {'code': 'UNAUTHORIZED', 'message': 'Token expired'},
          }),
          401,
        );
      });

      expect(
        () => client.me(),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('Entity listing', () {
    test('sends correct query parameters for type and metadata filter',
        () async {
      final client = createClient((request) {
        expect(request.url.queryParameters['type'], equals('task'));
        expect(
          request.url.queryParameters['metadata'],
          equals('{"status":"done"}'),
        );
        return http.Response(
          jsonEncode({
            'entities': [],
            'total': 0,
            'page': 1,
            'per_page': 50,
          }),
          200,
        );
      });

      await client.listEntities(
        type: 'task',
        metadata: {'status': 'done'},
      );
    });

    test('sends related_to and rel_type parameters', () async {
      final client = createClient((request) {
        expect(
            request.url.queryParameters['related_to'], equals('person-1'));
        expect(
            request.url.queryParameters['rel_type'], equals('assigned_to'));
        expect(request.url.queryParameters['type'], equals('task'));
        return http.Response(
          jsonEncode({
            'entities': [],
            'total': 0,
            'page': 1,
            'per_page': 50,
          }),
          200,
        );
      });

      await client.listEntities(
        type: 'task',
        relatedTo: 'person-1',
        relType: 'assigned_to',
      );
    });

    test('parses paginated entity list', () async {
      final client = createClient((_) {
        return http.Response(
          jsonEncode({
            'entities': [
              {
                'id': 'task-1',
                'type': 'task',
                'name': 'Test',
                'metadata': {'status': 'todo'},
                'created_at': '2026-03-20T10:00:00Z',
                'updated_at': '2026-03-20T10:00:00Z',
              },
            ],
            'total': 42,
            'page': 1,
            'per_page': 50,
          }),
          200,
        );
      });

      final result = await client.listEntities(type: 'task');

      expect(result.entities, hasLength(1));
      expect(result.entities.first.name, equals('Test'));
      expect(result.total, equals(42));
    });
  });

  group('Convenience methods', () {
    test('listTasks wraps listEntities with correct params', () async {
      final client = createClient((request) {
        expect(request.url.queryParameters['type'], equals('task'));
        expect(request.url.queryParameters['related_to'],
            equals('person-1'));
        expect(request.url.queryParameters['rel_type'],
            equals('assigned_to'));
        return http.Response(
          jsonEncode({
            'entities': [],
            'total': 0,
            'page': 1,
            'per_page': 50,
          }),
          200,
        );
      });

      await client.listTasks(assigneeId: 'person-1');
    });

    test('listSprints wraps listEntities with owned_by', () async {
      final client = createClient((request) {
        expect(request.url.queryParameters['type'], equals('sprint'));
        expect(request.url.queryParameters['related_to'],
            equals('person-1'));
        expect(
            request.url.queryParameters['rel_type'], equals('owned_by'));
        return http.Response(
          jsonEncode({
            'entities': [],
            'total': 0,
            'page': 1,
            'per_page': 50,
          }),
          200,
        );
      });

      await client.listSprints(ownerId: 'person-1');
    });

    test('listDocuments wraps listEntities with authored', () async {
      final client = createClient((request) {
        expect(request.url.queryParameters['type'], equals('document'));
        expect(request.url.queryParameters['related_to'],
            equals('person-1'));
        expect(
            request.url.queryParameters['rel_type'], equals('authored'));
        return http.Response(
          jsonEncode({
            'entities': [],
            'total': 0,
            'page': 1,
            'per_page': 50,
          }),
          200,
        );
      });

      await client.listDocuments(authorId: 'person-1');
    });
  });

  group('Error handling', () {
    test('throws ApiException on 400 with error body', () async {
      final client = createClient((_) {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'Invalid status value',
              'field': 'metadata.status',
            },
          }),
          400,
        );
      });

      try {
        await client.createEntity(
          type: 'task',
          name: 'Bad',
          metadata: {'status': 'invalid'},
        );
        fail('Should have thrown');
      } on ApiException catch (e) {
        expect(e.code, equals('VALIDATION_ERROR'));
        expect(e.message, contains('Invalid'));
        expect(e.field, equals('metadata.status'));
        expect(e.statusCode, equals(400));
      }
    });

    test('throws ApiException on 403', () async {
      final client = createClient((_) {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'FORBIDDEN',
              'message': 'Admin access required',
            },
          }),
          403,
        );
      });

      expect(
        () => client.createEntity(type: 'workspace', name: 'Nope'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
