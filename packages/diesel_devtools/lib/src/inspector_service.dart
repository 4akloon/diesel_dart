import 'package:diesel/diesel.dart';

import 'column_filter.dart';
import 'diesel_dev_tools.dart';
import 'dto/column_dto.dart';
import 'dto/foreign_key_dto.dart';
import 'dto/schema_dto.dart';
import 'dto/sql_result_dto.dart';
import 'dto/table_dto.dart';
import 'dto/table_page_dto.dart';
import 'inspector_exception.dart';
import 'json_codec.dart';
import 'registered_instance.dart';

/// Backend-agnostic core behind the `ext.diesel.*` service extensions.
///
/// Every method operates purely through the [Connection] interface and the
/// [DieselDevTools] registry, so it is directly unit-testable without a VM
/// service round-trip. The service-extension handlers are thin adapters that
/// parse string params and JSON-encode these results.
final class InspectorService {
  const InspectorService();

  /// The instances currently registered for inspection.
  Future<List<RegisteredInstance>> listInstances() async =>
      DieselDevTools.instances;

  /// Introspects [id]'s schema into a transport-friendly model.
  Future<SchemaDto> getSchema(String id) async {
    final tables = await _connection(id).introspect();
    return SchemaDto([for (final t in tables) _table(t)]);
  }

  /// Reads one page of rows from [table] on instance [id].
  ///
  /// [table]/[orderBy]/[filters] columns are validated against the introspected
  /// schema before being interpolated (identifiers can't be parameterized),
  /// which also rejects unknown names; filter *values* are bound as parameters.
  /// [limit] is clamped to `1..1000`.
  Future<TablePageDto> getTableData(
    String id, {
    required String table,
    int limit = 50,
    int offset = 0,
    String? orderBy,
    bool desc = false,
    List<ColumnFilter> filters = const [],
  }) async {
    final conn = _connection(id);
    final target = await _requireTable(conn, table);

    if (orderBy != null && !target.columns.any((c) => c.name == orderBy)) {
      throw InspectorException('Unknown column: $orderBy');
    }

    final safeLimit = limit.clamp(1, 1000);
    final safeOffset = offset < 0 ? 0 : offset;

    // WHERE is shared by the data + count queries (same params, same order), so
    // build it once. LIMIT/OFFSET/ORDER BY carry no params.
    final binds = _Binds(_backend(id));
    final where = _buildWhere(target, filters, binds);

    final data = StringBuffer('SELECT * FROM ${_quote(table)}$where');
    if (orderBy != null) {
      data.write(' ORDER BY ${_quote(orderBy)}${desc ? ' DESC' : ' ASC'}');
    }
    data.write(' LIMIT $safeLimit OFFSET $safeOffset');

    final rawRows = await conn.queryRaw(data.toString(), binds.params);
    final countRows = await conn.queryRaw(
        'SELECT count(*) AS c FROM ${_quote(table)}$where', binds.params);
    final total = (countRows.first['c'] as num?)?.toInt() ?? 0;

    // Project in schema-column order so the grid is deterministic regardless of
    // driver map ordering.
    final columns = [for (final c in target.columns) c.name];
    return TablePageDto(
      columns: columns,
      rows: [
        for (final row in rawRows)
          [for (final name in columns) toJsonValue(row[name])],
      ],
      total: total,
      limit: safeLimit,
      offset: safeOffset,
    );
  }

  /// Updates a single row of [table] on instance [id]: `SET changes WHERE key`.
  ///
  /// [key] must identify the row (typically its primary key); an empty [key] is
  /// rejected so a stray edit can't rewrite the whole table. Column names are
  /// validated against the schema; values are bound as parameters.
  Future<void> updateRow(
    String id, {
    required String table,
    required Map<String, Object?> key,
    required Map<String, Object?> changes,
  }) async {
    if (changes.isEmpty) return;
    if (key.isEmpty) {
      throw const InspectorException('No key columns to identify the row');
    }
    final conn = _connection(id);
    final target = await _requireTable(conn, table);
    final binds = _Binds(_backend(id));

    final sets = [
      for (final e in changes.entries)
        '${_quote(_requireColumn(target, e.key).name)} = ${binds.bind(e.value)}',
    ];
    final conds = [
      for (final e in key.entries)
        '${_quote(_requireColumn(target, e.key).name)} = ${binds.bind(e.value)}',
    ];

    final sql = 'UPDATE ${_quote(table)} SET ${sets.join(', ')} '
        'WHERE ${conds.join(' AND ')}';
    await conn.executeSql(sql, binds.params);
  }

