import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/models/auth.dart';

/// Authentication state.
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;
  bool get isAdmin => user?.isAdmin ?? false;
  String? get personEntityId => user?.personEntityId;

  AuthState copyWith({User? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;
  final TokenStore _tokenStore;

  AuthNotifier({required ApiClient api, required TokenStore tokenStore})
      : _api = api,
        _tokenStore = tokenStore,
        super(const AuthState());

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.login(email: email, password: password);
      await _tokenStore.write(response.token);
      state = AuthState(user: response.user);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response =
          await _api.register(email: email, password: password, name: name);
      await _tokenStore.write(response.token);
      state = AuthState(user: response.user);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<void> checkSession() async {
    state = state.copyWith(isLoading: true);
    final token = await _tokenStore.read();
    if (token == null) {
      // Dev auto-login: register or login a dev user so we skip the login screen
      await _devAutoLogin();
      return;
    }
    try {
      final user = await _api.me();
      state = AuthState(user: user);
    } catch (_) {
      await _tokenStore.clear();
      // Token was invalid — try dev auto-login
      await _devAutoLogin();
    }
  }

  Future<void> _devAutoLogin() async {
    const email = 'dev@localhost';
    const password = 'dev-password';
    const name = 'Dev User';
    try {
      // Try login first (user may already exist)
      final response =
          await _api.login(email: email, password: password);
      await _tokenStore.write(response.token);
      state = AuthState(user: response.user);
    } catch (_) {
      // Login failed — register instead
      try {
        final response = await _api.register(
            email: email, password: password, name: name);
        await _tokenStore.write(response.token);
        state = AuthState(user: response.user);
      } catch (_) {
        state = const AuthState();
      }
    }
  }

  Future<void> logout() async {
    await _tokenStore.clear();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  throw UnimplementedError('Override in app setup');
});
