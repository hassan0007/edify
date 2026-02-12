class Teacher {
  final String id;
  final String name;
  final String email;
  final String phone;
  final DateTime createdAt;

  Teacher({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.createdAt,
  });

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from Firebase document
  factory Teacher.fromMap(Map<String, dynamic> map, String documentId) {
    return Teacher(
      id: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Teacher copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    DateTime? createdAt,
  }) {
    return Teacher(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
