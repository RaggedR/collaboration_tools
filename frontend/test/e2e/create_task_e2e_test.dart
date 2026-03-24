import 'package:flutter_test/flutter_test.dart';

/// E2E test: Create a task and verify it appears in the kanban board.
void main() {
  group('Create task E2E', () {
    testWidgets('creates task from Tasks screen', (tester) async {
      // TODO: Wire up real app with test backend
      // 1. Login, navigate to Tasks screen
      // 2. Tap "+ New Task" button
      // 3. Fill in name, select status and priority
      // 4. Tap Save
      // 5. Verify task card appears in the correct kanban column
      // 6. Verify task count updates in column header
    }, skip: true /* Stage 3 */);

    testWidgets('creates task from My Page with auto-assign',
        (tester) async {
      // TODO: Wire up real app with test backend
      // 1. Login, navigate to My Page
      // 2. Tap "+ New Task" in the tasks section
      // 3. Fill in task details
      // 4. Tap Save
      // 5. Verify task appears in My Page kanban (auto-assigned to this person)
      // 6. Verify the assigned_to relationship was created
    }, skip: true /* Stage 3 */);

    testWidgets('validates required fields before submission',
        (tester) async {
      // TODO: Wire up real app with test backend
      // 1. Login, open task create form
      // 2. Tap Save without entering name
      // 3. Verify "Name is required" validation error
      // 4. Enter name, tap Save
      // 5. Verify task is created
    }, skip: true /* Stage 3 */);

    testWidgets('shows error on backend validation failure',
        (tester) async {
      // TODO: Wire up real app with test backend
      // 1. Login, open task create form
      // 2. Submit with invalid metadata
      // 3. Verify error snackbar appears with backend error message
    }, skip: true /* Stage 3 */);
  });
}
