import 'dart:convert';
import 'package:http/http.dart' as http;

/// HTTP client wrapper for E2E API tests.
///
/// Manages auth tokens and provides typed methods for every endpoint
/// in the API contract. Tests call these methods — never raw HTTP —
/// so the test suite is insulated from URL changes.
class TestClient {
  final String baseUrl;
  String? _authToken;
  final http.Client _client;

  TestClient({required this.baseUrl}) : _client = http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  // ── Auth ──────────────────────────────────────────────────

  Future<http.Response> register({
    required String email,
    required String password,
    String name = 'Test User',
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password, 'name': name}),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      _authToken = body['token'] as String?;
    }
    return response;
  }

  Future<http.Response> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      _authToken = body['token'] as String?;
    }
    return response;
  }

  Future<http.Response> me() =>
      _client.get(Uri.parse('$baseUrl/api/auth/me'), headers: _headers);

  void setToken(String token) => _authToken = token;
  void clearToken() => _authToken = null;
  bool get isAuthenticated => _authToken != null;

  // ── Schema ────────────────────────────────────────────────

  Future<http.Response> getSchema() =>
      _client.get(Uri.parse('$baseUrl/api/schema'), headers: _headers);

  Future<http.Response> getEntityTypes() =>
      _client.get(Uri.parse('$baseUrl/api/entity-types'), headers: _headers);

  Future<http.Response> getRelTypes() =>
      _client.get(Uri.parse('$baseUrl/api/rel-types'), headers: _headers);

  // ── Entities ──────────────────────────────────────────────

  Future<http.Response> listEntities({
    String? type,
    String? search,
    Map<String, dynamic>? metadata,
    int? page,
    int? perPage,
  }) {
    final params = <String, String>{};
    if (type != null) params['type'] = type;
    if (search != null) params['search'] = search;
    if (metadata != null) params['metadata'] = jsonEncode(metadata);
    if (page != null) params['page'] = page.toString();
    if (perPage != null) params['per_page'] = perPage.toString();
    final uri =
        Uri.parse('$baseUrl/api/entities').replace(queryParameters: params);
    return _client.get(uri, headers: _headers);
  }

  Future<http.Response> getEntity(String id) =>
      _client.get(Uri.parse('$baseUrl/api/entities/$id'), headers: _headers);

  Future<http.Response> createEntity({
    required String type,
    required String name,
    Map<String, dynamic> metadata = const {},
  }) {
    return _client.post(
      Uri.parse('$baseUrl/api/entities'),
      headers: _headers,
      body: jsonEncode({'type': type, 'name': name, 'metadata': metadata}),
    );
  }

  Future<http.Response> updateEntity(
    String id, {
    String? name,
    Map<String, dynamic>? metadata,
  }) {
    return _client.put(
      Uri.parse('$baseUrl/api/entities/$id'),
      headers: _headers,
      body: jsonEncode({
        if (name != null) 'name': name,
        if (metadata != null) 'metadata': metadata,
      }),
    );
  }

  Future<http.Response> deleteEntity(String id) =>
      _client.delete(Uri.parse('$baseUrl/api/entities/$id'), headers: _headers);

  // ── Relationships ─────────────────────────────────────────

  Future<http.Response> listRelationships({
    String? entityId,
    String? relType,
    int? page,
    int? perPage,
  }) {
    final params = <String, String>{};
    if (entityId != null) params['entity_id'] = entityId;
    if (relType != null) params['rel_type'] = relType;
    if (page != null) params['page'] = page.toString();
    if (perPage != null) params['per_page'] = perPage.toString();
    final uri = Uri.parse('$baseUrl/api/relationships')
        .replace(queryParameters: params);
    return _client.get(uri, headers: _headers);
  }

  Future<http.Response> createRelationship({
    required String relTypeKey,
    required String sourceEntityId,
    required String targetEntityId,
    Map<String, dynamic> metadata = const {},
  }) {
    return _client.post(
      Uri.parse('$baseUrl/api/relationships'),
      headers: _headers,
      body: jsonEncode({
        'rel_type_key': relTypeKey,
        'source_entity_id': sourceEntityId,
        'target_entity_id': targetEntityId,
        'metadata': metadata,
      }),
    );
  }

  Future<http.Response> deleteRelationship(String id) => _client.delete(
      Uri.parse('$baseUrl/api/relationships/$id'),
      headers: _headers);

  // ── Graph ─────────────────────────────────────────────────

  Future<http.Response> getGraph({
    String? rootId,
    int? depth,
    List<String>? types,
  }) {
    final params = <String, String>{};
    if (rootId != null) params['root_id'] = rootId;
    if (depth != null) params['depth'] = depth.toString();
    if (types != null) params['types'] = types.join(',');
    final uri =
        Uri.parse('$baseUrl/api/graph').replace(queryParameters: params);
    return _client.get(uri, headers: _headers);
  }

  // ── Plugins ───────────────────────────────────────────────

  Future<http.Response> installPlugin(Map<String, dynamic> schemaConfig) {
    return _client.post(
      Uri.parse('$baseUrl/api/plugins/install'),
      headers: _headers,
      body: jsonEncode(schemaConfig),
    );
  }

  Future<http.Response> exportPlugin() =>
      _client.get(Uri.parse('$baseUrl/api/plugins/export'), headers: _headers);

  // ── Lifecycle ─────────────────────────────────────────────

  void dispose() => _client.close();
}
