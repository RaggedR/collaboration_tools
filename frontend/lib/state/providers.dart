import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/models/schema.dart';
import 'auth_state.dart';
import 'permission_helper.dart';
import 'schema_state.dart';
import 'token_store_impl.dart';

/// Base URL for the backend API.
const _defaultBaseUrl = 'http://localhost:8080';

/// Token store backed by platform secure storage.
final tokenStoreProvider = Provider<TokenStore>((ref) {
  return SecureTokenStore();
});

/// HTTP API client.
final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStore = ref.watch(tokenStoreProvider);
  return ApiClient(baseUrl: _defaultBaseUrl, tokenStore: tokenStore);
});

/// Authentication state — overrides the throwing stub in auth_state.dart.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(apiClientProvider);
  final tokenStore = ref.watch(tokenStoreProvider);
  return AuthNotifier(api: api, tokenStore: tokenStore);
});

/// Schema state — loaded once after login.
final schemaProvider =
    StateNotifierProvider<SchemaNotifier, AsyncValue<Schema>>((ref) {
  final api = ref.watch(apiClientProvider);
  return SchemaNotifier(api: api);
});

/// Permission helper derived from auth + schema state.
final permissionProvider = Provider<PermissionHelper?>((ref) {
  final auth = ref.watch(authProvider);
  final schemaAsync = ref.watch(schemaProvider);

  final schema = schemaAsync.valueOrNull;
  if (schema == null || !auth.isAuthenticated) return null;

  return PermissionHelper(
    permissionRules: schema.permissionRules,
    isAdmin: auth.isAdmin,
    personEntityId: auth.personEntityId,
  );
});
