import 'package:firebase_database/firebase_database.dart';
import '../models/class_schedule.dart';

class ScheduleService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String _collection = 'schedules';

  // Add a new class schedule
  Future<String> addSchedule(ClassSchedule schedule) async {
    try {
      DatabaseReference newRef = _database.child(_collection).push();
      await newRef.set(schedule.toMap());
      return newRef.key!;
    } catch (e) {
      throw Exception('Error adding schedule: $e');
    }
  }

  // Get all schedules
  Stream<List<ClassSchedule>> getSchedules() {
    return _database
        .child(_collection)
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      
      if (data == null) return <ClassSchedule>[];
      
      final schedules = data.entries.map((entry) {
        final scheduleData = Map<String, dynamic>.from(entry.value as Map);
        return ClassSchedule.fromMap(scheduleData, entry.key as String);
      }).toList();
      
      // Sort by time slot
      schedules.sort((a, b) => a.timeSlot.compareTo(b.timeSlot));
      
      return schedules;
    });
  }

  // Get schedules for a specific teacher
  Stream<List<ClassSchedule>> getSchedulesByTeacher(String teacherId) {
    return _database
        .child(_collection)
        .orderByChild('teacherId')
        .equalTo(teacherId)
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      
      if (data == null) return <ClassSchedule>[];
      
      final schedules = data.entries.map((entry) {
        final scheduleData = Map<String, dynamic>.from(entry.value as Map);
        return ClassSchedule.fromMap(scheduleData, entry.key as String);
      }).toList();
      
      schedules.sort((a, b) => a.timeSlot.compareTo(b.timeSlot));
      
      return schedules;
    });
  }

  // Check if a time slot is available for specific days
  Future<bool> isTimeSlotAvailable(String timeSlot, List<String> days) async {
    try {
      DatabaseEvent event = await _database
          .child(_collection)
          .orderByChild('timeSlot')
          .equalTo(timeSlot)
          .once();

      if (event.snapshot.value == null) {
        return true; // No schedules for this time slot
      }

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      
      for (var entry in data.entries) {
        final scheduleData = Map<String, dynamic>.from(entry.value as Map);
        ClassSchedule existingSchedule = ClassSchedule.fromMap(scheduleData, entry.key as String);
        
        // Check if there's any day overlap
        bool hasOverlap = existingSchedule.days.any((day) => days.contains(day));
        if (hasOverlap) {
          return false;
        }
      }
      return true;
    } catch (e) {
      throw Exception('Error checking availability: $e');
    }
  }

  // Get available time slots for a pattern
  Future<List<String>> getAvailableTimeSlots(SchedulePattern pattern) async {
    List<String> allTimeSlots = _generateTimeSlots();
    List<String> days = ClassSchedule.getDaysForPattern(pattern);
    List<String> availableSlots = [];

    for (String slot in allTimeSlots) {
      bool isAvailable = await isTimeSlotAvailable(slot, days);
      if (isAvailable) {
        availableSlots.add(slot);
      }
    }

    return availableSlots;
  }

  // Generate time slots (1.5 hours each, from 8:00 AM to 8:00 PM)
  List<String> _generateTimeSlots() {
    List<String> slots = [];
    int startHour = 8;
    int endHour = 20;

    for (int hour = startHour; hour < endHour; hour++) {
      for (int minute = 0; minute < 60; minute += 90) {
        if (hour + (minute + 90) / 60 <= endHour) {
          String startTime = _formatTime(hour, minute);
          int endMinute = (minute + 90) % 60;
          int endHourAdjusted = hour + (minute + 90) ~/ 60;
          String endTime = _formatTime(endHourAdjusted, endMinute);
          slots.add('$startTime-$endTime');
        }
      }
    }

    return slots;
  }

  String _formatTime(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  // Delete schedule
  Future<void> deleteSchedule(String id) async {
    try {
      await _database.child(_collection).child(id).remove();
    } catch (e) {
      throw Exception('Error deleting schedule: $e');
    }
  }
}
