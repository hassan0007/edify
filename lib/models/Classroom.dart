class Classroom {
  final String id;
  final String name;
  final String capacity;
  final String location;
  final String classType;   // 'Regular' | 'NAVTTC'
  final DateTime createdAt;

  Classroom({
    required this.id,
    required this.name,
    required this.capacity,
    required this.location,
    this.classType = 'Regular',   // default keeps all existing Firebase data safe
    required this.createdAt,
  });

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'id':        id,
      'name':      name,
      'capacity':  capacity,
      'location':  location,
      'classType': classType,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from Firebase snapshot
  factory Classroom.fromMap(Map<String, dynamic> map, String id) {
    return Classroom(
      id:        id,
      name:      map['name']      ?? '',
      capacity:  map['capacity']  ?? '',
      location:  map['location']  ?? '',
      classType: map['classType'] ?? 'Regular', // old records get 'Regular'
      createdAt: DateTime.parse(
          map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  // Copy with method for updates
  Classroom copyWith({
    String?   id,
    String?   name,
    String?   capacity,
    String?   location,
    String?   classType,
    DateTime? createdAt,
  }) {
    return Classroom(
      id:        id        ?? this.id,
      name:      name      ?? this.name,
      capacity:  capacity  ?? this.capacity,
      location:  location  ?? this.location,
      classType: classType ?? this.classType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isRegular => classType == 'Regular';
  bool get isNavttc  => classType == 'NAVTTC';
}