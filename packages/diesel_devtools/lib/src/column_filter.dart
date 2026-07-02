/// One column predicate for `InspectorService.getTableData`.
///
/// [op] is one of `eq` / `ne` / `lt` / `le` / `gt` / `ge` / `like` / `isNull` /
/// `isNotNull`. [value] is ignored for the null checks; for `like` it should be
/// a string pattern (`%` wildcards). Combined with `AND`.
final class ColumnFilter {
  final String column;
  final String op;
  final Object? value;
  const ColumnFilter(this.column, this.op, [this.value]);

  factory ColumnFilter.fromJson(Map json) => ColumnFilter(
        json['column'] as String,
        json['op'] as String,
        json['value'],
      );
}
