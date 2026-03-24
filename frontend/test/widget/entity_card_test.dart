import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collaboration_tools/widgets/shared/entity_card.dart';
import 'package:collaboration_tools/api/models/entity.dart';

void main() {
  final now = DateTime.now();

  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('EntityCard', () {
    testWidgets('renders entity name', (tester) async {
      final entity = Entity(
        id: '1',
        type: 'task',
        name: 'Build login page',
        metadata: {},
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(wrap(EntityCard(entity: entity)));

      expect(find.text('Build login page'), findsOneWidget);
    });

    testWidgets('renders correct icon for task type', (tester) async {
      final entity = Entity(
        id: '1',
        type: 'task',
        name: 'Task',
        metadata: {},
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(wrap(EntityCard(entity: entity)));

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('renders correct icon for project type', (tester) async {
      final entity = Entity(
        id: '1',
        type: 'project',
        name: 'Project',
        metadata: {},
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(wrap(EntityCard(entity: entity)));

      expect(find.byIcon(Icons.folder), findsOneWidget);
    });

    testWidgets('renders correct icon for person type', (tester) async {
      final entity = Entity(
        id: '1',
        type: 'person',
        name: 'Robin',
        metadata: {},
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(wrap(EntityCard(entity: entity)));

      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('renders correct icon for sprint type', (tester) async {
      final entity = Entity(
        id: '1',
        type: 'sprint',
        name: 'Sprint 1',
        metadata: {},
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(wrap(EntityCard(entity: entity)));

      expect(find.byIcon(Icons.timer), findsOneWidget);
    });

    testWidgets('renders correct icon for document type', (tester) async {
      final entity = Entity(
        id: '1',
        type: 'document',
        name: 'Spec',
        metadata: {},
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(wrap(EntityCard(entity: entity)));

      expect(find.byIcon(Icons.description), findsOneWidget);
    });

    testWidgets('calls onTap callback', (tester) async {
      var tapped = false;
      final entity = Entity(
        id: '1',
        type: 'task',
        name: 'Tappable',
        metadata: {},
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
          wrap(EntityCard(entity: entity, onTap: () => tapped = true)));

      await tester.tap(find.text('Tappable'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('renders trailing widget when provided', (tester) async {
      final entity = Entity(
        id: '1',
        type: 'task',
        name: 'With trailing',
        metadata: {},
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(wrap(EntityCard(
        entity: entity,
        trailing: const Text('Extra'),
      )));

      expect(find.text('Extra'), findsOneWidget);
    });

    testWidgets('renders subtitle widget when provided', (tester) async {
      final entity = Entity(
        id: '1',
        type: 'task',
        name: 'With subtitle',
        metadata: {},
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(wrap(EntityCard(
        entity: entity,
        subtitle: const Text('Some detail'),
      )));

      expect(find.text('Some detail'), findsOneWidget);
    });
  });
}
