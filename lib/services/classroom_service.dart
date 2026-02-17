import 'package:firebase_database/firebase_database.dart';
import '../models/classroom.dart';

class ClassroomService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Get reference to classrooms node
  DatabaseReference get _classroomsRef => _database.child('classrooms');

  // Stream of all classrooms (realtime updates)
  Stream<List<Classroom>> getClassrooms() {
    return _classroomsRef.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <Classroom>[];

      final classroomsMap = Map<String, dynamic>.from(data as Map);
      return classroomsMap.entries
          .map((entry) => Classroom.fromMap(
        Map<String, dynamic>.from(entry.value as Map),
        entry.key,
      ))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name)); // Sort alphabetically
    });
  }

  // Add a new classroom
  Future<String> addClassroom(Classroom classroom) async {
    try {
      final newClassroomRef = _classroomsRef.push();
      final classroomWithId = classroom.copyWith(id: newClassroomRef.key!);
      await newClassroomRef.set(classroomWithId.toMap());
      return newClassroomRef.key!;
    } catch (e) {
      throw Exception('Failed to add classroom: $e');
    }
  }

  // Update an existing classroom
  Future<void> updateClassroom(Classroom classroom) async {
    try {
      await _classroomsRef.child(classroom.id).update(classroom.toMap());
    } catch (e) {
      throw Exception('Failed to update classroom: $e');
    }
  }

  // Delete a classroom
  Future<void> deleteClassroom(String classroomId) async {
    try {
      await _classroomsRef.child(classroomId).remove();
    } catch (e) {
      throw Exception('Failed to delete classroom: $e');
    }
  }

  // Get a single classroom by ID
  Future<Classroom?> getClassroomById(String id) async {
    try {
      final snapshot = await _classroomsRef.child(id).get();
      if (snapshot.exists) {
        return Classroom.fromMap(
          Map<String, dynamic>.from(snapshot.value as Map),
          id,
        );
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get classroom: $e');
    }
  }

  // Check if classroom name already exists
  Future<bool> classroomExists(String name) async {
    try {
      final snapshot = await _classroomsRef
          .orderByChild('name')
          .equalTo(name)
          .get();
      return snapshot.exists;
    } catch (e) {
      throw Exception('Failed to check classroom existence: $e');
    }
  }

  // Get classrooms by capacity
  Stream<List<Classroom>> getClassroomsByCapacity(int minCapacity) {
    return getClassrooms().map((classrooms) {
      return classrooms.where((classroom) {
        final capacity = int.tryParse(classroom.capacity) ?? 0;
        return capacity >= minCapacity;
      }).toList();
    });
  }

  // Get classrooms by location
  Stream<List<Classroom>> getClassroomsByLocation(String location) {
    return getClassrooms().map((classrooms) {
      return classrooms
          .where((classroom) =>
          classroom.location.toLowerCase().contains(location.toLowerCase()))
          .toList();
    });
  }
}