import 'package:flutter_test/flutter_test.dart';

/// E2E test: Register, login, and land on My Page.
///
/// These tests require a running backend and exercise the full
/// Flutter app with real HTTP calls. They are the last tests to
/// pass during Stage 3 implementation.
void main() {
  group('Login E2E', () {
    testWidgets('registers a new user and sees My Page', (tester) async {
      // TODO: Wire up real app with test backend
      // 1. Pump the app
      // 2. Navigate to /register
      // 3. Enter name, email, password
      // 4. Tap Register
      // 5. Verify My Page appears with the user's name
      // 6. Verify navigation shows 5 items (My Page, Tasks, Sprints, Docs, Graph)
    }, skip: true /* Stage 3 */);

    testWidgets('logs in with existing credentials', (tester) async {
      // TODO: Wire up real app with test backend
      // 1. Pre-register a user via API
      // 2. Pump the app at /login
      // 3. Enter email and password
      // 4. Tap Login
      // 5. Verify redirect to My Page
      // 6. Verify user's person data loads
    }, skip: true /* Stage 3 */);

    testWidgets('shows error for invalid credentials', (tester) async {
      // TODO: Wire up real app with test backend
      // 1. Pump the app at /login
      // 2. Enter wrong email/password
      // 3. Tap Login
      // 4. Verify error message appears
      // 5. Verify still on login screen
    }, skip: true /* Stage 3 */);

    testWidgets('cold start restores session from stored token',
        (tester) async {
      // TODO: Wire up real app with test backend
      // 1. Pre-register and store JWT token in mock secure storage
      // 2. Pump the app (no route — should auto-redirect)
      // 3. Verify app calls GET /api/auth/me
      // 4. Verify redirect to My Page
    }, skip: true /* Stage 3 */);

    testWidgets('redirects to login when token is expired', (tester) async {
      // TODO: Wire up real app with test backend
      // 1. Store an expired/invalid JWT token
      // 2. Pump the app
      // 3. Verify GET /api/auth/me returns 401
      // 4. Verify redirect to login
      // 5. Verify stored token is cleared
    }, skip: true /* Stage 3 */);
  });
}
