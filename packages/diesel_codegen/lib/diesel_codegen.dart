/// build_runner code generator for the Diesel Dart ORM. Wire it via build.yaml;
/// it derives a `RowMapper<T>` for every `@Queryable`-annotated class.
library;

export 'builder.dart';
export 'src/queryable_generator.dart';
