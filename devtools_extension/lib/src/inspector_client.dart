import 'dart:convert';

import 'package:devtools_extensions/devtools_extensions.dart';

/// Thin client over the `ext.diesel.*` VM service extensions registered by the
/// `diesel_devtools` runtime in the connected app.
class InspectorClient {
  Future<Map<String, dynamic>> _call(
    String method, [
    Map<String, String>? args,
  ]) async {
    final response =
        await serviceManager.callServiceExtensionOnMainIsolate(method, args: args);
    return response.json ?? const {};
  }

  Future<List<InstanceInfo>> listInstances() async {
    final json = await _call('ext.diesel.listInstances');
    final list = (json['instances'] as List?) ?? const [];
    return [for (final i in list) InstanceInfo.fromJson(i as Map)];
  }

  Future<SchemaInfo> getSchema(String id) async =>
      SchemaInfo.fromJson(await _call('ext.diesel.getSchema', {'id': id}));

  Future<TablePage> getTableData(
    String id,
    String table, {
    int limit = 50,
    int offset = 0,
    String? orderBy,
    bool desc = false,
  }) async {
    final args = {
      'id': id,
      'table': table,
      'limit': '$limit',
      'offset': '$offset',
      'orderBy': ?orderBy,
      if (desc) 'desc': 'true',
    };
    return TablePage.fromJson(await _call('ext.diesel.getTableData', args));
  }

  Future<SqlResult> runSql(
    String id,
    String sql, [
    List<Object?> params = const [],
  ]) async {
    final args = {
      'id': id,
      'sql': sql,
      if (params.isNotEmpty) 'params': jsonEncode(params),
    };
    return SqlResult.fromJson(await _call('ext.diesel.runSql', args));
  }
}

class InstanceInfo {
  final String id;
  final String name;
  final String backend;
  InstanceInfo(this.id, this.name, this.backend);
  factory InstanceInfo.fromJson(Map json) => InstanceInfo(
        json['id'] as String,
        json['name'] as String,
        json['backend'] as String,
      );
}

class SchemaInfo {
  final List<TableInfo> tables;
  SchemaInfo(this.tables);
  factory SchemaInfo.fromJson(Map json) => SchemaInfo([
        for (final t in (json['tables'] as List? ?? const []))
          TableInfo.fromJson(t as Map),
      ]);
}

class TableInfo {
  final String name;
  final List<ColumnInfo> columns;
  TableInfo(this.name, this.columns);
  factory TableInfo.fromJson(Map json) => TableInfo(
        json['name'] as String,
        [
          for (final c in (json['columns'] as List? ?? const []))
            ColumnInfo.fromJson(c as Map),
        ],
      );

  Iterable<String> get columnNames => columns.map((c) => c.name);
  Set<String> get primaryKeys =>
      {for (final c in columns) if (c.isPrimaryKey) c.name};
}

class ColumnInfo {
  final String name;
  final String type;
  final bool isNullable;
  final bool isPrimaryKey;
  final String? fkTable;
  ColumnInfo(this.name, this.type, this.isNullable, this.isPrimaryKey, this.fkTable);
  factory ColumnInfo.fromJson(Map json) => ColumnInfo(
        json['name'] as String,
        json['type'] as String,
        json['isNullable'] as bool? ?? true,
        json['isPrimaryKey'] as bool? ?? false,
        (json['foreignKey'] as Map?)?['table'] as String?,
      );
}

class TablePage {
  final List<String> columns;
  final List<List<Object?>> rows;
  final int total;
  final int limit;
  final int offset;
  TablePage(this.columns, this.rows, this.total, this.limit, this.offset);
  factory TablePage.fromJson(Map json) => TablePage(
        [for (final c in (json['columns'] as List? ?? const [])) c as String],
        _rows(json['rows']),
        json['total'] as int? ?? 0,
        json['limit'] as int? ?? 0,
        json['offset'] as int? ?? 0,
      );
}

class SqlResult {
  final String kind; // read | write | error
  final List<String> columns;
  final List<List<Object?>> rows;
  final int? affected;
  final bool truncated;
  final String? error;
  SqlResult({
    required this.kind,
    this.columns = const [],
    this.rows = const [],
    this.affected,
    this.truncated = false,
    this.error,
  });
  factory SqlResult.fromJson(Map json) => SqlResult(
        kind: json['kind'] as String? ?? 'write',
        columns: [for (final c in (json['columns'] as List? ?? const [])) c as String],
        rows: _rows(json['rows']),
        affected: json['affected'] as int?,
        truncated: json['truncated'] as bool? ?? false,
        error: json['error'] as String?,
      );
}

List<List<Object?>> _rows(Object? raw) => [
      for (final row in (raw as List? ?? const []))
        [for (final cell in (row as List)) cell],
    ];
