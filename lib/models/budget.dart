class Budget {
  final int? id;
  final double amount;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;

  Budget({
    this.id,
    required this.amount,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Budget copyWith({
    int? id,
    double? amount,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
  }) {
    return Budget(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
