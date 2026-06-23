/// Diesel — a type-safe query builder and ORM for Dart, inspired by diesel-rs.
///
/// Stage 1 surface: typed schema (`Column`/`TableRef`), expressions, the
/// `select*`/`insertInto`/`update`/`deleteFrom` builders, SQL serialization, and
/// the dialect-agnostic `Connection` interface. Concrete backends live in
/// separate packages (e.g. `diesel_sqlite`).
library;

export 'src/annotations.dart';
export 'src/ast/sql_node.dart' show Ordering;
export 'src/connection.dart';
export 'src/expression/expression.dart';
export 'src/query/query.dart';
export 'src/query/row_reader.dart';
export 'src/query/write.dart';
export 'src/schema/introspection.dart';
export 'src/schema/table.dart';
export 'src/serialize/query_builder.dart' show CompiledQuery, QueryBuilder;
export 'src/serialize/sql_dialect.dart';
export 'src/types/sql_type.dart';
