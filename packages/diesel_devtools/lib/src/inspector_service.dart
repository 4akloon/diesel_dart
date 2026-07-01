import 'package:diesel/diesel.dart';

import 'json_codec.dart';
import 'registry.dart';

/// Raised when the inspector is asked about an unknown instance/table/column.
final class InspectorException implements Exception {
  final String message;
  const InspectorException(this.message);
  @override
  String toString() => 'InspectorException: $message';
}

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
  /// [table] and [orderBy] are validated against the introspected schema before
  /// being interpolated (identifiers can't be parameterized), which also
  /// rejects unknown names. [limit] is clamped to `1..1000`.
  Future<TablePageDto> getTableData(
    String id, {
    required String table,
    int limit = 50,
    int offset = 0,
    String? orderBy,
    bool desc = false,
  }) async {
    final conn = _connection(id);
    final target = await _requireTable(conn, table);

    if (orderBy != null && !target.columns.any((c) => c.name == orderBy)) {
      throw InspectorException('Unknown column: $orderBy');
    }

    final safeLimit = limit.clamp(1, 1000);
    final safeOffset = offset < 0 ? 0 : offset;

    final sql = StringBuffer('SELECT * FROM ${_quote(table)}');
    if (orderBy != null) {
      sql.write(' ORDER BY ${_quote(orderBy)}${desc ? ' DESC' : ' ASC'}');
    }
    // limit/offset are validated ints, so inlining them is injection-safe and
    // sidesteps per-backend placeholder syntax (`?` vs `$1`).
    sql.write(' LIMIT $safeLimit OFFSET $safeOffset');

    final rawRows = await conn.queryRaw(sql.toString());
    final countRows =
        await conn.queryRaw('SELECT count(*) AS c FROM ${_quote(table)}');
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

  bool _returnsRows(String sql) =>
      _readLead.hasMatch(sql) || _returning.hasMatch(sql);

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

  Future<IntrospectedTable> _requireTable(Connection conn, String table) async {
    for (final t in await conn.introspect()) {
      if (t.name == table) return t;
    }
    throw InspectorException('Unknown table: $table');
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

/// Schema of one instance.
final class SchemaDto {
  final List<TableDto> tables;
  const SchemaDto(this.tables);
  Map<String, Object?> toJson() =>
      {'tables': [for (final t in tables) t.toJson()]};
}

final class TableDto {
  final String name;
  final List<ColumnDto> columns;
  const TableDto(this.name, this.columns);
  Map<String, Object?> toJson() =>
      {'name': name, 'columns': [for (final c in columns) c.toJson()]};
}

final class ColumnDto {
  final String name;

  /// Canonical [ColumnType] name (e.g. `integer`, `text`, `dateTime`).
  final String type;
  final String rawType;
  final bool isNullable;
  final bool isPrimaryKey;
  final ForeignKeyDto? foreignKey;

  const ColumnDto({
    required this.name,
    required this.type,
    required this.rawType,
    required this.isNullable,
    required this.isPrimaryKey,
    this.foreignKey,
  });

  Map<String, Object?> toJson() => {
        'name': name,
        'type': type,
        'rawType': rawType,
        'isNullable': isNullable,
        'isPrimaryKey': isPrimaryKey,
        if (foreignKey case final fk?) 'foreignKey': fk.toJson(),
      };
}

final class ForeignKeyDto {
  final String table;
  final String column;
  const ForeignKeyDto(this.table, this.column);
  Map<String, Object?> toJson() => {'table': table, 'column': column};
}

/// One page of table rows.
final class TablePageDto {
  final List<String> columns;
  final List<List<Object?>> rows;
  final int total;
  final int limit;
  final int offset;

  const TablePageDto({
    required this.columns,
    required this.rows,
    required this.total,
    required this.limit,
    required this.offset,
  });

  Map<String, Object?> toJson() => {
        'columns': columns,
        'rows': rows,
        'total': total,
        'limit': limit,
        'offset': offset,
      };
}

/// Result of [InspectorService.runSql]: a `read` (columns+rows), a `write`
/// (executed, optional affected count), or an `error`.
final class SqlResultDto {
  final List<String>? columns;
  final List<List<Object?>>? rows;
  final int? affected;
  final bool truncated;
  final String? error;

  const SqlResultDto.read({
    required this.columns,
    required this.rows,
    this.truncated = false,
  })  : affected = null,
        error = null;

  const SqlResultDto.write({this.affected})
      : columns = null,
        rows = null,
        truncated = false,
        error = null;

  const SqlResultDto.error(this.error)
      : columns = null,
        rows = null,
        affected = null,
        truncated = false;

  bool get isError => error != null;
  bool get isRead => columns != null;

  String get kind => error != null
      ? 'error'
      : columns != null
          ? 'read'
          : 'write';

  Map<String, Object?> toJson() => {
        'kind': kind,
        if (columns case final c?) 'columns': c,
        if (rows case final r?) 'rows': r,
        if (affected case final a?) 'affected': a,
        if (truncated) 'truncated': true,
        if (error case final e?) 'error': e,
      };
}
