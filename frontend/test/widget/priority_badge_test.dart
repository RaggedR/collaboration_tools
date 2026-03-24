import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collaboration_tools/widgets/shared/priority_badge.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('PriorityBadge', () {
    testWidgets('renders low priority with correct text', (tester) async {
      await tester.pumpWidget(wrap(const PriorityBadge(priority: 'low')));

      expect(find.text('Low'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('renders medium priority with correct text', (tester) async {
      await tester.pumpWidget(wrap(const PriorityBadge(priority: 'medium')));

      expect(find.text('Medium'), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });

    testWidgets('renders high priority with correct text', (tester) async {
      await tester.pumpWidget(wrap(const PriorityBadge(priority: 'high')));

      expect(find.text('High'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('renders urgent priority with correct text', (tester) async {
      await tester.pumpWidget(wrap(const PriorityBadge(priority: 'urgent')));

      expect(find.text('Urgent'), findsOneWidget);
      expect(find.byIcon(Icons.priority_high), findsOneWidget);
    });

    testWidgets('handles unknown priority gracefully', (tester) async {
      await tester
          .pumpWidget(wrap(const PriorityBadge(priority: 'custom')));

      expect(find.text('Custom'), findsOneWidget);
    });

    test('correct colors for each priority', () {
      expect(
        const PriorityBadge(priority: 'low').color,
        equals(const Color(0xFF9CA3AF)),
      );
      expect(
        const PriorityBadge(priority: 'medium').color,
        equals(const Color(0xFF3B82F6)),
      );
      expect(
        const PriorityBadge(priority: 'high').color,
        equals(const Color(0xFFF97316)),
      );
      expect(
        const PriorityBadge(priority: 'urgent').color,
        equals(const Color(0xFFEF4444)),
      );
    });
  });
}
