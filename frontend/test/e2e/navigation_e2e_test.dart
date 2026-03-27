import 'package:flutter_test/flutter_test.dart';

/// E2E test: Navigate through all screens and verify routing.
void main() {
  group('Navigation E2E', () {
    testWidgets('navigates through all main screens', (tester) async {
      // TODO: Wire up real app with test backend
      // 1. Login
      // 2. Verify My Page is the initial screen
      // 3. Tap Tasks nav item → verify Tasks screen
      // 4. Tap Sprints nav item → verify Sprints screen
      // 5. Tap Documents nav item → verify Documents screen
      // 6. Tap My Page nav item → verify back on My Page
    }, skip: true);

    testWidgets('tapping person chip navigates to their My Page',
        (tester) async {
      // TODO: Wire up real app with test backend
      // 1. Login, create a task assigned to another person
      // 2. Navigate to Tasks screen
      // 3. Open task detail
      // 4. Tap the person chip in relationships
      // 5. Verify navigation to /person/<personId>
      // 6. Verify that person's data loads
    }, skip: true);

    testWidgets('unauthenticated user is redirected to login',
        (tester) async {
      // TODO: Wire up real app (no auth)
      // 1. Pump the app without a stored token
      // 2. Try to navigate to /tasks
      // 3. Verify redirect to /login
    }, skip: true);

    testWidgets('deep link to specific person page works', (tester) async {
      // TODO: Wire up real app with test backend
      // 1. Login
      // 2. Navigate directly to /person/<other-person-id>
      // 3. Verify the correct person's page loads
      // 4. Verify read-only mode for non-admin viewing other's page
    }, skip: true);

    testWidgets('responsive layout switches between side rail and bottom nav',
        (tester) async {
      // TODO: Wire up real app
      // 1. Pump app at desktop width (>900px)
      // 2. Verify NavigationRail is visible
      // 3. Resize to mobile width (<900px)
      // 4. Verify BottomNavigationBar is visible
      // 5. Verify NavigationRail is gone
    }, skip: true);
  });
}
