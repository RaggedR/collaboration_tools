# Component: API Client Layer

## Overview

The API client is a pure Dart layer (no Flutter imports) that wraps all REST endpoints. It handles authentication headers, JSON serialisation/deserialisation, error mapping, and pagination. Every screen reads data through Riverpod state providers, which in turn call the API client.

---

## `ApiClient` Class Interface

```dart
class ApiClient {
  final String baseUrl;        // e.g. 'http://localhost:8080'
  final TokenStore tokenStore; // reads/writes JWT

  // --- Auth ---
  Future<AuthResponse> register({required String email, required String password, required String name});
  Future<AuthResponse> login({required String email, required String password});
  Future<User> me();

  // --- Schema ---
  Future<Schema> getSchema();

  // --- Entities (generic) ---
  Future<PaginatedEntities> listEntities({String? type, String? search, Map<String, dynamic>? metadata, String? relatedTo, String? relType, int page = 1, int perPage = 50});
  Future<EntityWithRelationships> getEntity(String id);
  Future<Entity> createEntity({required String type, required String name, Map<String, dynamic> metadata = const {}});
  Future<Entity> updateEntity(String id, {String? name, Map<String, dynamic>? metadata});
  Future<void> deleteEntity(String id);

  // --- Relationships ---
  Future<List<Relationship>> listRelationships({String? entityId, String? relType, int? page, int? perPage});
  Future<Relationship> createRelationship({required String relTypeKey, required String sourceEntityId, required String targetEntityId, Map<String, dynamic> metadata = const {}});
  Future<void> deleteRelationship(String id);

  // --- Graph ---
  Future<Graph> getGraph({String? rootId, int? depth, List<String>? types});

  // --- Plugins ---
  Future<Schema> installPlugin(Map<String, dynamic> config);
  Future<Map<String, dynamic>> exportPlugin();
}
```

---

## Convenience Methods

These wrap `listEntities` with domain-specific parameter names. They exist for readability at the call site — the underlying HTTP call is the same.

```dart
// Tasks
Future<PaginatedEntities> listTasks({
  String? status,          // → metadata: {"status": status}
  String? priority,        // → metadata: {"priority": priority}
  String? assigneeId,      // → relatedTo: assigneeId, relType: "assigned_to"
  String? sprintId,        // → relatedTo: sprintId, relType: "in_sprint"  (reverse)
  String? projectId,       // → relatedTo: projectId, relType: "contains_task" (reverse)
  int page = 1,
});

// Sprints
Future<PaginatedEntities> listSprints({
  String? ownerId,         // → relatedTo: ownerId, relType: "owned_by"
  int page = 1,
});

// Documents
Future<PaginatedEntities> listDocuments({
  String? docType,         // → metadata: {"doc_type": docType}
  String? authorId,        // → relatedTo: authorId, relType: "authored" (reverse)
  String? projectId,       // → relatedTo: projectId, relType: "contains_doc" (reverse)
  int page = 1,
});
```

---

## Response Models

All models are immutable Dart classes with `fromJson` factory constructors and `toJson` methods. They mirror the API JSON exactly.

### `Entity`

```dart
class Entity {
  final String id;
  final String type;
  final String name;
  final Map<String, dynamic> metadata;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### `EntityWithRelationships`

```dart
class EntityWithRelationships {
  final Entity entity;
  final List<ResolvedRelationship> relationships;
}
```

### `ResolvedRelationship`

```dart
class ResolvedRelationship {
  final String id;
  final String relTypeKey;    // e.g. "assigned_to"
  final String direction;     // "forward" or "reverse"
  final String label;         // e.g. "assigned to" or "responsible for"
  final RelatedEntity relatedEntity;
  final Map<String, dynamic> metadata;
}

class RelatedEntity {
  final String id;
  final String type;
  final String name;
}
```

### `Relationship` (raw, from list endpoint)

```dart
class Relationship {
  final String id;
  final String relTypeKey;
  final String sourceEntityId;
  final String targetEntityId;
  final Map<String, dynamic> metadata;
  final String? createdBy;
  final DateTime createdAt;
}
```

### `Schema`

```dart
class Schema {
  final AppConfig app;
  final List<EntityType> entityTypes;
  final List<RelType> relTypes;
  final List<PermissionRule> permissionRules;
}

class AppConfig {
  final String name;          // "Collaboration Tools"
  final String description;
  final String themeColor;    // "#2563eb"
  final String? logoUrl;
}

class EntityType {
  final String key;           // "task"
  final String label;         // "Task"
  final String plural;        // "Tasks"
  final String icon;          // "check_circle"
  final String color;         // "#10b981"
  final bool hidden;
  final Map<String, dynamic> metadataSchema;
}