  /// Runs an arbitrary SQL statement (dev-only; reads *and* writes).
  ///
  /// Statements that yield rows (`SELECT`/`WITH`/`PRAGMA`/`EXPLAIN`/`VALUES`, or
  /// anything with a `RETURNING` clause) go through [Connection.queryRaw];
  /// everything else through [Connection.executeSql]. Result rows are capped at
  /// [_maxRows].
  Future<SqlResultDto> runSql(
    String id,
    String sql, [
    List<Object?> params = const [],
  ]) async {
    final conn = _connection(id);
    try {
      if (_returnsRows(sql)) {
        return _rowsToResult(await conn.queryRaw(sql, params));
      }
      await conn.executeSql(sql, params);
      return const SqlResultDto.write();
    } catch (e) {
      return SqlResultDto.error(e.toString());
    }
  }

  static const _maxRows = 1000;

  static final _readLead = RegExp(
    r'^\s*(select|with|pragma|explain|show|values|table)\b',
    caseSensitive: false,
  );
  static final _returning = RegExp(r'\breturning\b', caseSensitive: false);

  static const _comparisons = {
    'eq': '=',
    'ne': '<>',
    'lt': '<',
    'le': '<=',
    'gt': '>',
    'ge': '>=',
  };

  bool _returnsRows(String sql) =>
      _readLead.hasMatch(sql) || _returning.hasMatch(sql);

  String _buildWhere(
      IntrospectedTable table, List<ColumnFilter> filters, _Binds binds) {
    if (filters.isEmpty) return '';
    final terms = <String>[];
    for (final f in filters) {
      final col = _quote(_requireColumn(table, f.column).name);
      switch (f.op) {
        case 'isNull':
          terms.add('$col IS NULL');
        case 'isNotNull':
          terms.add('$col IS NOT NULL');
        case 'like':
          terms.add('$col LIKE ${binds.bind('${f.value ?? ''}')}');
        default:
          final op = _comparisons[f.op];
          if (op == null) throw InspectorException('Unknown operator: ${f.op}');
          terms.add('$col $op ${binds.bind(f.value)}');
      }
    }
    return ' WHERE ${terms.join(' AND ')}';
  }

  SqlResultDto _rowsToResult(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) {
      return const SqlResultDto.read(columns: [], rows: []);
    }
    final columns = rows.first.keys.toList();
    final truncated = rows.length > _maxRows;
    final limited = truncated ? rows.sublist(0, _maxRows) : rows;
    return SqlResultDto.read(
      columns: columns,
      rows: [
        for (final row in limited)
          [for (final c in columns) toJsonValue(row[c])],
      ],
      truncated: truncated,
    );
  }

  Connection _connection(String id) {
    final conn = DieselDevTools.connection(id);
    if (conn == null) throw InspectorException('Unknown instance: $id');
    return conn;
  }

  String _backend(String id) {
    for (final i in DieselDevTools.instances) {
      if (i.id == id) return i.backend;
    }
    return 'sqlite';
  }

  Future<IntrospectedTable> _requireTable(Connection conn, String table) async {
    for (final t in await conn.introspect()) {
      if (t.name == table) return t;
    }
    throw InspectorException('Unknown table: $table');
  }

  IntrospectedColumn _requireColumn(IntrospectedTable table, String column) {
    for (final c in table.columns) {
      if (c.name == column) return c;
    }
    throw InspectorException('Unknown column: $column');
  }

  static TableDto _table(IntrospectedTable t) =>
      TableDto(t.name, [for (final c in t.columns) _column(c)]);

  static ColumnDto _column(IntrospectedColumn c) {
    final fk = c.foreignKey;
    return ColumnDto(
      name: c.name,
      type: c.type.name,
      rawType: c.rawType,
      isNullable: c.isNullable,
      isPrimaryKey: c.isPrimaryKey,
      foreignKey: fk == null ? null : ForeignKeyDto(fk.table, fk.column),
    );
  }

  static String _quote(String identifier) =>
      '"${identifier.replaceAll('"', '""')}"';
}

/// Accumulates bound parameters and emits backend-appropriate placeholders
/// (`?` for SQLite, `$N` for Postgres). A Dart `bool` is adapted to `0/1` for
/// SQLite, whose driver (via the raw query path) takes integers, not booleans.
final class _Binds {
  final String backend;
  final List<Object?> params = [];
  int _n = 0;

  _Binds(this.backend);

  String bind(Object? value) {
    params.add(backend == 'postgres' ? value : _forSqlite(value));
    _n++;
    return backend == 'postgres' ? '\$$_n' : '?';
  }

  static Object? _forSqlite(Object? value) =>
      value is bool ? (value ? 1 : 0) : value;
}
