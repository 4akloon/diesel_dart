/// Annotations consumed by `diesel_codegen` to derive row mappers for data
/// classes. They carry no runtime behaviour — only metadata for the generator.
library;

export 'annotations/ignore.dart';
export 'annotations/map_column.dart';
export 'annotations/queryable.dart';
export 'annotations/relation.dart';
