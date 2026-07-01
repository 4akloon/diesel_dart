import 'package:flutter/material.dart';

/// Scrollable read-only table for query/data results.
class DataGrid extends StatelessWidget {
  final List<String> columns;
  final List<List<Object?>> rows;
  final Set<String> primaryKeys;

  /// Called with the tapped column name (for sorting), if provided.
  final void Function(String column)? onHeaderTap;
  final String? sortColumn;
  final bool sortDescending;

  const DataGrid({
    super.key,
    required this.columns,
    required this.rows,
    this.primaryKeys = const {},
    this.onHeaderTap,
    this.sortColumn,
    this.sortDescending = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (columns.isEmpty) {
      return const Center(child: Text('No columns'));
    }
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 30,
            dataRowMaxHeight: 40,
            columns: [
              for (final name in columns)
                DataColumn(
                  onSort: onHeaderTap == null
                      ? null
                      : (_, _) => onHeaderTap!(name),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (primaryKeys.contains(name))
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.vpn_key, size: 12),
                        ),
                      Text(name,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                      if (sortColumn == name)
                        Icon(
                          sortDescending
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          size: 12,
                        ),
                    ],
                  ),
                ),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    for (var i = 0; i < columns.length; i++)
                      DataCell(_cell(theme, i < row.length ? row[i] : null)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(ThemeData theme, Object? value) {
    if (value == null) {
      return Text('NULL',
          style: TextStyle(
              fontStyle: FontStyle.italic,
              color: theme.disabledColor));
    }
    return Text(
      '$value',
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
    );
  }
}
