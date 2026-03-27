import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/entity.dart';
import 'models/relationship.dart';
import 'models/schema.dart';
import 'models/auth.dart';

/// Typed exceptions for API errors.
class ApiException implements Exception {
  final String code;
  final String message;
  final String? field;
  final int statusCode;

  ApiException({
    required this.code,
    required this.message,
    this.field,
    required this.statusCode,
  });

  @override
  String toString() => 'ApiException($code: $message)';
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

class UnauthorizedException implements Exception {}

/// Abstraction over token storage for testability.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// HTTP client wrapping all REST API endpoints.
class ApiClient {
  final String baseUrl;
  final TokenStore tokenStore;
  final http.Client _client;

  ApiClient({
    required this.baseUrl,
    required this.tokenStore,
    http.Client? client,
  }) : _client = client ?? http.Client();

  // --- Auth ---

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final response = await _post('/api/auth/register', {
      'email': email,
      'password': password,
      'name': name,
    });
    return AuthResponse.fromJson(response);
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    return AuthResponse.fromJson(response);
  }

  Future<User> me() async {
    final response = await _get('/api/auth/me');
    return User.fromJson(response);
  }

  // --- Schema ---

  Future<Schema> getSchema() async {
    final response = await _get('/api/schema');
    return Schema.fromJson(response);
  }

  // --- Entities ---

  Future<PaginatedEntities> listEntities({
    String? type,
    String? search,
    Map<String, dynamic>? metadata,
    String? relatedTo,
    String? relType,
    int page = 1,
    int perPage = 50,
  }) async {
    final params = <String, String>{};
    if (type != null) params['type'] = type;
    if (search != null) params['search'] = search;
    if (metadata != null) params['metadata'] = jsonEncode(metadata);
    if (relatedTo != null) params['related_to'] = relatedTo;
    if (relType != null) params['rel_type'] = relType;
    params['page'] = page.toString();
    params['per_page'] = perPage.toString();

    final response = await _get('/api/entities', queryParams: params);
    return PaginatedEntities.fromJson(response);
  }

  Future<EntityWithRelationships> getEntity(String id) async {
    final response = await _get('/api/entities/$id');
    return EntityWithRelationships.fromJson(response);
  }

  Future<Entity> createEntity({
    required String type,
    required String name,
    String? body,
    Map<String, dynamic> metadata = const {},
  }) async {
    final response = await _post('/api/entities', {
      'type': type,
      'name': name,
      if (body != null) 'body': body,
      'metadata': metadata,
    });
    return Entity.fromJson(response['entity'] as Map<String, dynamic>);
  }

