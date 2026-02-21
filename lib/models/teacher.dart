// models/teacher.dart

class Teacher {
  final String   id;
  final String   name;
  final String   email;
  final String   phone;
  final DateTime createdAt;

  Teacher({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    // Do NOT store 'id' — the RTDB push key is the id.
    'name':      name,
    'email':     email,
    'phone':     phone,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Teacher.fromMap(Map<String, dynamic> map, String documentId) =>
      Teacher(
        id:        documentId,
        name:      map['name']      as String? ?? '',
        email:     map['email']     as String? ?? '',
        phone:     map['phone']     as String? ?? '',
        createdAt: DateTime.parse(map['createdAt'] as String),
      );

  Teacher copyWith({
    String?   id,
    String?   name,
    String?   email,
    String?   phone,
    DateTime? createdAt,
  }) =>
      Teacher(
        id:        id        ?? this.id,
        name:      name      ?? this.name,
        email:     email     ?? this.email,
        phone:     phone     ?? this.phone,
        createdAt: createdAt ?? this.createdAt,
      );
}