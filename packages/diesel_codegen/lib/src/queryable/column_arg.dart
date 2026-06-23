/// One constructor column mapped to a schema accessor expression.
final class ColumnArg {
  final String paramName;
  final bool isNamed;
  final String columnExpr;

  const ColumnArg({
    required this.paramName,
    required this.isNamed,
    required this.columnExpr,
  });
}
