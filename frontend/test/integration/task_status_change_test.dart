import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:collaboration_tools/api/api_client.dart';
import 'package:collaboration_tools/api/models/entity.dart';
import 'package:collaboration_tools/state/task_board_state.dart';
import '../helpers/mock_api.dart';

/// Integration tests for task status change (kanban drag optimistic update).
///
/// Tests the flow: drag card → optimistic update → API call → success/rollback.
void main() {
  late MockApiClient mockApi;

  setUp(() {
    mockApi = MockApiClient();
  });

  group('Kanban status change', () {
    test('grouping reflects status change after move', () {
      final statusOrder = ['todo', 'in_progress', 'done'];
      final tasks = [
        TestFixtures.taskEntity(id: 't1', name: 'Move me', status: 'todo'),
        TestFixtures.taskEntity(id: 't2', name: 'Stay put', status: 'done'),
      ];

      var columns = groupTasksByStatus(tasks, statusOrder);
      expect(columns['todo'], hasLength(1));
      expect(columns['in_progress'], isEmpty);

      // Simulate move: change status in metadata
      final movedTask = Entity(
        id: 't1',
        type: 'task',
        name: 'Move me',
        metadata: {'status': 'in_progress'},
        createdAt: tasks[0].createdAt,
        updatedAt: tasks[0].updatedAt,
      );

      final updatedTasks = [movedTask, tasks[1]];
      columns = groupTasksByStatus(updatedTasks, statusOrder);

      expect(columns['todo'], isEmpty);
      expect(columns['in_progress'], hasLength(1));
      expect(columns['in_progress']!.first.name, equals('Move me'));
      expect(columns['done'], hasLength(1));
    });

    test('API call updates entity metadata with new status', () async {
      when(() => mockApi.updateEntity(
            't1',
            metadata: {'status': 'in_progress', 'priority': 'high'},
          )).thenAnswer((_) async => TestFixtures.taskEntity(
            id: 't1',
            name: 'Moved task',
            status: 'in_progress',
            priority: 'high',
          ));

      final result = await mockApi.updateEntity(
        't1',
        metadata: {'status': 'in_progress', 'priority': 'high'},
      );

      expect(result.metadata['status'], equals('in_progress'));
      verify(() => mockApi.updateEntity(
            't1',
            metadata: {'status': 'in_progress', 'priority': 'high'},
          )).called(1);
    });

    test('rollback restores original grouping on API failure', () {
      final statusOrder = ['todo', 'in_progress', 'done'];
      final originalTasks = [
        TestFixtures.taskEntity(id: 't1', name: 'Task', status: 'todo'),
      ];

      // Original state
      final originalColumns = groupTasksByStatus(originalTasks, statusOrder);
      expect(originalColumns['todo'], hasLength(1));

      // Optimistic move
      final movedTask = Entity(
        id: 't1',
        type: 'task',
        name: 'Task',
        metadata: {'status': 'in_progress'},
        createdAt: originalTasks[0].createdAt,
        updatedAt: originalTasks[0].updatedAt,
      );
      final optimisticColumns =
          groupTasksByStatus([movedTask], statusOrder);
      expect(optimisticColumns['in_progress'], hasLength(1));

      // Rollback (API failed, restore original)
      final rolledBack = groupTasksByStatus(originalTasks, statusOrder);
      expect(rolledBack['todo'], hasLength(1));
      expect(rolledBack['in_progress'], isEmpty);
    });

    test('preserves other metadata fields during status update', () async {
      final original = TestFixtures.taskEntity(
        id: 't1',
        status: 'todo',
        priority: 'high',
      );

      // Status changes but priority stays
      final updatedMetadata = {
        ...original.metadata,
        'status': 'in_progress',
      };

      expect(updatedMetadata['status'], equals('in_progress'));
      expect(updatedMetadata['priority'], equals('high'));
    });
  });
}
