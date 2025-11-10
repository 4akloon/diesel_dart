import 'column_schema.dart';
import 'constraints.dart';
import 'index_schema.dart';
import 'trigger_schema.dart';

class TableSchema {
  const TableSchema({
    required this.name,
    this.schema = 'main',
    this.kind = TableKind.table,
    this.comment,
    this.columns = const [],
    this.primaryKey,
    this.foreignKeys = const [],
    this.uniqueConstraints = const [],
    this.checkConstraints = const [],
    this.indexes = const [],
    this.triggers = const [],
  });

  final String schema;
  final String name;
  final TableKind kind;
  final String? comment;
  final List<ColumnSchema> columns;
  final PrimaryKeyConstraint? primaryKey;
  final List<ForeignKeyConstraint> foreignKeys;
  final List<UniqueConstraint> uniqueConstraints;
  final List<CheckConstraint> checkConstraints;
  final List<IndexSchema> indexes;
  final List<TriggerSchema> triggers;
}

enum TableKind {
  table,
  view,
  materializedView,
}

