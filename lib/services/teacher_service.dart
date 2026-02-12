import 'package:firebase_database/firebase_database.dart';
import '../models/teacher.dart';

class TeacherService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String _collection = 'teachers';

  // Add a new teacher
  Future<String> addTeacher(Teacher teacher) async {
    try {
      DatabaseReference newRef = _database.child(_collection).push();
      await newRef.set(teacher.toMap());
      return newRef.key!;
    } catch (e) {
      throw Exception('Error adding teacher: $e');
    }
  }

  // Get all teachers
  Stream<List<Teacher>> getTeachers() {
    return _database
        .child(_collection)
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      
      if (data == null) return <Teacher>[];
      
      final teachers = data.entries.map((entry) {
        final teacherData = Map<String, dynamic>.from(entry.value as Map);
        return Teacher.fromMap(teacherData, entry.key as String);
      }).toList();
      
      // Sort by name
      teachers.sort((a, b) => a.name.compareTo(b.name));
      
      return teachers;
    });
  }

  // Get a single teacher by ID
  Future<Teacher?> getTeacherById(String id) async {
    try {
      DatabaseEvent event = await _database.child(_collection).child(id).once();
      
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        return Teacher.fromMap(data, id);
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching teacher: $e');
    }
  }

  // Update teacher
  Future<void> updateTeacher(Teacher teacher) async {
    try {
      await _database.child(_collection).child(teacher.id).update(teacher.toMap());
    } catch (e) {
      throw Exception('Error updating teacher: $e');
    }
  }

  // Delete teacher
  Future<void> deleteTeacher(String id) async {
    try {
      await _database.child(_collection).child(id).remove();
    } catch (e) {
      throw Exception('Error deleting teacher: $e');
    }
  }
}
