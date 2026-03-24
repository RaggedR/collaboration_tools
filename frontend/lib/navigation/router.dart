import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/my_page/my_page_screen.dart';
import '../screens/tasks/tasks_screen.dart';
import '../screens/sprints/sprints_screen.dart';
import '../screens/documents/documents_screen.dart';
import '../screens/graph/graph_screen.dart';
import 'app_shell.dart';
import '../state/providers.dart';

/// Central route configuration.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/my-page',
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) return '/my-page';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-page',
                builder: (context, state) => const MyPageScreen(),
              ),
              GoRoute(
                path: '/person/:id',
                builder: (context, state) => MyPageScreen(
                  personId: state.pathParameters['id'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tasks',
                builder: (context, state) => const TasksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sprints',
                builder: (context, state) => const SprintsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/documents',
                builder: (context, state) => const DocumentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/graph',
                builder: (context, state) => const GraphScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
