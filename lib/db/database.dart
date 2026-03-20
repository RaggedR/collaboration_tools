import 'dart:io';

import 'package:postgres/postgres.dart';

class Database {
  final Connection _conn;

  Database._(this._conn);

  static Future<Database> connect(String databaseUrl) async {
    final conn = await Connection.open(
      _parseEndpoint(databaseUrl),
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );
    return Database._(conn);
  }

  Future<void> migrate() async {
    await _conn.execute('''
      CREATE TABLE IF NOT EXISTS entity_types (
        key TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        plural TEXT NOT NULL,
        icon TEXT,
        color TEXT NOT NULL DEFAULT '#6b7280',
        hidden BOOLEAN NOT NULL DEFAULT FALSE,
        metadata_schema JSONB,
        sort_order INTEGER NOT NULL DEFAULT 0
      );
    ''');

    await _conn.execute('''
      CREATE TABLE IF NOT EXISTS rel_types (
        key TEXT PRIMARY KEY,
        forward_label TEXT NOT NULL,
        reverse_label TEXT NOT NULL,
        source_types TEXT[] NOT NULL,
        target_types TEXT[] NOT NULL,
        "symmetric" BOOLEAN NOT NULL DEFAULT FALSE,
        metadata_schema JSONB
      );
    ''');

    await _conn.execute('''
      CREATE TABLE IF NOT EXISTS permission_rules (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        rule_type TEXT NOT NULL,
        entity_type_key TEXT REFERENCES entity_types(key),
        rel_type_key TEXT REFERENCES rel_types(key),
        config JSONB NOT NULL DEFAULT '{}'
      );
    ''');

    await _conn.execute('''
      CREATE TABLE IF NOT EXISTS entities (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        type TEXT NOT NULL REFERENCES entity_types(key),
        name TEXT NOT NULL,
        metadata JSONB NOT NULL DEFAULT '{}',
        created_by UUID,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    ''');

    await _conn.execute('''
      CREATE TABLE IF NOT EXISTS relationships (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        rel_type_key TEXT NOT NULL REFERENCES rel_types(key),
        source_entity_id UUID NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
        target_entity_id UUID NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
        metadata JSONB NOT NULL DEFAULT '{}',
        created_by UUID,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    ''');
  }

  Future<Result> query(Object sql, {Object? parameters}) {
    return _conn.execute(sql, parameters: parameters);
  }

  Future<Result> execute(Object sql, {Object? parameters}) {
    return _conn.execute(sql, parameters: parameters);
  }

  Future<R> runTx<R>(Future<R> Function(TxSession session) fn) {
    return _conn.runTx(fn);
  }

  Future<void> close() async {
    await _conn.close();
  }

  static Endpoint _parseEndpoint(String url) {
    final uri = Uri.parse(url);
    return Endpoint(
      host: uri.host.isEmpty ? 'localhost' : uri.host,
      port: uri.port == 0 ? 5432 : uri.port,
      database: uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'postgres',
      username: uri.userInfo.contains(':')
          ? uri.userInfo.split(':').first
          : uri.userInfo.isNotEmpty
              ? uri.userInfo
              : Platform.environment['USER'],
      password: uri.userInfo.contains(':')
          ? uri.userInfo.split(':').last
          : null,
    );
  }
}
