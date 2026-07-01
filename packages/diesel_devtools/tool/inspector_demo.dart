// Smoke/target harness for the diesel DevTools inspector.
//
// Run with the VM service on so DevTools can attach:
//
//   dart run --observe packages/diesel_devtools/tool/inspector_demo.dart
//
// It seeds an in-memory SQLite database, registers it, prints what the
// inspector's core sees, then stays alive so you can open the "diesel" tab in
// DevTools and browse it live.
import 'dart:convert';
import 'dart:io';

import 'package:diesel_devtools/diesel_devtools.dart';
import 'package:diesel_sqlite/diesel_sqlite.dart';

Future<void> main() async {
  final conn = SqliteConnection.memory();
  await conn.executeSql(
    'CREATE TABLE users ('
    'id INTEGER PRIMARY KEY, name TEXT NOT NULL, email TEXT, created_at INTEGER)',
  );
  await conn.executeSql(
    'CREATE TABLE posts ('
    'id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id), '
    'title TEXT NOT NULL)',
  );
  await conn.executeSql(
    "INSERT INTO users (name, email, created_at) VALUES "
    "('Alice', 'alice@example.com', 1719800000000), "
    "('Bob', NULL, 1719900000000)",
  );
  await conn.executeSql(
    "INSERT INTO posts (user_id, title) VALUES (1, 'Hello'), (1, 'World')",
  );

  final id = DieselDevTools.register(conn, name: 'demo');

  const service = InspectorService();
  final pretty = const JsonEncoder.withIndent('  ');
  stdout.writeln('instances: ${pretty.convert([
        for (final i in await service.listInstances()) i.toJson()
      ])}');
  stdout.writeln('schema: ${pretty.convert((await service.getSchema(id)).toJson())}');
  stdout.writeln('users page: ${pretty.convert((await service.getTableData(id, table: 'users')).toJson())}');
  stdout.writeln('sql: ${pretty.convert((await service.runSql(id, 'SELECT count(*) AS n FROM posts')).toJson())}');

  stdout.writeln('\nRegistered instance "$id". '
      'Open DevTools on this VM service and use the diesel tab. '
      'Press Enter to exit.');
  await stdin.first;
  await conn.close();
}
