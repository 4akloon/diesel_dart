import 'package:diesel/diesel.dart';

import 'service_extensions.dart';

/// Process-wide registry of live [Connection]s exposed to the DevTools
/// inspector.
///
/// This is **dev-only** tooling: connections only become visible after an
/// explicit [register] call, and the underlying `ext.diesel.*` service
/// extensions require the VM service (debug / `--observe`) — nothing is exposed
/// in a release build that never calls [register].
final class DieselDevTools {
  DieselDevTools._();

  static final Map<String, _Entry> _entries = {};
  static int _counter = 0;
  static bool _installed = false;

  /// Registers [conn] so it shows up as a selectable instance in the inspector.
  ///
  /// [name] is the display label (defaults to `instance-N`). Returns the
  /// generated instance id, which you can pass to [unregister].
  static String register(Connection conn, {String? name}) {
    final index = _counter++;
    final id = 'inst-$index';
    _entries[id] = _Entry(id, name ?? 'instance-$index', conn);
    if (!_installed) {
      _installed = true;
      // Best-effort: the registry stays usable even if the VM service is
      // unavailable (e.g. under `dart test`) or the extensions can't install.
      try {
        installServiceExtensions();
      } catch (_) {}
    }
    return id;
  }

  /// Removes a previously [register]ed instance.
  static void unregister(String id) => _entries.remove(id);

  /// Drops all registered instances (does not close the connections).
  static void clear() => _entries.clear();

  /// The registered instances, in registration order.
  static List<RegisteredInstance> get instances =>
      [for (final e in _entries.values) e.info];

  /// Looks up the live connection for an instance id, or `null` if unknown.
  static Connection? connection(String id) => _entries[id]?.conn;
}

/// Public description of a registered connection.
final class RegisteredInstance {
  final String id;
  final String name;

  /// Backend kind — `sqlite`, `postgres`, or the runtime type name.
  final String backend;

  const RegisteredInstance({
    required this.id,
    required this.name,
    required this.backend,
  });

  Map<String, Object?> toJson() =>
      {'id': id, 'name': name, 'backend': backend};
}

final class _Entry {
  final String id;
  final String name;
  final Connection conn;

  _Entry(this.id, this.name, this.conn);

  RegisteredInstance get info =>
      RegisteredInstance(id: id, name: name, backend: _backendOf(conn));
}

String _backendOf(Connection conn) {
  final name = conn.runtimeType.toString().toLowerCase();
  if (name.contains('sqlite')) return 'sqlite';
  if (name.contains('postgres')) return 'postgres';
  return name;
}
