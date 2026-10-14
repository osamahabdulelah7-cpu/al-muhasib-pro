enum EntryType { income, expense }

class FinancialEntry {
  const FinancialEntry({
    this.id,
    required this.title,
    required this.amountMinor,
    required this.type,
    required this.createdAt,
    this.note = '',
  });

  final int? id;
  final String title;
  /// Store money in the smallest currency unit to avoid floating-point rounding.
  final int amountMinor;
  final EntryType type;
  final DateTime createdAt;
  final String note;

  Map<String, Object?> toMap() => {
    'id': id, 'title': title, 'amount_minor': amountMinor,
    'type': type.name, 'created_at': createdAt.toIso8601String(), 'note': note,
  };

  factory FinancialEntry.fromMap(Map<String, Object?> map) => FinancialEntry(
    id: map['id'] as int?,
    title: map['title'] as String,
    amountMinor: map['amount_minor'] as int,
    type: EntryType.values.firstWhere((v) => v.name == map['type'], orElse: () => EntryType.expense),
    createdAt: DateTime.parse(map['created_at'] as String),
    note: map['note'] as String? ?? '',
  );
}
