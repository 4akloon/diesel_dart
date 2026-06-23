import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:diesel/diesel.dart';
import 'package:source_gen/source_gen.dart';

import 'queryable/queryable.dart';

export 'queryable/queryable.dart';

/// Generates alias-parameterized row readers, `RowMapper<T>` instances, and
/// self-mapping join queries for each `@Queryable` class. `@Relation` fields
/// drive nested joins with per-edge depth limits and path-based table aliases.
class QueryableGenerator extends GeneratorForAnnotation<Queryable> {
  const QueryableGenerator();

  @override
  Iterable<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
          '@Queryable can only be applied to classes.',
          element: element);
    }
    return generateQueryableClass(element);
  }
}
