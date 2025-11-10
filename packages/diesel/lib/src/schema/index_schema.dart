class IndexSchema {
  const IndexSchema({
    required this.name,
    required this.columns,
    this.isUnique = false,
    this.isPrimary = false,
    this.whereClause,
    this.method,
  });

  final String name;
  final List<IndexColumn> columns;
  final bool isUnique;
  final bool isPrimary;
  final String? whereClause;
  final String? method;
}

class IndexColumn {
  const IndexColumn({
    required this.name,
    this.sortOrder = SortOrder.ascending,
    this.nullsOrder,
    this.expression,
  });

  final String name;
  final SortOrder sortOrder;
  final NullsOrder? nullsOrder;
  final String? expression;
}

enum SortOrder {
  ascending,
  descending,
}

enum NullsOrder {
  first,
  last,
}

