class ExtensionSchema {
  const ExtensionSchema({
    required this.name,
    this.version,
    this.schema = 'main',
    this.comment,
  });

  final String schema;
  final String name;
  final String? version;
  final String? comment;
}

