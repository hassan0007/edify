// services/teacher_service.dart

import 'package:firebase_database/firebase_database.dart';
import '../models/teacher.dart';

class TeacherService {
  final DatabaseReference _database   = FirebaseDatabase.instance.ref();
  final String            _collection = 'teachers';

  DatabaseReference get _ref => _database.child(_collection);

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<String> addTeacher(Teacher teacher) async {
    try {
      final newRef = _ref.push();
      await newRef.set(teacher.toMap());
      return newRef.key!;
    } catch (e) {
      throw Exception('Error adding teacher: $e');
    }
  }

  Future<void> updateTeacher(Teacher teacher) async {
    try {
      await _ref.child(teacher.id).update(teacher.toMap());
    } catch (e) {
      throw Exception('Error updating teacher: $e');
    }
  }

  Future<void> deleteTeacher(String id) async {
    try {
      await _ref.child(id).remove();
    } catch (e) {
      throw Exception('Error deleting teacher: $e');
    }
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  Stream<List<Teacher>> getTeachers() {
    return _ref.onValue.map((event) => _parse(event.snapshot.value));
  }

  Future<Teacher?> getTeacherById(String id) async {
    try {
      final snap = await _ref.child(id).get();
      if (!snap.exists || snap.value == null) return null;
      final map = Map<String, dynamic>.from(snap.value as Map);
      return Teacher.fromMap(map, id);
    } catch (e) {
      throw Exception('Error fetching teacher: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<Teacher> _parse(Object? raw) {
    if (raw == null) return [];
    final data = raw as Map<dynamic, dynamic>;
    final teachers = data.entries.map((entry) {
      final map = Map<String, dynamic>.from(entry.value as Map);
      return Teacher.fromMap(map, entry.key as String);
    }).toList();
    teachers.sort((a, b) => a.name.compareTo(b.name));
    return teachers;
  }
}