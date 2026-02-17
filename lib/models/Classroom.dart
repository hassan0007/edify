class Classroom {
  final String id;
  final String name;
  final String capacity;
  final String location;
  final DateTime createdAt;

  Classroom({
    required this.id,
    required this.name,
    required this.capacity,
    required this.location,
    required this.createdAt,
  });

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'capacity': capacity,
      'location': location,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from Firebase snapshot
  factory Classroom.fromMap(Map<String, dynamic> map, String id) {
    return Classroom(
      id: id,
      name: map['name'] ?? '',
      capacity: map['capacity'] ?? '',
      location: map['location'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  // Copy with method for updates
  Classroom copyWith({
    String? id,
    String? name,
    String? capacity,
    String? location,
    DateTime? createdAt,
  }) {
    return Classroom(
      id: id ?? this.id,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}