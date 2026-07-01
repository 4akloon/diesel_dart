import '../ast/sql_node.dart';
import '../query/query.dart';
import '../query/write.dart';
import 'sql_dialect.dart';

/// A serialized statement: the SQL text and its ordered bound parameters.
typedef CompiledQuery = (String sql, List<Object?> params);

/// Walks an untyped AST and emits `(sql, params)` for a given [SqlDialect].
///
/// Pure string/value transformation — it never touches a database driver,
/// which keeps serialization trivially unit-testable.
final class QueryBuilder {
  final SqlDialect dialect;
  final StringBuffer _sql = StringBuffer();
  final List<Object?> _params = [];

  QueryBuilder(this.dialect);

  CompiledQuery buildSelect(SelectQuery<dynamic> stmt) {
    _validateScope(stmt);
    _sql.write('SELECT ');
    if (stmt.isDistinct) _sql.write('DISTINCT ');
    var firstProjection = true;
    for (final p in stmt.projection) {
      if (!firstProjection) _sql.write(', ');
      firstProjection = false;
      _writeNode(p.expression);
      if (p.alias case final alias?) {
        _sql
          ..write(' AS ')
          ..write(dialect.quoteIdentifier(alias));
      }
    }
    _sql
      ..write(' FROM ')
      ..write(dialect.quoteIdentifier(stmt.fromTable));
    if (stmt.fromAlias case final alias?) {
      _sql
        ..write(' AS ')
        ..write(dialect.quoteIdentifier(alias));
    }
    for (final join in stmt.joins) {
      _sql
        ..write(switch (join.kind) {
          JoinKind.inner => ' INNER JOIN ',
          JoinKind.left => ' LEFT JOIN ',
        })
        ..write(dialect.quoteIdentifier(join.table));
      if (join.alias case final alias?) {
        _sql
          ..write(' AS ')
          ..write(dialect.quoteIdentifier(alias));
      }
      _sql.write(' ON ');
      _writeNode(join.on);
    }
    if (stmt.whereNode case final where?) {
      _sql.write(' WHERE ');
      _writeNode(where);
    }
    if (stmt.groupByColumns.isNotEmpty) {
      _sql.write(' GROUP BY ');
      _sql.write(stmt.groupByColumns.map(_column).join(', '));
    }
    if (stmt.havingNode case final having?) {
      _sql.write(' HAVING ');
      _writeNode(having);
    }
    if (stmt.orderings.isNotEmpty) {
      _sql.write(' ORDER BY ');
      _sql.write(stmt.orderings
          .map((o) => '${_column(o.column)} ${o.ascending ? 'ASC' : 'DESC'}')
          .join(', '));
    }
    if (stmt.limitCount case final limit?) {
      _sql
        ..write(' LIMIT ')
        ..write(_bind(limit));
    }
    if (stmt.offsetCount case final offset?) {
      _sql
        ..write(' OFFSET ')
        ..write(_bind(offset));
    }
    return _result();
  }

  /// Verifies every referenced column belongs to a table in the FROM/JOIN
  /// clause — the runtime safety net for joined queries (single-table queries
  /// are already guaranteed by the type system).
  void _validateScope(SelectQuery<dynamic> stmt) {
    // Columns address a source by its effective name (alias when aliased).
    final allowed = {
      stmt.fromAlias ?? stmt.fromTable,
      for (final j in stmt.joins) j.alias ?? j.table,
    };
    for (final p in stmt.projection) {
      _checkNode(p.expression, allowed);
    }
    for (final ordering in stmt.orderings) {
      _checkColumn(ordering.column, allowed);
    }
    for (final column in stmt.groupByColumns) {
      _checkColumn(column, allowed);
    }
    if (stmt.havingNode case final having?) {
      _checkNode(having, allowed);
    }
    for (final join in stmt.joins) {
      _checkNode(join.on, allowed);
    }
    if (stmt.whereNode case final where?) {
      _checkNode(where, allowed);
    }
  }

  void _checkColumn(ColumnNode column, Set<String> allowed) {
    if (!allowed.contains(column.table)) {
      throw StateError(
          'Column "${column.table}"."${column.name}" is not in the query\'s '
          'FROM/JOIN clause (tables in scope: ${allowed.join(', ')})');
    }
  }

  void _checkNode(SqlNode node, Set<String> allowed) {
    switch (node) {
      case ColumnNode():
        _checkColumn(node, allowed);
      case ParamNode():
        break;
      case BinaryNode(:final left, :final right):
        _checkNode(left, allowed);
        _checkNode(right, allowed);
      case InNode(:final target):
        _checkNode(target, allowed);
      case NullCheckNode(:final target):
        _checkNode(target, allowed);
      case BetweenNode(:final target):
        _checkNode(target, allowed);
      case FunctionNode(:final argument):
        if (argument != null) _checkNode(argument, allowed);
      case RawNode():
        break;
    }
  }

