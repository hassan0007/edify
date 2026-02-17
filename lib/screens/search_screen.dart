import 'package:flutter/material.dart';
import '../models/teacher.dart';
import '../models/class_schedule.dart';
import '../services/teacher_service.dart';
import '../services/schedule_service.dart';

class TeacherSearchScreen extends StatefulWidget {
  const TeacherSearchScreen({Key? key}) : super(key: key);

  @override
  State<TeacherSearchScreen> createState() => _TeacherSearchScreenState();
}

class _TeacherSearchScreenState extends State<TeacherSearchScreen> {
  final TeacherService _teacherService = TeacherService();
  final ScheduleService _scheduleService = ScheduleService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  Teacher? _selectedTeacher;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.white,
            Colors.purple.shade50,
          ],
        ),
      ),
      child: Column(
        children: [
          // Header Section
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_search,
                      size: 32,
                      color: Colors.indigo.shade700,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Teacher Search',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade900,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Search for a teacher to view their complete class schedule',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Search Section
          Container(
            padding: EdgeInsets.all(24),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.indigo.shade400, size: 28),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Type teacher name...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                      ),
                      style: TextStyle(fontSize: 16),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                          _selectedTeacher = null;
                        });
                      },
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey.shade400),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _selectedTeacher = null;
                        });
                      },
                    ),
                ],
              ),
            ),
          ),

          // Results Section
          Expanded(
            child: _searchQuery.isEmpty
                ? _buildEmptyState()
                : StreamBuilder<List<Teacher>>(
              stream: _teacherService.getTeachers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                final allTeachers = snapshot.data ?? [];
                final filteredTeachers = allTeachers
                    .where((teacher) =>
                    teacher.name.toLowerCase().contains(_searchQuery))
                    .toList();

                if (filteredTeachers.isEmpty) {
                  return _buildNoResultsState();
                }

                return _buildSearchResults(filteredTeachers);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16),
          Text(
            'Search for a Teacher',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Enter a teacher\'s name in the search box above',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16),
          Text(
            'No Teachers Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'No teachers match "$_searchQuery"',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
          SizedBox(height: 16),
          Text(
            'Error Loading Teachers',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(List<Teacher> teachers) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Teachers List
          Text(
            'Teachers (${teachers.length})',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade900,
            ),
          ),
          SizedBox(height: 16),
          ...teachers.map((teacher) => _buildTeacherCard(teacher)),
          SizedBox(height: 24),

          // Selected Teacher's Schedule
          if (_selectedTeacher != null) ...[
            Divider(height: 48),
            _buildTeacherSchedule(_selectedTeacher!),
            SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildTeacherCard(Teacher teacher) {
    final isSelected = _selectedTeacher?.id == teacher.id;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
          colors: [Colors.indigo.shade400, Colors.indigo.shade600],
        )
            : null,
        color: isSelected ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? Colors.indigo.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: isSelected ? 12 : 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedTeacher = isSelected ? null : teacher;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person,
                    size: 32,
                    color: isSelected ? Colors.white : Colors.indigo.shade600,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 14,
                            color: isSelected
                                ? Colors.white.withOpacity(0.8)
                                : Colors.grey.shade500,
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              teacher.email,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? Colors.white.withOpacity(0.9)
                                    : Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: isSelected
                                ? Colors.white.withOpacity(0.8)
                                : Colors.grey.shade500,
                          ),
                          SizedBox(width: 4),
                          Text(
                            teacher.phone,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected
                                  ? Colors.white.withOpacity(0.9)
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected ? Icons.expand_less : Icons.expand_more,
                  color: isSelected ? Colors.white : Colors.grey.shade400,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherSchedule(Teacher teacher) {
    return StreamBuilder<List<ClassSchedule>>(
      stream: _scheduleService.getSchedules(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final allSchedules = snapshot.data ?? [];
        final teacherSchedules = allSchedules
            .where((schedule) => schedule.teacherName == teacher.name)
            .toList();

        if (teacherSchedules.isEmpty) {
          return _buildNoClassesState(teacher.name);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.class_,
                  size: 24,
                  color: Colors.indigo.shade700,
                ),
                SizedBox(width: 12),
                Text(
                  '${teacher.name}\'s Classes',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade900,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...teacherSchedules.map((schedule) => _buildClassCard(schedule)),
          ],
        );
      },
    );
  }

  Widget _buildNoClassesState(String teacherName) {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              'No Classes Assigned',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '$teacherName has no scheduled classes',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassCard(ClassSchedule schedule) {
    // Gradient colors for classes
    List<List<Color>> gradients = [
      [Colors.indigo.shade400, Colors.indigo.shade600],
      [Colors.indigo.shade400, Colors.indigo.shade600],
      [Colors.indigo.shade400, Colors.indigo.shade600],
      [Colors.indigo.shade400, Colors.indigo.shade600],
    ];

    List<Color> gradient = gradients[schedule.hashCode % gradients.length];

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Batch Name
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.class_, color: Colors.white, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    schedule.batchName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Time Slot
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.white.withOpacity(0.9), size: 18),
                SizedBox(width: 8),
                Text(
                  schedule.timeSlot,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Classroom
            Row(
              children: [
                Icon(Icons.meeting_room, color: Colors.white.withOpacity(0.9), size: 18),
                SizedBox(width: 8),
                Text(
                  schedule.classroom,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Days
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: schedule.days.map((day) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    day,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}