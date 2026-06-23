import 'relation_edge.dart';

/// One node in the unrolled join tree for a relation query.
final class TreeNode {
  final RelationEdge edge;
  final String aliasPath;
  final String? parentAliasPath;
  final int budget;

  const TreeNode({
    required this.edge,
    required this.aliasPath,
    required this.parentAliasPath,
    required this.budget,
  });
}