class RelType {
  final String key;           // "assigned_to"
  final String forwardLabel;  // "assigned to"
  final String reverseLabel;  // "responsible for"
  final List<String> sourceTypes;  // ["task"]
  final List<String> targetTypes;  // ["person"]
  final bool symmetric;
}

class PermissionRule {
  final String ruleType;      // "admin_only_entity_type" or "edit_granting_rel_type"
  final String? entityTypeKey;
  final String? relTypeKey;
}
```

### `Graph`

```dart
class Graph {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
}

class GraphNode {
  final String id;
  final String type;
  final String name;
  final String color;
  final String? icon;
}

class GraphEdge {
  final String id;
  final String source;    // entity ID
  final String target;    // entity ID
  final String relType;   // rel type key
  final String label;
}
```

### `Auth`

```dart
class AuthResponse {
  final String token;
  final User user;
}

class User {
  final String id;
  final String email;
  final String name;
  final bool isAdmin;
  final String? personEntityId;  // the person entity linked to this user
}
```

### `PaginatedEntities`

```dart
class PaginatedEntities {
  final List<Entity> entities;
  final int total;
  final int page;
  final int perPage;
}
```

---

## Token Management

```
┌────────────────┐     ┌───────────────┐     ┌──────────────┐
│ flutter_secure  │────▶│  TokenStore    │────▶│  ApiClient   │
│    _storage     │     │  read/write   │     │  attaches    │
│ (encrypted)     │     │  JWT string   │     │  Bearer hdr  │
└────────────────┘     └───────────────┘     └──────────────┘
```

- `TokenStore` is an abstraction over `flutter_secure_storage` to allow test injection
- On login/register: store the JWT token
- On every API call: read token, attach `Authorization: Bearer <token>` header
- On 401 response: clear token, redirect to login screen
- On logout: clear token

---

## Error Handling

### Error Types

```dart
class ApiException implements Exception {
  final String code;      // "VALIDATION_ERROR", "FORBIDDEN", etc.
  final String message;   // Human-readable
  final String? field;    // Which field failed (for form errors)
  final int statusCode;
}

class NetworkException implements Exception {
  final String message;   // "Connection refused", "Timeout", etc.
}

class UnauthorizedException implements Exception {}
```

### Error Mapping

| HTTP Status | Exception | Frontend Action |
|-------------|-----------|-----------------|
| 400 | `ApiException(code, message, field)` | Show field-level error or snackbar |
| 401 | `UnauthorizedException` | Clear token, redirect to login |
| 403 | `ApiException('FORBIDDEN', ...)` | Show "permission denied" message |
| 404 | `ApiException('NOT_FOUND', ...)` | Show "not found" screen or snackbar |
| 5xx | `ApiException` | Show generic error snackbar |
| Network error | `NetworkException` | Show "unable to connect" banner |

### Response Parsing Pattern

```dart
Future<T> _request<T>(
  String method,
  String path, {
  Map<String, dynamic>? body,
  Map<String, String>? queryParams,
  required T Function(Map<String, dynamic>) parser,
}) async {
  // 1. Build URL with query params
  // 2. Attach auth header
  // 3. Make request
  // 4. If 401: throw UnauthorizedException
  // 5. If 4xx/5xx: parse error body, throw ApiException
  // 6. Parse success body with parser function
}
```

---

## `related_to` API Enhancement (Blocking Dependency)

The current `GET /api/entities` only supports `type`, `search`, `metadata`, `page`, `per_page` query parameters. The My Page feature needs:

```
GET /api/entities?type=task&related_to=<personId>&rel_type=assigned_to
```

**What this does:** Returns entities of the given type that have a relationship of the given type to/from the specified entity. The backend needs to JOIN the relationships table.

**New query parameters:**

| Param | Type | Description |
|-------|------|-------------|
| `related_to` | UUID | Entity ID to filter by relationship |
| `rel_type` | string | Relationship type key to filter by |

Both must be provided together. `related_to` alone is ambiguous; `rel_type` alone is meaningless without a target entity.

**Backend changes needed:**
1. `entity_queries.dart` — add JOIN to relationships table when `relatedTo` + `relType` params are present
2. `entity_handler.dart` — pass new query params through to `entities.list()`
3. `API.md` — document the new parameters

**Without this enhancement,** loading My Page requires:
1. `GET /api/entities/:personId` (get person with relationships)
2. For each assigned task: `GET /api/entities/:taskId`
3. For each owned sprint: `GET /api/entities/:sprintId`
4. For each authored doc: `GET /api/entities/:docId`

This is N+1 and unacceptable. The `related_to` filter reduces it to 3 parallel calls.

---

## Usage in State Layer

The state layer (Riverpod providers) is the only consumer of `ApiClient`. Screens never call the API directly.

```dart
// Example: MyPageState calls ApiClient
final myPageProvider = FutureProvider.family<MyPageData, String>((ref, personId) async {
  final api = ref.read(apiClientProvider);
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
```
