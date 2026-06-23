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
    if (!targetHasRelations) {
      return 'budget <= 0 ? null : $reader(r, $alias)';
    }
    final childPrefix = "'\${prefix}${edge.fieldName}_'";
    return 'budget <= 0 ? null : $reader(r, $alias, $childPrefix, budget - 1)';
  }
}
