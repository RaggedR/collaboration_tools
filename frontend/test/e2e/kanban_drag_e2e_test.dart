import 'package:flutter_test/flutter_test.dart';

/// E2E test: Drag a task card on the kanban board and verify status update.
///
/// These tests exercise the full optimistic update cycle:
/// drag → UI updates → API call → verify persistence.
void main() {
  group('Kanban drag E2E', () {
    testWidgets('dragging card changes its column', (tester) async {
      // TODO: Wire up real app with test backend
      // 1. Pre-create a task with status "todo" via API
      // 2. Pump app, navigate to Tasks screen
      // 3. Find the task card in the "Todo" column
      // 4. Drag it to the "In Progress" column
      // 5. Verify the card appears in "In Progress"
      // 6. Verify the card is gone from "Todo"
    }, skip: true /* Stage 3 */);

    testWidgets('status persists after page reload', (tester) async {
      // TODO: Wire up real app with test backend
      // 1. Pre-create a task with status "todo"
      // 2. Drag it to "in_progress"
      // 3. Navigate away and back to Tasks
      // 4. Verify the task is still in "In Progress"
      // 5. Verify API has the updated status
    }, skip: true /* Stage 3 */);

    testWidgets('read-only kanban prevents drag on others page',
        (tester) async {
      // TODO: Wire up real app with test backend
      // 1. Login as non-admin user A
      // 2. Navigate to user B's My Page
      // 3. Verify kanban cards are not draggable
      // 4. Verify no "New Task" button
    }, skip: true /* Stage 3 */);

    testWidgets('admin can drag on any persons page', (tester) async {
      // TODO: Wire up real app with test backend
      // 1. Login as admin
      // 2. Navigate to another user's My Page
      // 3. Verify kanban cards are draggable
      // 4. Drag a card, verify status updates
    }, skip: true /* Stage 3 */);
  });
}