  Future<Entity> updateEntity(
    String id, {
    String? name,
    String? body,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _put('/api/entities/$id', {
      if (name != null) 'name': name,
      if (body != null) 'body': body,
      if (metadata != null) 'metadata': metadata,
    });
    return Entity.fromJson(response['entity'] as Map<String, dynamic>);
  }

  /// Upload a file and return its URL path.
  Future<String> uploadFile(List<int> bytes, String filename) async {
    final token = await tokenStore.read();
    final uri = Uri.parse('$baseUrl/api/upload');
    final request = http.MultipartRequest('POST', uri);
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
    ));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final responseBody = _handleResponse(response);
    return responseBody['url'] as String;
  }

  Future<void> deleteEntity(String id) async {
    await _delete('/api/entities/$id');
  }

  // --- Convenience methods ---

  Future<PaginatedEntities> listTasks({
    Map<String, dynamic>? metadata,
    String? assigneeId,
    String? sprintId,
    String? projectId,
    int page = 1,
    int perPage = 50,
  }) {
    return listEntities(
      type: 'task',
      metadata: metadata,
      relatedTo: assigneeId ?? sprintId ?? projectId,
      relType: assigneeId != null
          ? 'assigned_to'
          : sprintId != null
              ? 'in_sprint'
              : projectId != null
                  ? 'contains_task'
                  : null,
      page: page,
      perPage: perPage,
    );
  }

  Future<PaginatedEntities> listSprints({
    String? ownerId,
    String? participantId,
    int page = 1,
    int perPage = 50,
  }) {
    final relatedId = participantId ?? ownerId;
    final relKey = participantId != null
        ? 'participates_in'
        : ownerId != null
            ? 'owned_by'
            : null;
    return listEntities(
      type: 'sprint',
      relatedTo: relatedId,
      relType: relKey,
      page: page,
      perPage: perPage,
    );
  }

  Future<PaginatedEntities> listDocuments({
    String? docType,
    String? authorId,
    String? taskId,
    String? projectId,
    int page = 1,
    int perPage = 50,
  }) {
    Map<String, dynamic>? metadata;
    if (docType != null) metadata = {'doc_type': docType};
    return listEntities(
      type: 'document',
      metadata: metadata,
      relatedTo: authorId ?? taskId ?? projectId,
      relType: authorId != null
          ? 'authored'
          : taskId != null
              ? 'contains_doc'
              : projectId != null
                  ? 'contains_doc'
              : null,
      page: page,
      perPage: perPage,
    );
  }

  // --- Relationships ---

  Future<List<Relationship>> listRelationships({
    String? entityId,
    String? relType,
    int? page,
    int? perPage,
  }) async {
    final params = <String, String>{};
    if (entityId != null) params['entity_id'] = entityId;
    if (relType != null) params['rel_type'] = relType;
    if (page != null) params['page'] = page.toString();
    if (perPage != null) params['per_page'] = perPage.toString();

    final response = await _getList('/api/relationships', queryParams: params);
    return response
        .map((r) => Relationship.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<Relationship> createRelationship({
    required String relTypeKey,
    required String sourceEntityId,
    required String targetEntityId,
    Map<String, dynamic> metadata = const {},
  }) async {
    final response = await _post('/api/relationships', {
      'rel_type_key': relTypeKey,
      'source_entity_id': sourceEntityId,
      'target_entity_id': targetEntityId,
      'metadata': metadata,
    });
    return Relationship.fromJson(response);
  }

  Future<void> deleteRelationship(String id) async {
    await _delete('/api/relationships/$id');
  }

  // --- Internal HTTP helpers ---

  Future<Map<String, String>> get _headers async {
    final token = await tokenStore.read();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? queryParams}) async {
    try {
      final uri = Uri.parse('$baseUrl$path')
          .replace(queryParameters: queryParams?.isNotEmpty == true ? queryParams : null);
      final response = await _client.get(uri, headers: await _headers);
      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    }
  }

  Future<List<dynamic>> _getList(String path,
      {Map<String, String>? queryParams}) async {
    try {
      final uri = Uri.parse('$baseUrl$path')
          .replace(queryParameters: queryParams?.isNotEmpty == true ? queryParams : null);
      final response = await _client.get(uri, headers: await _headers);
      if (response.statusCode == 401) throw UnauthorizedException();
      if (response.statusCode >= 400) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final error = body['error'] as Map<String, dynamic>?;
        throw ApiException(
          code: error?['code'] as String? ?? 'ERROR',
          message: error?['message'] as String? ?? 'Unknown error',
          field: error?['field'] as String?,
          statusCode: response.statusCode,
        );
      }
      return jsonDecode(response.body) as List<dynamic>;
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    }
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await _client.post(uri,
          headers: await _headers, body: jsonEncode(body));
      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    }
  }

  Future<Map<String, dynamic>> _put(
      String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await _client.put(uri,
          headers: await _headers, body: jsonEncode(body));
      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    }
  }

  Future<void> _delete(String path) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await _client.delete(uri, headers: await _headers);
      if (response.statusCode == 401) throw UnauthorizedException();
      if (response.statusCode >= 400 && response.statusCode != 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final error = body['error'] as Map<String, dynamic>?;
        throw ApiException(
          code: error?['code'] as String? ?? 'ERROR',
          message: error?['message'] as String? ?? 'Unknown error',
          statusCode: response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 401) throw UnauthorizedException();
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      final error = body['error'] as Map<String, dynamic>?;
      throw ApiException(
        code: error?['code'] as String? ?? 'ERROR',
        message: error?['message'] as String? ?? 'Unknown error',
        field: error?['field'] as String?,
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  void dispose() => _client.close();
}
