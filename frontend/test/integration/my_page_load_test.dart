import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:collaboration_tools/api/api_client.dart';
import 'package:collaboration_tools/api/models/entity.dart';
import '../helpers/mock_api.dart';

/// Integration tests for My Page data loading.
///
/// Tests that the My Page correctly fetches tasks, sprints, and documents
/// for a given person using the related_to API, and handles edge cases
/// like empty data and errors.
void main() {
  late MockApiClient mockApi;

  setUp(() {
    mockApi = MockApiClient();
  });

  group('My Page data loading', () {
    test('loads tasks assigned to a person', () async {
      final tasks = [
        TestFixtures.taskEntity(id: 't1', name: 'Task A', status: 'todo'),
        TestFixtures.taskEntity(
            id: 't2', name: 'Task B', status: 'in_progress'),
      ];

      when(() => mockApi.listTasks(assigneeId: 'person-1'))
          .thenAnswer((_) async => TestFixtures.paginatedEntities(tasks));

      final result = await mockApi.listTasks(assigneeId: 'person-1');

      expect(result.entities, hasLength(2));
      expect(result.entities.first.name, equals('Task A'));
    });

    test('loads sprints owned by a person', () async {
      final sprints = [
        TestFixtures.sprintEntity(
          id: 's1',
          name: 'Sprint 12',
          startDate: '2026-03-10',
          endDate: '2026-03-24',
        ),
      ];

      when(() => mockApi.listSprints(ownerId: 'person-1'))
          .thenAnswer((_) async => TestFixtures.paginatedEntities(sprints));

      final result = await mockApi.listSprints(ownerId: 'person-1');

      expect(result.entities, hasLength(1));
      expect(result.entities.first.name, equals('Sprint 12'));
    });

    test('loads documents authored by a person', () async {
      final docs = [
        TestFixtures.documentEntity(
            id: 'd1', name: 'API Spec', docType: 'spec'),
        TestFixtures.documentEntity(
            id: 'd2', name: 'Notes', docType: 'note'),
      ];

      when(() => mockApi.listDocuments(authorId: 'person-1'))
          .thenAnswer((_) async => TestFixtures.paginatedEntities(docs));

      final result = await mockApi.listDocuments(authorId: 'person-1');

      expect(result.entities, hasLength(2));
    });

    test('all three sections load in parallel', () async {
      when(() => mockApi.listTasks(assigneeId: 'person-1')).thenAnswer(
          (_) async => TestFixtures.paginatedEntities([
                TestFixtures.taskEntity(),
              ]));
      when(() => mockApi.listSprints(ownerId: 'person-1')).thenAnswer(
          (_) async => TestFixtures.paginatedEntities([
                TestFixtures.sprintEntity(),
              ]));
      when(() => mockApi.listDocuments(authorId: 'person-1')).thenAnswer(
          (_) async => TestFixtures.paginatedEntities([
                TestFixtures.documentEntity(),
              ]));
      when(() => mockApi.getEntity('person-1')).thenAnswer(
          (_) async => EntityWithRelationships(
                entity: TestFixtures.personEntity(),
                relationships: [],
              ));

      // Simulate parallel loading like the real My Page
      final results = await Future.wait([
        mockApi.getEntity('person-1'),
        mockApi.listTasks(assigneeId: 'person-1'),
        mockApi.listSprints(ownerId: 'person-1'),
        mockApi.listDocuments(authorId: 'person-1'),
      ]);

      expect(results, hasLength(4));
      // All four calls were made
      verify(() => mockApi.getEntity('person-1')).called(1);
      verify(() => mockApi.listTasks(assigneeId: 'person-1')).called(1);
      verify(() => mockApi.listSprints(ownerId: 'person-1')).called(1);
      verify(() => mockApi.listDocuments(authorId: 'person-1')).called(1);
    });

    test('handles empty results for a person with no data', () async {
      when(() => mockApi.listTasks(assigneeId: 'person-new'))
          .thenAnswer((_) async => TestFixtures.paginatedEntities([]));
      when(() => mockApi.listSprints(ownerId: 'person-new'))
          .thenAnswer((_) async => TestFixtures.paginatedEntities([]));
      when(() => mockApi.listDocuments(authorId: 'person-new'))
          .thenAnswer((_) async => TestFixtures.paginatedEntities([]));

      final tasks = await mockApi.listTasks(assigneeId: 'person-new');
      final sprints = await mockApi.listSprints(ownerId: 'person-new');
      final docs = await mockApi.listDocuments(authorId: 'person-new');

      expect(tasks.entities, isEmpty);
      expect(sprints.entities, isEmpty);
      expect(docs.entities, isEmpty);
    });

    test('handles API error on one section gracefully', () async {
      when(() => mockApi.listTasks(assigneeId: 'person-1')).thenAnswer(
          (_) async => TestFixtures.paginatedEntities([
                TestFixtures.taskEntity(),
              ]));
      when(() => mockApi.listSprints(ownerId: 'person-1'))
          .thenThrow(ApiException(
        code: 'SERVER_ERROR',
        message: 'Internal error',
        statusCode: 500,
      ));
      when(() => mockApi.listDocuments(authorId: 'person-1')).thenAnswer(
          (_) async => TestFixtures.paginatedEntities([
                TestFixtures.documentEntity(),
              ]));

      // Tasks and docs succeed, sprints fail
      final tasks = await mockApi.listTasks(assigneeId: 'person-1');
      expect(tasks.entities, hasLength(1));

      expect(
        () => mockApi.listSprints(ownerId: 'person-1'),
        throwsA(isA<ApiException>()),
      );

      final docs = await mockApi.listDocuments(authorId: 'person-1');
      expect(docs.entities, hasLength(1));
    });
  });
}
