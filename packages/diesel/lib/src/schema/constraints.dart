class PrimaryKeyConstraint {
  const PrimaryKeyConstraint({
    required this.columns,
    this.name,
    this.isAutoIncrementing = false,
  });

  final String? name;
  final List<String> columns;
  final bool isAutoIncrementing;
}

class ForeignKeyConstraint {
  const ForeignKeyConstraint({
    required this.columns,
    required this.reference,
    this.name,
    this.onUpdate = ForeignKeyAction.noAction,
    this.onDelete = ForeignKeyAction.noAction,
    this.isDeferrable = false,
    this.initiallyDeferred = false,
  });

  final String? name;
  final List<String> columns;
  final ForeignKeyReference reference;
  final ForeignKeyAction onUpdate;
  final ForeignKeyAction onDelete;
  final bool isDeferrable;
  final bool initiallyDeferred;
}

class ForeignKeyReference {
  const ForeignKeyReference({
    required this.table,
    required this.columns,
    this.schema = 'main',
  });

  final String schema;
  final String table;
  final List<String> columns;
}

enum ForeignKeyAction {
  cascade,
  restrict,
  setNull,
  setDefault,
  noAction,
}

class UniqueConstraint {
  const UniqueConstraint({
    required this.columns,
    this.name,
    this.whereClause,
  });

  final String? name;
  final List<String> columns;
  final String? whereClause;
}

class CheckConstraint {
  const CheckConstraint({
    required this.expression,
    this.name,
  });

  final String? name;
  final String expression;
}

