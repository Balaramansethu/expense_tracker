import 'package:flutter/material.dart';

enum Category {
  food(
    icon: Icons.restaurant,
    color: Color(0xFFEF6C00),
    keywords: [
      'grocery', 'groceries', 'restaurant', 'coffee', 'lunch', 'dinner',
      'breakfast', 'snack', 'pizza', 'burger', 'food', 'eat', 'meal',
      'drink', 'tea', 'juice', 'starbucks', 'mcdonald', 'takeout',
    ],
  ),
  transport(
    icon: Icons.directions_car,
    color: Color(0xFF1565C0),
    keywords: [
      'uber', 'lyft', 'taxi', 'cab', 'bus', 'train', 'metro', 'subway',
      'gas', 'fuel', 'petrol', 'parking', 'toll', 'ride', 'commute',
    ],
  ),
  shopping(
    icon: Icons.shopping_bag,
    color: Color(0xFF7B1FA2),
    keywords: [
      'clothes', 'clothing', 'shoes', 'amazon', 'store', 'mall', 'shirt',
      'pants', 'jacket', 'dress', 'online', 'order', 'bought', 'purchase',
    ],
  ),
  bills(
    icon: Icons.receipt_long,
    color: Color(0xFF00838F),
    keywords: [
      'rent', 'electricity', 'electric', 'water', 'internet', 'wifi',
      'phone', 'insurance', 'bill', 'subscription', 'netflix', 'spotify',
      'utility', 'utilities', 'mortgage',
    ],
  ),
  health(
    icon: Icons.favorite,
    color: Color(0xFFC62828),
    keywords: [
      'doctor', 'pharmacy', 'medicine', 'gym', 'hospital', 'dentist',
      'prescription', 'health', 'medical', 'therapy', 'vitamin',
    ],
  ),
  entertainment(
    icon: Icons.movie,
    color: Color(0xFFAD1457),
    keywords: [
      'movie', 'cinema', 'concert', 'game', 'bar', 'drinks', 'party',
      'club', 'ticket', 'show', 'theater', 'museum', 'fun', 'event',
    ],
  ),
  travel(
    icon: Icons.flight,
    color: Color(0xFF2E7D32),
    keywords: [
      'hotel', 'flight', 'airbnb', 'booking', 'hostel', 'vacation',
      'trip', 'travel', 'airport', 'luggage', 'resort',
    ],
  ),
  other(
    icon: Icons.more_horiz,
    color: Color(0xFF546E7A),
    keywords: [],
  );

  const Category({
    required this.icon,
    required this.color,
    required this.keywords,
  });

  final IconData icon;
  final Color color;
  final List<String> keywords;

  String get displayName => name[0].toUpperCase() + name.substring(1);
}

class Expense {
  final int? id;
  final double amount;
  final String description;
  final Category category;
  final DateTime createdAt;

  const Expense({
    this.id,
    required this.amount,
    required this.description,
    required this.category,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'amount': amount,
        'description': description,
        'category': category.name,
        'created_at': createdAt.toIso8601String(),
      };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
        id: map['id'] as int,
        amount: (map['amount'] as num).toDouble(),
        description: map['description'] as String,
        category: Category.values.firstWhere(
          (c) => c.name == map['category'],
          orElse: () => Category.other,
        ),
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Expense copyWith({
    int? id,
    double? amount,
    String? description,
    Category? category,
    DateTime? createdAt,
  }) =>
      Expense(
        id: id ?? this.id,
        amount: amount ?? this.amount,
        description: description ?? this.description,
        category: category ?? this.category,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  String toString() => '$description: \$${amount.toStringAsFixed(2)}';
}
