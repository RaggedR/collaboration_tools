import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collaboration_tools/widgets/shared/metadata_form.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));
  }

  group('MetadataForm', () {
    testWidgets('renders name field', (tester) async {
      await tester.pumpWidget(wrap(MetadataForm(
        metadataSchema: {
          'type': 'object',
          'properties': {},
        },
        onSubmit: (_, __) {},
      )));

      expect(find.text('Name'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('generates dropdown for string with enum', (tester) async {
      await tester.pumpWidget(wrap(MetadataForm(
        metadataSchema: {
          'type': 'object',
          'properties': {
            'status': {
              'type': 'string',
              'enum': ['backlog', 'todo', 'in_progress', 'done'],
            },
          },
        },
        onSubmit: (_, __) {},
      )));

      expect(find.text('Status'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('generates text field for plain string', (tester) async {
      await tester.pumpWidget(wrap(MetadataForm(
        metadataSchema: {
          'type': 'object',
          'properties': {
            'description': {'type': 'string'},
          },
        },
        onSubmit: (_, __) {},
      )));

      expect(find.text('Description'), findsOneWidget);
    });

    testWidgets('generates number field for number type', (tester) async {
      await tester.pumpWidget(wrap(MetadataForm(
        metadataSchema: {
          'type': 'object',
          'properties': {
            'estimate': {'type': 'number'},
          },
        },
        onSubmit: (_, __) {},
      )));

      expect(find.text('Estimate'), findsOneWidget);
    });

    testWidgets('generates date field for date format', (tester) async {
      await tester.pumpWidget(wrap(MetadataForm(
        metadataSchema: {
          'type': 'object',
          'properties': {
            'deadline': {'type': 'string', 'format': 'date'},
          },
        },
        onSubmit: (_, __) {},
      )));

      expect(find.text('Deadline'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('generates all fields for task metadata schema',
        (tester) async {
      await tester.pumpWidget(wrap(MetadataForm(
        metadataSchema: {
          'type': 'object',
          'properties': {
            'status': {
              'type': 'string',
              'enum': [
                'backlog',
                'todo',
                'in_progress',
                'review',
                'done',
                'archived'
              ],
            },
            'priority': {
              'type': 'string',
              'enum': ['low', 'medium', 'high', 'urgent'],
            },
            'deadline': {'type': 'string', 'format': 'date'},
            'estimate': {'type': 'number'},
            'labels': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
        },
        onSubmit: (_, __) {},
      )));

      // Name + 5 metadata fields
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Priority'), findsOneWidget);
      expect(find.text('Deadline'), findsOneWidget);
      expect(find.text('Estimate'), findsOneWidget);
      expect(find.text('Labels'), findsOneWidget);
    });

    testWidgets('validates required name field', (tester) async {
      await tester.pumpWidget(wrap(MetadataForm(
        metadataSchema: {
          'type': 'object',
          'properties': {},
        },
        onSubmit: (_, __) {},
      )));

      // Tap save without entering name
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Name is required'), findsOneWidget);
    });

    testWidgets('calls onSubmit with entered data', (tester) async {
      String? submittedName;
      Map<String, dynamic>? submittedMetadata;

      await tester.pumpWidget(wrap(MetadataForm(
        metadataSchema: {
          'type': 'object',
          'properties': {
            'description': {'type': 'string'},
          },
        },
        onSubmit: (name, metadata) {
          submittedName = name;
          submittedMetadata = metadata;
        },
      )));

      await tester.enterText(find.byType(TextFormField).first, 'Test Entity');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(submittedName, equals('Test Entity'));
      expect(submittedMetadata, isNotNull);
    });

    testWidgets('pre-fills values in edit mode', (tester) async {
      await tester.pumpWidget(wrap(MetadataForm(
        metadataSchema: {
          'type': 'object',
          'properties': {
            'description': {'type': 'string'},
          },
        },
        initialName: 'Existing Name',
        initialValues: {'description': 'Existing description'},
        onSubmit: (_, __) {},
      )));

      expect(find.text('Existing Name'), findsOneWidget);
      expect(find.text('Existing description'), findsOneWidget);
    });

    testWidgets('shows loading state on submit button', (tester) async {
      await tester.pumpWidget(wrap(MetadataForm(
        metadataSchema: {
          'type': 'object',
          'properties': {},
        },
        onSubmit: (_, __) {},
        isLoading: true,
      )));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
