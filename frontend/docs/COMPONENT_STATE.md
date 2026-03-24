# Component: State Management

## Overview

State management uses **Riverpod** throughout. The state tree is split into global providers (schema, auth) and per-screen providers (scoped to parameters like person ID or filter state). The `family` modifier is the key enabler for My Page — it creates isolated state per person ID.

---

## Why Riverpod

1. **`family` modifier** — `myPageProvider.call(personId)` creates separate state for each person's page. This is the killer feature for My Page: visiting Robin's page and then Sarah's page keeps both cached.
2. **Testability** — `ProviderContainer` overrides let us inject mock API clients in tests without complex DI setup.
3. **Automatic disposal** — when a screen is popped, its `autoDispose` providers clean up. No manual stream management.
4. **Cross-provider invalidation** — when a task's status changes on the Tasks screen, we can invalidate the relevant My Page provider to trigger a refresh.

---

## State Tree

```
Global (lives for app lifetime)
├── schemaProvider          — Schema (entity types, rel types, permission rules)
├── authProvider            — AuthState (user, token, isAdmin, personEntityId)
└── apiClientProvider       — ApiClient instance (depends on auth for token)

Per-Screen (autoDispose, scoped to parameters)
├── myPageProvider(personId)          — MyPageData (tasks, sprints, docs for this person)
├── taskBoardProvider(filters)        — TaskBoardState (all tasks, grouped by status)
├── sprintListProvider(filters)       — SprintListState (sprints, grouped by status)
├── documentListProvider(filters)     — DocumentListState (filtered document list)
├── entityDetailProvider(entityId)    — EntityWithRelationships
└── graphProvider(graphParams)        — Graph (nodes + edges)
```

---

## Provider Definitions

### Global Providers

```dart
// Schema — fetched once after login, refreshed on plugin install
final schemaProvider = StateNotifierProvider<SchemaNotifier, AsyncValue<Schema>>((ref) {
  return SchemaNotifier(ref.read(apiClientProvider));
});

class SchemaNotifier extends StateNotifier<AsyncValue<Schema>> {
  final ApiClient _api;
  SchemaNotifier(this._api) : super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _api.getSchema());
  }
}

// Auth — manages login/register/logout, persists token
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiClientProvider));
});

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user != null;
  bool get isAdmin => user?.isAdmin ?? false;
  String? get personEntityId => user?.personEntityId;
}

// API Client — singleton, reads token from auth
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: const String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080'),
    tokenStore: ref.read(tokenStoreProvider),
  );
});
```

### Per-Screen Providers

```dart
// My Page — family by personId
final myPageProvider = FutureProvider.autoDispose.family<MyPageData, String>((ref, personId) async {
  final api = ref.read(apiClientProvider);
  // Three parallel fetches (requires related_to API enhancement)
  final results = await Future.wait([
    api.listTasks(assigneeId: personId),
    api.listSprints(ownerId: personId),
    api.listDocuments(authorId: personId),
  ]);
  return MyPageData(
    tasks: results[0] as PaginatedEntities,
    sprints: results[1] as PaginatedEntities,
    documents: results[2] as PaginatedEntities,
  );
});

// Task Board — StateNotifier for optimistic updates
final taskBoardProvider = StateNotifierProvider.autoDispose<TaskBoardNotifier, TaskBoardState>((ref) {
  return TaskBoardNotifier(ref.read(apiClientProvider), ref);
});

class TaskBoardState {
  final Map<String, List<Entity>> columns; // status → tasks
  final TaskFilters filters;
  final bool isLoading;
  final String? error;
}

// Sprint List
final sprintListProvider = FutureProvider.autoDispose.family<SprintListData, SprintFilters>((ref, filters) async {
  final api = ref.read(apiClientProvider);
  return api.listSprints(ownerId: filters.ownerId);
});

// Document List
final documentListProvider = FutureProvider.autoDispose.family<PaginatedEntities, DocumentFilters>((ref, filters) async {
  final api = ref.read(apiClientProvider);
  return api.listDocuments(
    docType: filters.docType,
    authorId: filters.authorId,
    projectId: filters.projectId,
  );
});

// Entity Detail — used by detail panels across screens
final entityDetailProvider = FutureProvider.autoDispose.family<EntityWithRelationships, String>((ref, entityId) async {
  final api = ref.read(apiClientProvider);
  return api.getEntity(entityId);
});

// Graph
final graphProvider = FutureProvider.autoDispose.family<Graph, GraphParams>((ref, params) async {
  final api = ref.read(apiClientProvider);
  return api.getGraph(rootId: params.rootId, depth: params.depth, types: params.types);
});
```

