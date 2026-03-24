import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collaboration_tools/widgets/kanban/kanban_board.dart';
import 'package:collaboration_tools/api/models/entity.dart';

void main() {
  final now = DateTime.now();

  Entity makeTask(String id, String name, String status,
      {String? priority}) {
    return Entity(
      id: id,
      type: 'task',
      name: name,
      metadata: {
        'status': status,
        if (priority != null) 'priority': priority,
      },
      createdAt: now,
      updatedAt: now,
    );
  }

  final columnOrder = ['backlog', 'todo', 'in_progress', 'done'];
  final columnLabels = {
    'backlog': 'Backlog',
    'todo': 'Todo',
    'in_progress': 'In Progress',
    'done': 'Done',
  };

  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('KanbanBoard', () {
    testWidgets('renders all column headers', (tester) async {
      await tester.pumpWidget(wrap(KanbanBoard(
        columns: {
          'backlog': [],
          'todo': [],
          'in_progress': [],
          'done': [],
        },
        columnOrder: columnOrder,
        columnLabels: columnLabels,
      )));

      expect(find.text('Backlog'), findsOneWidget);
      expect(find.text('Todo'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('renders task cards in correct columns', (tester) async {
      final tasks = {
        'backlog': <Entity>[],
        'todo': [makeTask('1', 'Task A', 'todo')],
        'in_progress': [
          makeTask('2', 'Task B', 'in_progress'),
          makeTask('3', 'Task C', 'in_progress'),
        ],
        'done': [makeTask('4', 'Task D', 'done')],
      };

      await tester.pumpWidget(wrap(KanbanBoard(
        columns: tasks,
        columnOrder: columnOrder,
        columnLabels: columnLabels,
      )));

      expect(find.text('Task A'), findsOneWidget);
      expect(find.text('Task B'), findsOneWidget);
      expect(find.text('Task C'), findsOneWidget);
      expect(find.text('Task D'), findsOneWidget);
    });

    testWidgets('shows task count per column', (tester) async {
      final tasks = {
        'backlog': <Entity>[],
        'todo': [makeTask('1', 'T1', 'todo'), makeTask('2', 'T2', 'todo')],
        'in_progress': <Entity>[],
        'done': <Entity>[],
      };

      await tester.pumpWidget(wrap(KanbanBoard(
        columns: tasks,
        columnOrder: columnOrder,
        columnLabels: columnLabels,
      )));

      expect(find.text('(2)'), findsOneWidget); // todo column count
      expect(find.text('(0)'), findsWidgets); // empty columns
    });

    testWidgets('calls onTaskTap when card is tapped', (tester) async {
      Entity? tappedTask;
      final task = makeTask('1', 'Tappable', 'todo');

      await tester.pumpWidget(wrap(KanbanBoard(
        columns: {
          'backlog': <Entity>[],
          'todo': [task],
          'in_progress': <Entity>[],
          'done': <Entity>[],
        },
        columnOrder: columnOrder,
        columnLabels: columnLabels,
        onTaskTap: (t) => tappedTask = t,
      )));

      await tester.tap(find.text('Tappable'));
      await tester.pump();

      expect(tappedTask, isNotNull);
      expect(tappedTask!.id, equals('1'));
    });

    testWidgets('renders empty columns gracefully', (tester) async {
      await tester.pumpWidget(wrap(KanbanBoard(
        columns: {
          'backlog': <Entity>[],
          'todo': <Entity>[],
          'in_progress': <Entity>[],
          'done': <Entity>[],
        },
        columnOrder: columnOrder,
        columnLabels: columnLabels,
      )));

      // All columns render with zero-count
      for (final label in columnLabels.values) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('readOnly mode disables draggable on cards', (tester) async {
      final task = makeTask('1', 'Read only', 'todo');

      await tester.pumpWidget(wrap(KanbanBoard(
        columns: {
          'backlog': <Entity>[],
          'todo': [task],
          'in_progress': <Entity>[],
          'done': <Entity>[],
        },
        columnOrder: columnOrder,
        columnLabels: columnLabels,
        readOnly: true,
      )));

      // Card renders but Draggable should not be present
      expect(find.text('Read only'), findsOneWidget);
      expect(find.byType(Draggable<String>), findsNothing);
    });
  });
}
