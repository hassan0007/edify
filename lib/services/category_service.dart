// services/category_service.dart

import 'package:firebase_database/firebase_database.dart';
import '../models/category.dart';

class CategoryService {
  final DatabaseReference _database  = FirebaseDatabase.instance.ref();
  final String            _collection = 'categories';

  DatabaseReference get _ref => _database.child(_collection);

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<List<ScheduleCategory>> getCategories() {
    return _ref.onValue.map((event) => _parse(event.snapshot.value));
  }

  // ── One-shot ──────────────────────────────────────────────────────────────

  Future<List<ScheduleCategory>> getCategoriesOnce() async {
    final snap = await _ref.get();
    return _parse(snap.value);
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<String> addCategory(ScheduleCategory cat) async {
    try {
      final newRef = _ref.push();
      await newRef.set(cat.toMap());
      return newRef.key!;
    } catch (e) {
      throw Exception('Error adding category: $e');
    }
  }

  Future<void> updateCategory(ScheduleCategory cat) async {
    try {
      await _ref.child(cat.id).update(cat.toMap());
    } catch (e) {
      throw Exception('Error updating category: $e');
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _ref.child(id).remove();
    } catch (e) {
      throw Exception('Error deleting category: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<bool> categoryExists(String name) async {
    final snap = await _ref.get();
    if (!snap.exists || snap.value == null) return false;
    final data = snap.value as Map<dynamic, dynamic>;
    return data.values.any((v) {
      final map = Map<String, dynamic>.from(v as Map);
      return (map['name'] as String?)?.toLowerCase() == name.toLowerCase();
    });
  }

  List<ScheduleCategory> _parse(Object? raw) {
    if (raw == null) return [];
    final data = raw as Map<dynamic, dynamic>;
    final categories = data.entries.map((entry) {
      final map = Map<String, dynamic>.from(entry.value as Map);
      return ScheduleCategory.fromMap(entry.key as String, map);
    }).toList();

    // Sort by createdAt ascending
    categories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return categories;
  }
}