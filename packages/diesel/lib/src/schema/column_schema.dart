import 'constraints.dart';

class ColumnSchema {
  const ColumnSchema({
    required this.name,
    required this.type,
    this.isNullable = false,
    this.isPrimaryKeyMember = false,
    this.isUnique = false,
    this.isAutoIncrement = false,
    this.defaultValueSql,
    this.generatedAs,
    this.comment,
    this.checkConstraints = const [],
    this.references,
    this.collation,
  });

  final String name;
  final ColumnType type;
  final bool isNullable;
  final bool isPrimaryKeyMember;
  final bool isUnique;
  final bool isAutoIncrement;
  final String? defaultValueSql;
  final GeneratedColumnSpecification? generatedAs;
  final String? comment;
  final List<CheckConstraint> checkConstraints;
  final ColumnReference? references;
  final String? collation;
}

class ColumnType {
  const ColumnType({
    required this.kind,
    this.nativeTypeName,
    this.length,
    this.precision,
    this.scale,
    this.isUnsigned = false,
    this.enumName,
  });

  final SqlTypeKind kind;
  final String? nativeTypeName;
  final int? length;
  final int? precision;
  final int? scale;
  final bool isUnsigned;
  final String? enumName;
}

enum SqlTypeKind {
  integer,
  smallInteger,
  bigInteger,
  numeric,
  decimal,
  real,
  doublePrecision,
  boolean,
  text,
  varchar,
  char,
  binary,
  blob,
  date,
  time,
  timestamp,
  json,
  uuid,
  enumType,
  custom,
}

class GeneratedColumnSpecification {
  const GeneratedColumnSpecification({
    required this.expression,
    this.storage = GeneratedColumnStorage.virtual,
  });

  final String expression;
  final GeneratedColumnStorage storage;
}

enum GeneratedColumnStorage {
  virtual,
  stored,
}

class ColumnReference {
  const ColumnReference({
    required this.targetTable,
    required this.targetColumn,
    this.schema = 'main',
  });

  final String schema;
  final String targetTable;
  final String targetColumn;
}

