import 'package:firebase_database/firebase_database.dart';
import '../models/class_schedule.dart';

class ScheduleService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String _collection = 'schedules';

  // ── Break / day boundary constants ────────────────────────────────────────
  // Keep these in sync with home_screen.dart and add_class_dialog.dart.
  static const int _dayStartMinutes   = 11 * 60;      // 11:00 AM
  static const int _breakStartMinutes = 14 * 60;      // 2:00 PM
  static const int _breakEndMinutes   = 14 * 60 + 30; // 2:30 PM
  static const int _dayEndMinutes     = 19 * 60;      // 7:00 PM
  static const int _slotDuration      = 90;           // minutes per class

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Add a new class schedule.
  Future<String> addSchedule(ClassSchedule schedule) async {
    try {
      final newRef = _database.child(_collection).push();
      await newRef.set(schedule.toMap());
      return newRef.key!;
    } catch (e) {
      throw Exception('Error adding schedule: $e');
    }
  }

  /// Stream of all schedules, sorted by time slot.
  Stream<List<ClassSchedule>> getSchedules() {
    return _database.child(_collection).onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      final schedules = data.entries.map((entry) {
        final scheduleData = Map<String, dynamic>.from(entry.value as Map);
        return ClassSchedule.fromMap(scheduleData, entry.key as String);
      }).toList();

      schedules.sort((a, b) => a.timeSlot.compareTo(b.timeSlot));
      return schedules;
    });
  }

  /// Stream of schedules filtered by teacher ID.
  Stream<List<ClassSchedule>> getSchedulesByTeacher(String teacherId) {
    return _database
        .child(_collection)
        .orderByChild('teacherId')
        .equalTo(teacherId)
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];

      final schedules = data.entries.map((entry) {
        final scheduleData = Map<String, dynamic>.from(entry.value as Map);
        return ClassSchedule.fromMap(scheduleData, entry.key as String);
      }).toList();

      schedules.sort((a, b) => a.timeSlot.compareTo(b.timeSlot));
      return schedules;
    });
  }

  // ── Availability ──────────────────────────────────────────────────────────

  /// Returns `true` when [timeSlot] is free for the given [teacherId] AND
  /// [classroom] on the given [days], and does not overlap the break.
  ///
  /// A slot is blocked when:
  ///   • the same teacher is already in it on any overlapping day, OR
  ///   • the same classroom is already occupied in it on any overlapping day.
  ///
  /// Two different teachers in two different classrooms CAN share a slot.
  Future<bool> isTimeSlotAvailable(
      String       timeSlot,
      List<String> days,
      String       teacherId,
      String       classroom,
      ) async {
    if (_slotOverlapsBreak(timeSlot)) return false;

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

        // Block if same teacher on overlapping days
        if (existing.teacherId == teacherId) return false;

        // Block if same classroom on overlapping days
        if (existing.classroom == classroom) return false;
      }

      return true;
    } catch (e) {
      throw Exception('Error checking availability: $e');
    }
  }

  /// Returns all valid slots (11 AM–7 PM, break excluded) that are free for
  /// [teacherId] and [classroom] on the days implied by [pattern].
  Future<List<String>> getAvailableTimeSlots(
      SchedulePattern pattern,
      String          teacherId,
      String          classroom,
      ) async {
    final allSlots = _generateTimeSlots();
    final days     = ClassSchedule.getDaysForPattern(pattern);

    final List<String> available = [];
    for (final slot in allSlots) {
      if (await isTimeSlotAvailable(slot, days, teacherId, classroom)) {
        available.add(slot);
      }
    }
    return available;
  }

  // ── Time-slot generation ──────────────────────────────────────────────────

  /// Generates 90-minute slots from 11:00 AM to 7:00 PM,
  /// skipping any slot that would overlap the 2:00–2:30 PM break.
  ///
  /// Resulting slots:
  ///   11:00 AM – 12:30 PM
  ///   12:30 PM –  2:00 PM
  ///    2:30 PM –  4:00 PM
  ///    4:00 PM –  5:30 PM
  ///    5:30 PM –  7:00 PM
  List<String> _generateTimeSlots() {
    final List<String> slots = [];
    int current = _dayStartMinutes;

    while (current < _dayEndMinutes) {
      final end = current + _slotDuration;

      // Advance past the break if we've landed inside it.
      if (current >= _breakStartMinutes && current < _breakEndMinutes) {
        current = _breakEndMinutes;
        continue;
      }

      // If this slot would run into the break, skip to after the break.
      if (current < _breakStartMinutes && end > _breakStartMinutes) {
        current = _breakEndMinutes;
        continue;
      }

      if (end <= _dayEndMinutes) {
        slots.add('${_minutesToTime(current)}-${_minutesToTime(end)}');
        current = end;
      } else {
        break;
      }
    }

    return slots;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns `true` if [timeSlot] (formatted as "H:MM AM-H:MM PM") starts
  /// inside the 2:00–2:30 PM break window.
  bool _slotOverlapsBreak(String timeSlot) {
    try {
      final start = timeSlot.split('-').first.trim();
      final startMinutes = _timeStringToMinutes(start);
      return startMinutes >= _breakStartMinutes &&
          startMinutes < _breakEndMinutes;
    } catch (_) {
      return false; // Malformed slot string — don't block it here.
    }
  }

  /// Converts a time string like "2:00 PM" to total minutes from midnight.
  int _timeStringToMinutes(String time) {
    final parts   = time.trim().split(' ');        // ["2:00", "PM"]
    final hm      = parts[0].split(':');           // ["2", "00"]
    final isPM    = parts[1].toUpperCase() == 'PM';
    int hour      = int.parse(hm[0]);
    final minute  = int.parse(hm[1]);

    if (isPM && hour != 12) hour += 12;
    if (!isPM && hour == 12) hour = 0;

    return hour * 60 + minute;
  }

  /// Converts total minutes from midnight to a display string like "2:30 PM".
  String _minutesToTime(int totalMinutes) {
    final hour   = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;
    return _formatTime(hour, minute);
  }

  String _formatTime(int hour, int minute) {
    final period      = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteSchedule(String id) async {
    try {
      await _database.child(_collection).child(id).remove();
    } catch (e) {
      throw Exception('Error deleting schedule: $e');
    }
  }
}