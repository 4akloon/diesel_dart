class EnumSchema {
  const EnumSchema({
    required this.name,
    required this.values,
    this.schema = 'main',
    this.comment,
  });

  final String schema;
  final String name;
  final List<String> values;
  final String? comment;
}

