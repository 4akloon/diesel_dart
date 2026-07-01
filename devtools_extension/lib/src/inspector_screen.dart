import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'data_grid.dart';
import 'inspector_client.dart';

class InspectorScreen extends StatefulWidget {
  const InspectorScreen({super.key});

  @override
  State<InspectorScreen> createState() => _InspectorScreenState();
}

enum _Mode { data, sql }

class _InspectorScreenState extends State<InspectorScreen> {
  final _client = InspectorClient();
  final _sqlController = TextEditingController();

  List<InstanceInfo> _instances = const [];
  String? _instanceId;
  SchemaInfo? _schema;
  TableInfo? _table;

  TablePage? _page;
  int _offset = 0;
  static const _limit = 50;
  String? _orderBy;
  bool _desc = false;

  _Mode _mode = _Mode.data;
  SqlResult? _sqlResult;
  bool _sqlRunning = false;

  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    serviceManager.connectedState.addListener(_onConnectionChange);
    if (serviceManager.connectedState.value.connected) _loadInstances();
  }

  @override
  void dispose() {
    serviceManager.connectedState.removeListener(_onConnectionChange);
    _sqlController.dispose();
    super.dispose();
  }

  void _onConnectionChange() {
    if (serviceManager.connectedState.value.connected && mounted) {
      _loadInstances();
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadInstances() => _guard(() async {
        final instances = await _client.listInstances();
        _instances = instances;
        if (instances.isNotEmpty &&
            !instances.any((i) => i.id == _instanceId)) {
          await _selectInstance(instances.first.id);
        } else {
          setState(() {});
        }
      });

  Future<void> _selectInstance(String id) => _guard(() async {
        _instanceId = id;
        _schema = await _client.getSchema(id);
        _table = null;
        _page = null;
        _sqlResult = null;
        final tables = _schema?.tables ?? const [];
        if (tables.isNotEmpty) {
          await _openTable(tables.first);
        } else {
          setState(() {});
        }
      });

  Future<void> _openTable(TableInfo table) => _guard(() async {
        _table = table;
        _offset = 0;
        _orderBy = null;
        _desc = false;
        await _loadPage();
      });

  Future<void> _loadPage() async {
    final id = _instanceId;
    final table = _table;
    if (id == null || table == null) return;
    _page = await _client.getTableData(
      id,
      table.name,
      limit: _limit,
      offset: _offset,
      orderBy: _orderBy,
      desc: _desc,
    );
    if (mounted) setState(() {});
  }

  void _sortBy(String column) => _guard(() async {
        if (_orderBy == column) {
          _desc = !_desc;
        } else {
          _orderBy = column;
          _desc = false;
        }
        _offset = 0;
        await _loadPage();
      });

  void _page$(int delta) => _guard(() async {
        _offset = (_offset + delta).clamp(0, 1 << 30);
        await _loadPage();
      });

  Future<void> _runSql() async {
    final id = _instanceId;
    if (id == null) return;
    setState(() {
      _sqlRunning = true;
      _error = null;
    });
    try {
      final result = await _client.runSql(id, _sqlController.text);
      if (mounted) setState(() => _sqlResult = result);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _sqlRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!serviceManager.connectedState.value.connected) {
      return const Center(child: Text('Waiting for a connected app…'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _topBar(),
        if (_error case final e?) _errorBanner(e),
        const Divider(height: 1),
        Expanded(
          child: _instances.isEmpty
              ? _empty('No registered diesel connections.\n'
                  'Call DieselDevTools.register(conn) in your app.')
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 220, child: _tableList()),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child:
                          _mode == _Mode.data ? _dataView() : _sqlConsole(),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.storage, size: 18),
          const SizedBox(width: 8),
          if (_instances.isNotEmpty)
            DropdownButton<String>(
              value: _instanceId,
              underline: const SizedBox.shrink(),
              items: [
                for (final i in _instances)
                  DropdownMenuItem(
                    value: i.id,
                    child: Text('${i.name}  ·  ${i.backend}'),
                  ),
              ],
              onChanged: (id) {
                if (id != null) _selectInstance(id);
              },
            ),
          const SizedBox(width: 12),
          SegmentedButton<_Mode>(
            segments: const [
              ButtonSegment(value: _Mode.data, label: Text('Data')),
              ButtonSegment(value: _Mode.sql, label: Text('SQL')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const Spacer(),
          if (_busy)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadInstances,
          ),
        ],
      ),
    );
  }

  Widget _tableList() {
    final tables = _schema?.tables ?? const [];
    if (tables.isEmpty) return _empty('No tables');
    return ListView(
      children: [
        for (final t in tables)
          ListTile(
            dense: true,
            selected: t.name == _table?.name,
            leading: const Icon(Icons.table_rows, size: 16),
            title: Text(t.name, overflow: TextOverflow.ellipsis),
            subtitle: Text('${t.columns.length} cols'),
            onTap: () {
              setState(() => _mode = _Mode.data);
              _openTable(t);
            },
          ),
      ],
    );
  }

  Widget _dataView() {
    final table = _table;
    final page = _page;
    if (table == null || page == null) return _empty('Select a table');
    final shownFrom = page.rows.isEmpty ? 0 : page.offset + 1;
    final shownTo = page.offset + page.rows.length;
    return Column(
      children: [
        Expanded(
          child: DataGrid(
            columns: page.columns,
            rows: page.rows,
            primaryKeys: table.primaryKeys,
            onHeaderTap: _sortBy,
            sortColumn: _orderBy,
            sortDescending: _desc,
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Text('${table.name}: $shownFrom–$shownTo of ${page.total}'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: page.offset > 0 ? () => _page$(-_limit) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: shownTo < page.total ? () => _page$(_limit) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sqlConsole() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _sqlController,
            maxLines: 5,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'SELECT * FROM …   (runs reads and writes — dev only)',
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Run'),
                onPressed: _sqlRunning ? null : _runSql,
              ),
              const SizedBox(width: 12),
              if (_sqlRunning)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(child: _sqlResultView()),
      ],
    );
  }

  Widget _sqlResultView() {
    final result = _sqlResult;
    if (result == null) return _empty('Run a query to see results');
    switch (result.kind) {
      case 'error':
        return _errorBanner(result.error ?? 'Unknown error');
      case 'write':
        return _empty(result.affected == null
            ? 'Statement executed.'
            : '${result.affected} row(s) affected.');
      default:
        return Column(
          children: [
            if (result.truncated)
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.all(6),
                child: const Text('Results truncated to 1000 rows'),
              ),
            Expanded(
              child: DataGrid(columns: result.columns, rows: result.rows),
            ),
          ],
        );
    }
  }

  Widget _errorBanner(String message) => Container(
        width: double.infinity,
        color: Theme.of(context).colorScheme.errorContainer,
        padding: const EdgeInsets.all(10),
        child: Text(
          message,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer),
        ),
      );

  Widget _empty(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}
