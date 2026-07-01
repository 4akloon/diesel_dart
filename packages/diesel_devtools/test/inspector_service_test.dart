import 'package:diesel_devtools/diesel_devtools.dart';
import 'package:diesel_sqlite/diesel_sqlite.dart';
import 'package:test/test.dart';

void main() {
  late SqliteConnection conn;
  late String id;
  const service = InspectorService();

  setUp(() async {
    DieselDevTools.clear();
    conn = SqliteConnection.memory();
    await conn.executeSql(
      'CREATE TABLE users ('
      'id INTEGER PRIMARY KEY, '
      'name TEXT NOT NULL, '
      'email TEXT, '
      'created_at INTEGER)',
    );
    await conn.executeSql(
      'CREATE TABLE posts ('
      'id INTEGER PRIMARY KEY, '
      'user_id INTEGER NOT NULL REFERENCES users(id), '
      'title TEXT NOT NULL)',
    );
    await conn.executeSql(
      "INSERT INTO users (name, email, created_at) VALUES "
      "('Alice', 'alice@example.com', 100), "
      "('Bob', NULL, 200), "
      "('Cara', 'cara@example.com', 300)",
    );
    id = DieselDevTools.register(conn, name: 'main');
  });

  tearDown(() async {
    DieselDevTools.clear();
    await conn.close();
  });

  test('listInstances reflects the registry', () async {
    final instances = await service.listInstances();
    expect(instances, hasLength(1));
    expect(instances.single.id, id);
    expect(instances.single.name, 'main');
    expect(instances.single.backend, 'sqlite');
  });

  test('getSchema exposes tables, columns, PK and FK', () async {
    final schema = await service.getSchema(id);
    final names = [for (final t in schema.tables) t.name];
    expect(names, containsAll(<String>['users', 'posts']));

    final users = schema.tables.firstWhere((t) => t.name == 'users');
    final idCol = users.columns.firstWhere((c) => c.name == 'id');
    expect(idCol.isPrimaryKey, isTrue);
    expect(idCol.type, 'integer');
    final email = users.columns.firstWhere((c) => c.name == 'email');
    expect(email.isNullable, isTrue);

    final posts = schema.tables.firstWhere((t) => t.name == 'posts');
    final fkCol = posts.columns.firstWhere((c) => c.name == 'user_id');
    expect(fkCol.foreignKey?.table, 'users');
  });

  test('getTableData pages with total, order and column projection', () async {
    final page = await service.getTableData(
      id,
      table: 'users',
      limit: 2,
      offset: 1,
      orderBy: 'id',
    );
    expect(page.total, 3);
    expect(page.limit, 2);
    expect(page.offset, 1);
    expect(page.columns, ['id', 'name', 'email', 'created_at']);
    expect(page.rows, hasLength(2));
    // ordered by id, offset 1 => Bob, Cara
    expect(page.rows[0][1], 'Bob');
    expect(page.rows[0][2], isNull); // Bob's email
    expect(page.rows[1][1], 'Cara');
  });

  test('getTableData descending order', () async {
    final page = await service.getTableData(
      id,
      table: 'users',
      orderBy: 'id',
      desc: true,
    );
    expect(page.rows.first[1], 'Cara');
  });

  test('getTableData rejects unknown table and column', () async {
    expect(
      () => service.getTableData(id, table: 'ghosts'),
      throwsA(isA<InspectorException>()),
    );
    expect(
      () => service.getTableData(id, table: 'users', orderBy: 'nope'),
      throwsA(isA<InspectorException>()),
    );
  });

  test('unknown instance id throws', () async {
    expect(
      () => service.getSchema('inst-999'),
      throwsA(isA<InspectorException>()),
    );
  });

  test('runSql read returns columns and rows', () async {
    final result = await service.runSql(
      id,
      "SELECT name, email FROM users WHERE name = 'Alice'",
    );
    expect(result.isRead, isTrue);
    expect(result.isError, isFalse);
    expect(result.columns, ['name', 'email']);
    expect(result.rows, [
      ['Alice', 'alice@example.com'],
    ]);
  });

  test('runSql with bound params', () async {
    final result =
        await service.runSql(id, 'SELECT id FROM users WHERE name = ?', ['Bob']);
    expect(result.rows, hasLength(1));
  });

  test('runSql write executes and reports write kind', () async {
    final result = await service.runSql(
      id,
      "UPDATE users SET email = 'x@y.z' WHERE name = 'Bob'",
    );
    expect(result.kind, 'write');
    expect(result.isError, isFalse);

    final check = await service.runSql(
      id,
      "SELECT email FROM users WHERE name = 'Bob'",
    );
    expect(check.rows, [
      ['x@y.z'],
    ]);
  });

  test('runSql surfaces errors instead of throwing', () async {
    final result = await service.runSql(id, 'SELECT * FROM nonexistent');
    expect(result.isError, isTrue);
    expect(result.error, isNotNull);
  });

  test('toJson shapes match the wire protocol', () async {
    final page = await service.getTableData(id, table: 'users', limit: 1);
    final json = page.toJson();
    expect(json['columns'], isA<List<String>>());
    expect(json['total'], 3);

    final err = await service.runSql(id, 'SELECT * FROM nope');
    expect(err.toJson()['kind'], 'error');
  });
}
