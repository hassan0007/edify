enum SchedulePattern {
  fiveDays,      // Mon-Fri
  sixDays,       // Mon-Sat
  monWedFri,     // Mon, Wed, Fri
  tueThuSat,     // Tue, Thu, Sat
}

class ClassSchedule {
  final String id;
  final String teacherId;
  final String teacherName;
  final String batchName;
  final String classroom;
  final SchedulePattern pattern;
  final String timeSlot; // e.g., "09:00-10:30"
  final List<String> days; // e.g., ["Monday", "Tuesday", ...]
  final DateTime createdAt;

  ClassSchedule({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.batchName,
    required this.classroom,
    required this.pattern,
    required this.timeSlot,
    required this.days,
    required this.createdAt,
  });

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'batchName': batchName,
      'classroom': classroom,
      'pattern': pattern.toString().split('.').last,
      'timeSlot': timeSlot,
      'days': days,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from Firebase document
  factory ClassSchedule.fromMap(Map<String, dynamic> map, String documentId) {
    return ClassSchedule(
      id: documentId,
      teacherId: map['teacherId'] ?? '',
      teacherName: map['teacherName'] ?? '',
      batchName: map['batchName'] ?? '',
      classroom: map['classroom'] ?? '',
      pattern: _parsePattern(map['pattern']),
      timeSlot: map['timeSlot'] ?? '',
      days: List<String>.from(map['days'] ?? []),
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  static SchedulePattern _parsePattern(String pattern) {
    switch (pattern) {
      case 'fiveDays':
        return SchedulePattern.fiveDays;
      case 'sixDays':
        return SchedulePattern.sixDays;
      case 'monWedFri':
        return SchedulePattern.monWedFri;
      case 'tueThuSat':
        return SchedulePattern.tueThuSat;
      default:
        return SchedulePattern.fiveDays;
    }
  }

  static String getPatternLabel(SchedulePattern pattern) {
    switch (pattern) {
      case SchedulePattern.fiveDays:
        return '5 Days (Mon-Fri)';
      case SchedulePattern.sixDays:
        return '6 Days (Mon-Sat)';
      case SchedulePattern.monWedFri:
        return 'Mon, Wed, Fri';
      case SchedulePattern.tueThuSat:
        return 'Tue, Thu, Sat';
    }
  }

  static List<String> getDaysForPattern(SchedulePattern pattern) {
    switch (pattern) {
      case SchedulePattern.fiveDays:
        return ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
      case SchedulePattern.sixDays:
        return ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      case SchedulePattern.monWedFri:
        return ['Monday', 'Wednesday', 'Friday'];
      case SchedulePattern.tueThuSat:
        return ['Tuesday', 'Thursday', 'Saturday'];
    }
  }
}