---

## Optimistic Updates

Kanban drag-and-drop is the primary use case. The pattern:

```dart
class TaskBoardNotifier extends StateNotifier<TaskBoardState> {
  final ApiClient _api;
  final Ref _ref;

  Future<void> moveTask(String taskId, String fromStatus, String toStatus) async {
    // 1. Snapshot current state (for rollback)
    final snapshot = state;

    // 2. Optimistic update — move card immediately
    state = state.moveTask(taskId, fromStatus, toStatus);

    // 3. API call
    try {
      final task = state.findTask(taskId);
      await _api.updateEntity(taskId, metadata: {
        ...task.metadata,
        'status': toStatus,
      });
      // 4a. Success — invalidate affected My Page providers
      _ref.invalidate(myPageProvider(task.assigneeId));
    } catch (e) {
      // 4b. Failure — rollback
      state = snapshot;
      // Show error via a separate error provider or callback
    }
  }
}
```

### Why Optimistic Updates Matter

Kanban drag-and-drop needs to feel instant. A 200ms API round-trip with a loading spinner destroys the UX. By moving the card immediately and only rolling back on failure, the UI stays responsive.

---

## Cross-Screen Invalidation

When data changes on one screen, other screens may need to refresh. Riverpod's `ref.invalidate()` handles this:

| Action | Invalidates |
|--------|------------|
| Task status changed (kanban drag) | `myPageProvider(assigneeId)`, `taskBoardProvider` |
| Task created | `taskBoardProvider`, `myPageProvider(assigneeId)` if assigned |
| Task assigned to person | `myPageProvider(personId)` |
| Sprint created | `sprintListProvider`, `myPageProvider(ownerId)` (auto-relationship) |
| Document created | `documentListProvider`, `myPageProvider(authorId)` |
| Relationship created/deleted | `entityDetailProvider(entityId)`, relevant list providers |

The invalidation happens in the state notifier methods (e.g., `TaskBoardNotifier.moveTask`), not in the UI layer.

---

## Filter State

Filters are value objects (immutable, implement `==` and `hashCode`) used as `family` parameters:

```dart
class TaskFilters {
  final String? projectId;
  final String? assigneeId;
  final String? priority;
  final String? sprintId;
  final List<String>? labels;

  // == and hashCode based on all fields
}

class SprintFilters {
  final String? ownerId;
}

class DocumentFilters {
  final String? docType;
  final String? authorId;
  final String? projectId;
}

class GraphParams {
  final String? rootId;
  final int depth;
  final List<String>? types;
}
```

---

## Permission Helpers

Derived from `schemaProvider` and `authProvider`:

```dart
// Computed provider — no network call, pure logic
final permissionProvider = Provider<PermissionHelper>((ref) {
  final schema = ref.watch(schemaProvider).valueOrNull;
  final auth = ref.watch(authProvider);
  return PermissionHelper(
    permissionRules: schema?.permissionRules ?? [],
    isAdmin: auth.isAdmin,
    personEntityId: auth.personEntityId,
  );
});

class PermissionHelper {
  bool canCreate(String entityType);      // checks admin_only_entity_type rules
  bool canEdit(Entity entity, List<ResolvedRelationship> rels);  // checks edit_granting_rel_type
  bool canEditPage(String personId);      // admin or own page
}
```

---

## Testing Strategy

Riverpod's `ProviderContainer` makes testing straightforward:

```dart
// Override the API client with a mock
final container = ProviderContainer(overrides: [
  apiClientProvider.overrideWithValue(mockApiClient),
]);

// Read a provider and verify
final myPage = await container.read(myPageProvider('person-123').future);
expect(myPage.tasks.entities, hasLength(3));
```

No need for complex dependency injection — just override the providers you want to mock.
