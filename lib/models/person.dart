class Person {
  final int? id;
  final String name;
  final DateTime createdAt;

  const Person({
    this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
      };

  factory Person.fromMap(Map<String, dynamic> map) => Person(
        id: map['id'] as int,
        name: map['name'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  @override
  String toString() => name;
}