  /// Serializes a write, optionally appending a `RETURNING` clause (its columns
  /// are referenced unqualified, as SQLite requires).
  CompiledQuery buildWrite(WriteStatement stmt,
      {List<Projection> returning = const []}) {
    switch (stmt) {
      case InsertStatement():
        _writeInsert(stmt);
      case UpdateStatement():
        _writeUpdate(stmt);
      case DeleteStatement():
        _writeDelete(stmt);
    }
    if (returning.isNotEmpty) {
      _sql.write(' RETURNING ');
      var first = true;
      for (final p in returning) {
        if (!first) _sql.write(', ');
        first = false;
        final expr = p.expression;
        if (expr is ColumnNode) {
          _sql.write(dialect.quoteIdentifier(expr.name));
        } else {
          _writeNode(expr);
        }
        if (p.alias case final alias?) {
          _sql
            ..write(' AS ')
            ..write(dialect.quoteIdentifier(alias));
        }
      }
    }
    return _result();
  }

  void _writeInsert(InsertStatement stmt) {
    final cols = stmt.columns.map(dialect.quoteIdentifier).join(', ');
    final tuples = [
      for (final row in stmt.rows) '(${row.map(_bind).join(', ')})',
    ].join(', ');
    _sql.write(
        'INSERT INTO ${dialect.quoteIdentifier(stmt.table)} ($cols) VALUES $tuples');
    if (stmt.conflictTarget case final target?) {
      _sql.write(' ON CONFLICT');
      if (target.isNotEmpty) {
        _sql.write(' (${target.map(dialect.quoteIdentifier).join(', ')})');
      }
      if (stmt.conflictDoNothing) {
        _sql.write(' DO NOTHING');
      } else {
        _sql.write(' DO UPDATE SET ');
        var first = true;
        for (final a in stmt.conflictSet) {
          if (!first) _sql.write(', ');
          first = false;
          _sql
            ..write(dialect.quoteIdentifier(a.column))
            ..write(' = ');
          if (a.isExcluded) {
            _sql.write('excluded.${dialect.quoteIdentifier(a.column)}');
          } else {
            _sql.write(_bind(a.encoded));
          }
        }
      }
    }
  }

  void _writeUpdate(UpdateStatement stmt) {
    final assignments = [
      for (var i = 0; i < stmt.assignColumns.length; i++)
        '${dialect.quoteIdentifier(stmt.assignColumns[i])} = ${_bind(stmt.assignValues[i])}',
    ].join(', ');
    _sql.write('UPDATE ${dialect.quoteIdentifier(stmt.table)} SET $assignments');
    if (stmt.whereNode case final where?) {
      _sql.write(' WHERE ');
      _writeNode(where);
    }
  }

  void _writeDelete(DeleteStatement stmt) {
    _sql.write('DELETE FROM ${dialect.quoteIdentifier(stmt.table)}');
    if (stmt.whereNode case final where?) {
      _sql.write(' WHERE ');
      _writeNode(where);
    }
  }

  void _writeNode(SqlNode node) {
    switch (node) {
      case ColumnNode():
        _sql.write(_column(node));
      case ParamNode(:final value):
        _sql.write(_bind(value));
      case BinaryNode(:final left, :final op, :final right):
        _sql.write('(');
        _writeNode(left);
        _sql.write(' $op ');
        _writeNode(right);
        _sql.write(')');
      case InNode(:final target, :final values):
        _writeNode(target);
        _sql
          ..write(' IN (')
          ..write(values.map(_bind).join(', '))
          ..write(')');
      case NullCheckNode(:final target, :final negated):
        _writeNode(target);
        _sql.write(negated ? ' IS NOT NULL' : ' IS NULL');
      case BetweenNode(:final target, :final low, :final high):
        _writeNode(target);
        _sql
          ..write(' BETWEEN ')
          ..write(_bind(low))
          ..write(' AND ')
          ..write(_bind(high));
      case FunctionNode(:final name, :final argument):
        _sql
          ..write(name)
          ..write('(');
        if (argument == null) {
          _sql.write('*');
        } else {
          _writeNode(argument);
        }
        _sql.write(')');
      case RawNode(:final sql, :final params):
        _sql.write(sql);
        _params.addAll(params);
    }
  }

  String _column(ColumnNode c) =>
      '${dialect.quoteIdentifier(c.table)}.${dialect.quoteIdentifier(c.name)}';

  /// Registers a bound parameter and returns its placeholder.
  String _bind(Object? value) {
    final placeholder = dialect.placeholder(_params.length);
    _params.add(dialect.encodeParam(value));
    return placeholder;
  }

  CompiledQuery _result() => (_sql.toString(), _params);
}
