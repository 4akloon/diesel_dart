import 'enum_schema.dart';
import 'extension_schema.dart';
import 'sequence_schema.dart';
import 'table_schema.dart';
import 'view_schema.dart';

export 'column_schema.dart';
export 'constraints.dart';
export 'enum_schema.dart';
export 'extension_schema.dart';
export 'index_schema.dart';
export 'sequence_schema.dart';
export 'table_schema.dart';
export 'trigger_schema.dart';
export 'view_schema.dart';

class DatabaseSchema {
  const DatabaseSchema({
    required this.provider,
    required this.databaseName,
    required this.tables,
    this.views = const [],
    this.enums = const [],
    this.sequences = const [],
    this.extensions = const [],
    this.version,
    this.comment,
  });

  final SqlProvider provider;
  final String databaseName;
  final List<TableSchema> tables;
  final List<ViewSchema> views;
  final List<EnumSchema> enums;
  final List<SequenceSchema> sequences;
  final List<ExtensionSchema> extensions;
  final int? version;
  final String? comment;
}

enum SqlProvider {
  sqlite,
  postgres,
  mysql,
  mariadb,
  sqlServer,
  oracle,
  unknown,
}
