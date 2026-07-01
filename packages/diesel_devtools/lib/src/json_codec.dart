import 'dart:typed_data';

/// Coerces a raw driver value into a JSON-safe value for transport over the VM
/// service to the DevTools extension.
///
/// `null`/`num`/`bool`/`String` pass through unchanged; [DateTime] becomes an
/// ISO-8601 string; blobs (`Uint8List`/`List<int>`) become a short tagged hex
/// preview; anything else falls back to `toString()`.
Object? toJsonValue(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is DateTime) return value.toIso8601String();
  if (value is Uint8List) return _hexPreview(value);
  if (value is List<int>) return _hexPreview(Uint8List.fromList(value));
  return value.toString();
}

/// Blobs can be arbitrarily large, so show a capped hex preview plus the true
/// byte length rather than shipping the whole payload to the UI.
String _hexPreview(Uint8List bytes) {
  const cap = 32;
  final shown = bytes.length > cap ? bytes.sublist(0, cap) : bytes;
  final hex = [for (final b in shown) b.toRadixString(16).padLeft(2, '0')].join();
  final ellipsis = bytes.length > cap ? '…' : '';
  return '0x$hex$ellipsis (${bytes.length} bytes)';
}
