import 'package:flutter_test/flutter_test.dart';
import 'package:collaboration_tools/state/task_board_state.dart';
import 'package:collaboration_tools/api/models/entity.dart';

void main() {
  final now = DateTime.now();

  Entity makeTask(String id, String name, String status,
      {String priority = 'medium'}) {
    return Entity(
      id: id,
      type: 'task',
      name: name,
      metadata: {'status': status, 'priority': priority},
      createdAt: now,
      updatedAt: now,
    );
  }

  group('groupTasksByStatus', () {
    final statusOrder = [
      'backlog',
      'todo',
      'in_progress',
      'review',
      'done',
      'archived'
    ];

    test('groups tasks into correct columns', () {
      final tasks = [
        makeTask('1', 'Task A', 'todo'),
        makeTask('2', 'Task B', 'in_progress'),
        makeTask('3', 'Task C', 'todo'),
        makeTask('4', 'Task D', 'done'),
      ];

      final columns = groupTasksByStatus(tasks, statusOrder);

      expect(columns['backlog'], isEmpty);
      expect(columns['todo'], hasLength(2));
      expect(columns['in_progress'], hasLength(1));
      expect(columns['review'], isEmpty);
      expect(columns['done'], hasLength(1));
      expect(columns['archived'], isEmpty);
    });

    test('creates empty columns for all statuses', () {
      final columns = groupTasksByStatus([], statusOrder);

      for (final status in statusOrder) {
        expect(columns[status], isNotNull);
        expect(columns[status], isEmpty);
      }
    });

    test('puts tasks with missing status into backlog', () {
      final task = Entity(
        id: '1',
        type: 'task',
        name: 'No status',
        metadata: {}, // no status field
        createdAt: now,
        updatedAt: now,
      );

      final columns = groupTasksByStatus([task], statusOrder);

      expect(columns['backlog'], hasLength(1));
    });

    test('preserves task order within columns', () {
      final tasks = [
        makeTask('1', 'First', 'todo'),
        makeTask('2', 'Second', 'todo'),
        makeTask('3', 'Third', 'todo'),
      ];

      final columns = groupTasksByStatus(tasks, statusOrder);

      expect(columns['todo']![0].name, equals('First'));
      expect(columns['todo']![1].name, equals('Second'));
      expect(columns['todo']![2].name, equals('Third'));
    });

    test('handles unknown status values gracefully', () {
      final task = makeTask('1', 'Unknown status', 'custom_status');

      final columns = groupTasksByStatus([task], statusOrder);

      // Should create a new column for the unknown status
      expect(columns['custom_status'], hasLength(1));
    });
  });

  group('TaskFilters equality', () {
    test('equal filters have same hashCode', () {
      final a = TaskFilters(projectId: 'p1', assigneeId: 'a1');
      final b = TaskFilters(projectId: 'p1', assigneeId: 'a1');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different filters are not equal', () {
      final a = TaskFilters(projectId: 'p1');
      final b = TaskFilters(projectId: 'p2');

      expect(a, isNot(equals(b)));
    });

    test('empty filters are equal', () {
      const a = TaskFilters();
      const b = TaskFilters();

      expect(a, equals(b));
    });
  });
}
