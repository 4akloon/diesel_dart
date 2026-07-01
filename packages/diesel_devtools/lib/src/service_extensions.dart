import 'dart:convert';
import 'dart:developer' as developer;

import 'inspector_service.dart';

const _service = InspectorService();

/// Installs the `ext.diesel.*` VM service extensions the DevTools UI calls.
///
/// Called once, lazily, from [DieselDevTools.register]. Each handler receives
/// string-valued params (the VM service transport) and returns a JSON string.
void installServiceExtensions() {
  _register('ext.diesel.listInstances', (_) async {
    final instances = await _service.listInstances();
    return {'instances': [for (final i in instances) i.toJson()]};
  });

  _register('ext.diesel.getSchema', (p) async {
    return (await _service.getSchema(_require(p, 'id'))).toJson();
  });

  _register('ext.diesel.getTableData', (p) async {
    final page = await _service.getTableData(
      _require(p, 'id'),
      table: _require(p, 'table'),
      limit: int.tryParse(p['limit'] ?? '') ?? 50,
      offset: int.tryParse(p['offset'] ?? '') ?? 0,
      orderBy: p['orderBy'],
      desc: p['desc'] == 'true',
    );
    return page.toJson();
  });

  _register('ext.diesel.runSql', (p) async {
    final rawParams = p['params'];
    final params = rawParams == null || rawParams.isEmpty
        ? const <Object?>[]
        : (jsonDecode(rawParams) as List).cast<Object?>();
    final result = await _service.runSql(_require(p, 'id'), _require(p, 'sql'), params);
    return result.toJson();
  });
}

typedef _Handler = Future<Map<String, Object?>> Function(
    Map<String, String> params);

void _register(String name, _Handler handler) {
  developer.registerExtension(name, (method, params) async {
    try {
      final result = await handler(params);
      return developer.ServiceExtensionResponse.result(jsonEncode(result));
    } catch (e, st) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        jsonEncode({'error': e.toString(), 'stack': st.toString()}),
      );
    }
  });
}

String _require(Map<String, String> params, String key) {
  final value = params[key];
  if (value == null) throw ArgumentError('Missing parameter: $key');
  return value;
}
