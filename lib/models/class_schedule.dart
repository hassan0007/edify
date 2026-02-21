// models/class_schedule.dart

import 'package:flutter/foundation.dart';

enum SchedulePattern {
  fiveDays,   // Mon-Fri
  sixDays,    // Mon-Sat
  monWedFri,  // Mon, Wed, Fri
  tueThuSat,  // Tue, Thu, Sat
}

enum ClassType {
  regular,
  navttc,
}

class ClassSchedule {
  final String          id;
  final String          teacherId;
  final String          teacherName;
  final String          batchName;
  final String          classroom;
  final SchedulePattern pattern;
  final String          timeSlot;
  final List<String>    days;
  final DateTime        createdAt;
  final ClassType       classType;
  final String?         categoryId;
  final String?         categoryName;

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
    this.classType    = ClassType.regular,
    this.categoryId,
    this.categoryName,
  });

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      // Do NOT include 'id' — the RTDB key is the id, storing it inside
      // the node is redundant and can cause confusion on reads.
      'teacherId':    teacherId,
      'teacherName':  teacherName,
      'batchName':    batchName,
      'classroom':    classroom,
      'pattern':      pattern.toString().split('.').last,
      'timeSlot':     timeSlot,
      // RTDB requires List to be stored as a Map<index, value> or
      // as a plain List — Flutter's RTDB plugin handles List<String>
      // correctly, but we cast explicitly to avoid type inference issues.
      'days':         List<String>.from(days),
      'createdAt':    createdAt.toIso8601String(),
      'classType':    classType.toString().split('.').last,
      // Use empty string instead of null — RTDB drops null-valued keys
      // silently, which can cause fromMap to fail on reads.
      'categoryId':   categoryId   ?? '',
      'categoryName': categoryName ?? '',
    };
  }

  factory ClassSchedule.fromMap(Map<String, dynamic> map, String documentId) {
    return ClassSchedule(
      id:           documentId,
      teacherId:    map['teacherId']    as String? ?? '',
      teacherName:  map['teacherName']  as String? ?? '',
      batchName:    map['batchName']    as String? ?? '',
      classroom:    map['classroom']    as String? ?? '',
      pattern:      _parsePattern(map['pattern']),
      timeSlot:     map['timeSlot']     as String? ?? '',
      // RTDB can return days as a List or as a Map<index, value>
      // depending on how it was stored — handle both.
      days:         _parseDays(map['days']),
      createdAt:    DateTime.parse(map['createdAt'] as String),
      classType:    _parseClassType(map['classType']),
      // Empty string sentinel → treat as null
      categoryId:   _nullIfEmpty(map['categoryId']   as String?),
      categoryName: _nullIfEmpty(map['categoryName'] as String?),
    );
  }

  // ── Private parse helpers ─────────────────────────────────────────────────

  /// RTDB sometimes returns a stored List as a Map<String, dynamic>
  /// keyed by index ("0", "1", ...) depending on client. Handle both.
  static List<String> _parseDays(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    if (raw is Map) {
      // RTDB index-keyed map → sort by key and extract values
      final entries = raw.entries.toList()
        ..sort((a, b) {
          final ai = int.tryParse(a.key.toString()) ?? 0;
          final bi = int.tryParse(b.key.toString()) ?? 0;
          return ai.compareTo(bi);
        });
      return entries.map((e) => e.value.toString()).toList();
    }
    return [];
  }

  static String? _nullIfEmpty(String? value) =>
      (value == null || value.isEmpty) ? null : value;

  // ── Pattern helpers ───────────────────────────────────────────────────────

  static SchedulePattern _parsePattern(dynamic raw) {
    switch (raw) {
      case 'fiveDays':  return SchedulePattern.fiveDays;
      case 'sixDays':   return SchedulePattern.sixDays;
      case 'monWedFri': return SchedulePattern.monWedFri;
      case 'tueThuSat': return SchedulePattern.tueThuSat;
      default:          return SchedulePattern.fiveDays;
    }
  }

  static String getPatternLabel(SchedulePattern pattern) {
    switch (pattern) {
      case SchedulePattern.fiveDays:  return '5 Days (Mon–Fri)';
      case SchedulePattern.sixDays:   return '6 Days (Mon–Sat)';
      case SchedulePattern.monWedFri: return 'Mon, Wed, Fri';
      case SchedulePattern.tueThuSat: return 'Tue, Thu, Sat';
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

  // ── ClassType helpers ─────────────────────────────────────────────────────

  static ClassType _parseClassType(dynamic raw) {
    switch (raw) {
      case 'navttc':  return ClassType.navttc;
      case 'regular': return ClassType.regular;
      default:        return ClassType.regular;
    }
  }

  static String getClassTypeLabel(ClassType type) {
    switch (type) {
      case ClassType.regular: return 'Regular';
      case ClassType.navttc:  return 'NAVTTC';
    }
  }

  // ── Copy ──────────────────────────────────────────────────────────────────

  ClassSchedule copyWith({
    String?          id,
    String?          teacherId,
    String?          teacherName,
    String?          batchName,
    String?          classroom,
    SchedulePattern? pattern,
    String?          timeSlot,
    List<String>?    days,
    DateTime?        createdAt,
    ClassType?       classType,
    String?          categoryId,
    String?          categoryName,
  }) {
    return ClassSchedule(
      id:           id           ?? this.id,
      teacherId:    teacherId    ?? this.teacherId,
      teacherName:  teacherName  ?? this.teacherName,
      batchName:    batchName    ?? this.batchName,
      classroom:    classroom    ?? this.classroom,
      pattern:      pattern      ?? this.pattern,
      timeSlot:     timeSlot     ?? this.timeSlot,
      days:         days         ?? this.days,
      createdAt:    createdAt    ?? this.createdAt,
      classType:    classType    ?? this.classType,
      categoryId:   categoryId   ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ClassSchedule &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ClassSchedule(id: $id, batch: $batchName, teacher: $teacherName, '
          'slot: $timeSlot, type: ${classType.name}, category: $categoryName)';
}