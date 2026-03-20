import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dbcrypt/dbcrypt.dart';
import 'package:postgres/postgres.dart';

import '../db/database.dart';

class Auth {
  final Database db;
  final String _jwtSecret;

  Auth({required this.db, String? jwtSecret})
      : _jwtSecret = jwtSecret ?? 'outlier-dev-secret';

  /// Create the users table if it doesn't exist.
  Future<void> migrate() async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        person_entity_id UUID UNIQUE REFERENCES entities(id),
        is_admin BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    ''');
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final passwordHash = DBCrypt().hashpw(password, DBCrypt().gensalt());

    // Check if this is the first user (auto-admin)
    final countResult =
        await db.query('SELECT COUNT(*) as count FROM users');
    final isFirstUser = (countResult.first.toColumnMap()['count'] as int) == 0;

    // Create user
    final userResult = await db.query(
      Sql.named('''
        INSERT INTO users (email, password_hash, is_admin)
        VALUES (@email, @passwordHash, @isAdmin)
        RETURNING id, email, is_admin, created_at
      '''),
      parameters: {
        'email': email,
        'passwordHash': passwordHash,
        'isAdmin': isFirstUser,
      },
    );

    final user = userResult.first.toColumnMap();
    final userId = user['id'] as String;

    // Auto-create person entity
    final personResult = await db.query(
      Sql.named('''
        INSERT INTO entities (type, name, metadata, created_by)
        VALUES ('person', @name, @metadata, @userId)
        RETURNING id
      '''),
      parameters: {
        'name': name,
        'metadata': jsonEncode({'email': email, 'role': 'member'}),
        'userId': userId,
      },
    );

    final personId = personResult.first.toColumnMap()['id'] as String;

    // Link user to person entity
    await db.execute(
      Sql.named('UPDATE users SET person_entity_id = @personId WHERE id = @userId'),
      parameters: {'personId': personId, 'userId': userId},
    );

    final token = _generateToken(userId, user['is_admin'] as bool);

    return {
      'token': token,
      'user': {
        'id': userId,
        'email': email,
        'name': name,
        'is_admin': user['is_admin'],
        'person_entity_id': personId,
      },
    };
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final result = await db.query(
      Sql.named('''
        SELECT u.*, e.name as person_name
        FROM users u
        LEFT JOIN entities e ON u.person_entity_id = e.id
        WHERE u.email = @email
      '''),
      parameters: {'email': email},
    );

    if (result.isEmpty) {
      throw ArgumentError('Invalid credentials');
    }

    final user = result.first.toColumnMap();
    final validPassword =
        DBCrypt().checkpw(password, user['password_hash'] as String);
    if (!validPassword) {
      throw ArgumentError('Invalid credentials');
    }

    final token =
        _generateToken(user['id'] as String, user['is_admin'] as bool);

    return {
      'token': token,
      'user': {
        'id': user['id'],
        'email': user['email'],
        'name': user['person_name'],
        'is_admin': user['is_admin'],
        'person_entity_id': user['person_entity_id'],
      },
    };
  }

  Future<Map<String, dynamic>?> getUserFromToken(String token) async {
    try {
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      final payload = jwt.payload as Map<String, dynamic>;
      final userId = payload['sub'] as String;

      final result = await db.query(
        Sql.named('''
          SELECT u.*, e.name as person_name
          FROM users u
          LEFT JOIN entities e ON u.person_entity_id = e.id
          WHERE u.id = @id
        '''),
        parameters: {'id': userId},
      );

      if (result.isEmpty) return null;

      final user = result.first.toColumnMap();
      return {
        'id': user['id'],
        'email': user['email'],
        'name': user['person_name'],
        'is_admin': user['is_admin'],
        'person_entity_id': user['person_entity_id'],
      };
    } catch (_) {
      return null;
    }
  }

  String _generateToken(String userId, bool isAdmin) {
    final jwt = JWT({
      'sub': userId,
      'is_admin': isAdmin,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
    return jwt.sign(SecretKey(_jwtSecret),
        expiresIn: Duration(days: 7));
  }
}
