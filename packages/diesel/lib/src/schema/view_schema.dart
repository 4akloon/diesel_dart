import 'column_schema.dart';

class ViewSchema {
  const ViewSchema({
    required this.name,
    this.schema = 'main',
    this.definition,
    this.columns = const [],
    this.isMaterialized = false,
    this.comment,
  });

  final String schema;
  final String name;
  final String? definition;
  final List<ColumnSchema> columns;
  final bool isMaterialized;
  final String? comment;
}

