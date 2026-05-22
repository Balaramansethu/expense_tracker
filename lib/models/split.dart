class SplitEntry {
  final int? id;
  final int expenseId;
  final int personId;
  final String personName;
  final double totalAmount;
  final double splitAmount;
  final String description;
  final String category;
  final DateTime createdAt;

  const SplitEntry({
    this.id,
    required this.expenseId,
    required this.personId,
    required this.personName,
    required this.totalAmount,
    required this.splitAmount,
    required this.description,
    required this.category,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'expense_id': expenseId,
        'person_id': personId,
        'person_name': personName,
        'total_amount': totalAmount,
        'split_amount': splitAmount,
        'description': description,
        'category': category,
        'created_at': createdAt.toIso8601String(),
      };

  factory SplitEntry.fromMap(Map<String, dynamic> map) => SplitEntry(
        id: map['id'] as int,
        expenseId: map['expense_id'] as int,
        personId: map['person_id'] as int,
        personName: map['person_name'] as String,
        totalAmount: (map['total_amount'] as num).toDouble(),
        splitAmount: (map['split_amount'] as num).toDouble(),
        description: map['description'] as String,
        category: map['category'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
