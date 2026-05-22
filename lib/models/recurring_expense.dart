import 'expense.dart';

class RecurringExpense {
  final int? id;
  final double amount;
  final String description;
  final Category category;
  final int dayOfMonth; // 1-28 (safe for all months)
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoggedAt; // tracks the last time this was auto-logged

  const RecurringExpense({
    this.id,
    required this.amount,
    required this.description,
    required this.category,
    required this.dayOfMonth,
    this.isActive = true,
    required this.createdAt,
    this.lastLoggedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'amount': amount,
        'description': description,
        'category': category.name,
        'day_of_month': dayOfMonth,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'last_logged_at': lastLoggedAt?.toIso8601String(),
      };

  factory RecurringExpense.fromMap(Map<String, dynamic> map) => RecurringExpense(
        id: map['id'] as int,
        amount: (map['amount'] as num).toDouble(),
        description: map['description'] as String,
        category: Category.values.firstWhere(
          (c) => c.name == map['category'],
          orElse: () => Category.other,
        ),
        dayOfMonth: map['day_of_month'] as int,
        isActive: (map['is_active'] as int) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        lastLoggedAt: map['last_logged_at'] != null
            ? DateTime.parse(map['last_logged_at'] as String)
            : null,
      );

  RecurringExpense copyWith({
    int? id,
    double? amount,
    String? description,
    Category? category,
    int? dayOfMonth,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLoggedAt,
  }) =>
      RecurringExpense(
        id: id ?? this.id,
        amount: amount ?? this.amount,
        description: description ?? this.description,
        category: category ?? this.category,
        dayOfMonth: dayOfMonth ?? this.dayOfMonth,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        lastLoggedAt: lastLoggedAt ?? this.lastLoggedAt,
      );
}
