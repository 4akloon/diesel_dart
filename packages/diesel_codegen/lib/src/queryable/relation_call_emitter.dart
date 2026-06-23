import 'relation_arg.dart';
import 'relation_edge.dart';

/// Builds the inline relation expressions placed inside a unified reader.
///
/// Each relation reads from a path-based alias (`${prefix}field`) and recurses
/// into the target's own public reader with `budget - 1`, so the whole join
/// tree is unrolled at runtime by one function per class.
final class RelationCallEmitter {
  const RelationCallEmitter();

  List<RelationArg> forReader(
    List<RelationEdge> edges,
    bool Function(String targetClass) targetHasRelations,
  ) {
    return [
      for (final edge in edges)
        RelationArg(
          fieldName: edge.fieldName,
          childCall: _call(edge, targetHasRelations(edge.targetClass)),
        ),
    ];
  }

  String _call(RelationEdge edge, bool targetHasRelations) {
    final reader = '\$${edge.targetClass}FromRow';
    final alias = "${edge.targetMarker}.table.aliased('\${prefix}${edge.fieldName}')";
    // Cap budget per root relation: join trees are per-edge but the query
    // seeds one global budget (max root depth). Nested calls keep `budget`.
    final budget =
        "prefix.isEmpty ? (budget > ${edge.depth} ? ${edge.depth} : budget) : budget";
    final String read;
    if (!targetHasRelations) {
      read = '$reader(r, $alias)';
    } else {
      final childPrefix = "'\${prefix}${edge.fieldName}_'";
      read = '$reader(r, $alias, $childPrefix, ($budget) - 1)';
    }
    final fk =
        'r.get(src.col(${edge.parentMarker}.${edge.fkAccessor})) == null';
    final whenFkNull = edge.fkNullable ? '$fk ? null : ' : '';
    return '($budget) <= 0 ? null : $whenFkNull$read';
  }
}
