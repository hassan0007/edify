// services/schedule_service.dart

import 'package:firebase_database/firebase_database.dart';
import '../models/class_schedule.dart';
import '../models/category.dart';

class ScheduleService {
  final DatabaseReference _database    = FirebaseDatabase.instance.ref();
  final String            _collection  = 'schedules';

  // ── Legacy global constants (fallback when no category is used) ───────────
  static const int _dayStartMinutes   = 11 * 60;       // 11:00 AM
  static const int _breakStartMinutes = 14 * 60;       // 2:00 PM
  static const int _breakEndMinutes   = 14 * 60 + 30;  // 2:30 PM
  static const int _dayEndMinutes     = 19 * 60;       // 7:00 PM
  static const int _slotDuration      = 90;            // minutes

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<String> addSchedule(ClassSchedule schedule) async {
    try {
      final newRef = _database.child(_collection).push();
      await newRef.set(schedule.toMap());
      return newRef.key!;
    } catch (e) {
      throw Exception('Error adding schedule: $e');
    }
  }

  Stream<List<ClassSchedule>> getSchedules() {
    return _database.child(_collection).onValue.map((event) {
      return _parseAndSort(event.snapshot.value);
    });
  }

  Stream<List<ClassSchedule>> getSchedulesByType(ClassType type) {
    return getSchedules()
        .map((all) => all.where((s) => s.classType == type).toList());
  }

  Stream<List<ClassSchedule>> getSchedulesByCategory(String categoryId) {
    return getSchedules()
        .map((all) => all.where((s) => s.categoryId == categoryId).toList());
  }

  Stream<List<ClassSchedule>> getSchedulesByTeacher(String teacherId) {
    return _database
        .child(_collection)
        .orderByChild('teacherId')
        .equalTo(teacherId)
        .onValue
        .map((event) => _parseAndSort(event.snapshot.value));
  }

  Stream<List<ClassSchedule>> getSchedulesByTeacherAndType(
      String teacherId,
      ClassType type,
      ) {
    return getSchedulesByTeacher(teacherId)
        .map((all) => all.where((s) => s.classType == type).toList());
  }

  // ── Availability ──────────────────────────────────────────────────────────

  /// Returns true when [timeSlot] is free for the given [teacherId] AND
  /// [classroom] on the given [days].
  ///
  /// Pass [category] to validate against that category's break window.
  /// When null, the global 2:00-2:30 PM break is used as a fallback.
  Future<bool> isTimeSlotAvailable(
      String            timeSlot,
      List<String>      days,
      String            teacherId,
      String            classroom, {
        ScheduleCategory? category,
      }) async {
    // Break validation
    if (category != null) {
      if (_slotOverlapsBreakWindow(
        timeSlot,
        breakStart: category.breakStartTotal,
        breakEnd:   category.breakEndTotal,
        hasBreak:   category.hasBreak,
      )) return false;
    } else {
      if (_slotOverlapsBreak(timeSlot)) return false;
    }

    try {
      final event = await _database
          .child(_collection)
          .orderByChild('timeSlot')
          .equalTo(timeSlot)
          .once();

      if (event.snapshot.value == null) return true;

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      for (final entry in data.entries) {
        final sd       = Map<String, dynamic>.from(entry.value as Map);
        final existing = ClassSchedule.fromMap(sd, entry.key as String);

        final daysOverlap = existing.days.any((d) => days.contains(d));
        if (!daysOverlap) continue;

        if (existing.teacherId == teacherId) return false;
        if (existing.classroom == classroom) return false;
      }
      return true;
    } catch (e) {
      throw Exception('Error checking availability: $e');
    }
  }

  /// Returns all valid slots free for [teacherId] and [classroom] on the
  /// days implied by [pattern].
  ///
  /// When [category] is provided, its slots drive everything (start/end/
  /// duration/break). Otherwise falls back to the global hardcoded schedule.
  Future<List<String>> getAvailableTimeSlots(
      SchedulePattern   pattern,
      String            teacherId,
      String            classroom, {
        ScheduleCategory? category,
      }) async {
    final allSlots = category != null
        ? category.timeSlots
        : _generateGlobalTimeSlots();

    final days = ClassSchedule.getDaysForPattern(pattern);

    final List<String> available = [];
    for (final slot in allSlots) {
      final free = await isTimeSlotAvailable(
        slot, days, teacherId, classroom,
        category: category,
      );
      if (free) available.add(slot);
    }
    return available;
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteSchedule(String id) async {
    try {
      await _database.child(_collection).child(id).remove();
    } catch (e) {
      throw Exception('Error deleting schedule: $e');
    }
  }

  // ── Time-slot generation ──────────────────────────────────────────────────

  /// Global fallback: 11 AM to 7 PM, 90-min slots, 2:00-2:30 PM break.
  List<String> _generateGlobalTimeSlots() {
    final List<String> slots = [];
    int cur = _dayStartMinutes;

    while (cur < _dayEndMinutes) {
      final end = cur + _slotDuration;

      if (cur >= _breakStartMinutes && cur < _breakEndMinutes) {
        cur = _breakEndMinutes;
        continue;
      }
      if (cur < _breakStartMinutes && end > _breakStartMinutes) {
        cur = _breakEndMinutes;
        continue;
      }
      if (end <= _dayEndMinutes) {
        slots.add('${_minutesToTime(cur)}-${_minutesToTime(end)}');
        cur = end;
      } else {
        break;
      }
    }
    return slots;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  List<ClassSchedule> _parseAndSort(Object? raw) {
    final data = raw as Map<dynamic, dynamic>?;
    if (data == null) return [];

    final schedules = data.entries.map((entry) {
      final sd = Map<String, dynamic>.from(entry.value as Map);
      return ClassSchedule.fromMap(sd, entry.key as String);
    }).toList();

    schedules.sort((a, b) => a.timeSlot.compareTo(b.timeSlot));
    return schedules;
  }

  /// Legacy global break check (2:00-2:30 PM).
  bool _slotOverlapsBreak(String timeSlot) {
    try {
      final startMinutes = _timeStringToMinutes(
          timeSlot.split('-').first.trim());
      return startMinutes >= _breakStartMinutes &&
          startMinutes < _breakEndMinutes;
    } catch (_) {
      return false;
    }
  }

  /// Category-aware break check using the category's own break window.
  bool _slotOverlapsBreakWindow(
      String timeSlot, {
        required int  breakStart,
        required int  breakEnd,
        required bool hasBreak,
      }) {
    if (!hasBreak) return false;
    try {
      final parts     = timeSlot.split('-');
      final slotStart = _timeStringToMinutes(parts.first.trim());
      final slotEnd   = _timeStringToMinutes(parts.last.trim());
      // True if slot and break windows overlap at all
      return slotStart < breakEnd && slotEnd > breakStart;
    } catch (_) {
      return false;
    }
  }

  int _timeStringToMinutes(String time) {
    final parts  = time.trim().split(' ');
    final hm     = parts[0].split(':');
    final isPM   = parts[1].toUpperCase() == 'PM';
    int    hour  = int.parse(hm[0]);
    final minute = int.parse(hm[1]);

    if (isPM  && hour != 12) hour += 12;
    if (!isPM && hour == 12) hour  = 0;

    return hour * 60 + minute;
  }

  String _minutesToTime(int totalMinutes) {
    final hour        = totalMinutes ~/ 60;
    final minute      = totalMinutes % 60;
    final period      = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }
}