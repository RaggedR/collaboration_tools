/// Authentication response from login/register.
class AuthResponse {
  final String token;
  final User user;

  AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

/// Authenticated user.
class User {
  final String id;
  final String email;
  final String? name;
  final bool isAdmin;
  final String? personEntityId;

  User({
    required this.id,
    required this.email,
    this.name,
    required this.isAdmin,
    this.personEntityId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      isAdmin: json['is_admin'] as bool? ?? false,
      personEntityId: json['person_entity_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'is_admin': isAdmin,
        'person_entity_id': personEntityId,
      };
}
