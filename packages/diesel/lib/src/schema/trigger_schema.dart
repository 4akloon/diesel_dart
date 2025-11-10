class TriggerSchema {
  const TriggerSchema({
    required this.name,
    required this.timing,
    required this.events,
    this.body,
    this.condition,
    this.whenClause,
    this.comment,
  });

  final String name;
  final TriggerTiming timing;
  final List<TriggerEvent> events;
  final String? body;
  final String? condition;
  final String? whenClause;
  final String? comment;
}

enum TriggerTiming {
  before,
  after,
  insteadOf,
}

enum TriggerEvent {
  insert,
  update,
  delete,
  truncate,
}

