import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';

/// Manages a test server process for E2E tests.
///
/// Starts the Dart backend against a test database, waits for it to be
/// ready, and tears it down after tests complete.
class TestServer {
  Process? _process;
  int _actualPort = 0;
  final String databaseUrl;

  TestServer({
    String? databaseUrl,
  }) : databaseUrl = databaseUrl ??
            Platform.environment['DATABASE_URL'] ??
            'postgresql://outlier:outlier@localhost:5433/outlier_test';

  String get baseUrl => 'http://localhost:$_actualPort';

  /// Truncates all application tables so each test suite starts clean.
  Future<void> _resetDatabase() async {
    final uri = Uri.parse(databaseUrl);
    final conn = await Connection.open(
      Endpoint(
        host: uri.host.isEmpty ? 'localhost' : uri.host,
        port: uri.port == 0 ? 5433 : uri.port,
        database:
            uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'outlier_test',
        username: uri.userInfo.contains(':')
            ? uri.userInfo.split(':').first
            : uri.userInfo.isNotEmpty
                ? uri.userInfo
                : 'outlier',
        password:
            uri.userInfo.contains(':') ? uri.userInfo.split(':').last : null,
      ),
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );

    // Drop all tables so each suite starts with a fresh schema.
    // The server's migrate() call will recreate them.
    await conn.execute(
        'DROP TABLE IF EXISTS relationships, entities, users, permission_rules, rel_types, entity_types CASCADE');
    await conn.close();
  }

  /// Starts the server and waits until it responds to health checks.
  Future<void> start() async {
    await _resetDatabase();

    _process = await Process.start(
      'dart',
      ['run', 'bin/server.dart'],
      environment: {
        'PORT': '0', // Let OS pick a free port
        'DATABASE_URL': databaseUrl,
        'ENV': 'test',
      },
    );

    // Read stderr to find the actual port
    final portCompleter = Completer<int>();
    _process!.stderr.transform(utf8.decoder).listen((data) {
      final match = RegExp(r'port (\d+)').firstMatch(data);
      if (match != null && !portCompleter.isCompleted) {
        portCompleter.complete(int.parse(match.group(1)!));
      }
    });

    // Forward stdout for debugging
    _process!.stdout.transform(utf8.decoder).listen((_) {});

    // Wait for port assignment (up to 30 seconds for first compile)
    _actualPort = await portCompleter.future
        .timeout(Duration(seconds: 30), onTimeout: () {
      throw StateError('Server failed to report port within 30 seconds');
    });

    // Wait for server to be ready (respond to health check)
    final timeout = DateTime.now().add(Duration(seconds: 10));
    while (DateTime.now().isBefore(timeout)) {
      try {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse('$baseUrl/api/schema'));
        final response = await request.close();
        if (response.statusCode == 200) {
          client.close();
          return;
        }
        client.close();
      } catch (_) {
        // Server not ready yet
      }
      await Future.delayed(Duration(milliseconds: 200));
    }
    throw StateError('Server failed to start within 10 seconds');
  }

  /// Stops the server process.
  Future<void> stop() async {
    _process?.kill();
    await _process?.exitCode;
    _process = null;
  }
}
