class SequenceSchema {
  const SequenceSchema({
    required this.name,
    this.schema = 'main',
    this.startValue,
    this.incrementBy,
    this.minValue,
    this.maxValue,
    this.cycle = false,
    this.cacheSize,
    this.comment,
  });

  final String schema;
  final String name;
  final int? startValue;
  final int? incrementBy;
  final int? minValue;
  final int? maxValue;
  final bool cycle;
  final int? cacheSize;
  final String? comment;
}

