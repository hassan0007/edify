import 'package:flutter/material.dart';
import '../models/teacher.dart';
import '../models/class_schedule.dart';
import '../services/teacher_service.dart';
import '../services/schedule_service.dart';
import '../services/pdf_service.dart';
import '../widgets/add_teacher_dialog.dart';
import '../widgets/add_class_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TeacherService _teacherService = TeacherService();
  final ScheduleService _scheduleService = ScheduleService();
  final PdfService _pdfService = PdfService();

  String? _selectedClassroomFilter;
  List<String> _timeSlots = [];
  List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  @override
  void initState() {
    super.initState();
    _timeSlots = _generateTimeSlots();
  }

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
    String period = hour >= 12 ? 'PM' : 'AM';
    int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString()}:${minute.toString().padLeft(2, '0')} $period';
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school, size: 28),
            SizedBox(width: 12),
            Text('Edify College of IT'),
          ],
        ),
        actions: [
          // Classroom Filter
          StreamBuilder<List<ClassSchedule>>(
            stream: _scheduleService.getSchedules(),
            builder: (context, snapshot) {
              final schedules = snapshot.data ?? [];
              final classrooms = schedules
                  .map((s) => s.classroom)
                  .where((c) => c.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();

              return Container(
                width: 200,
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Filter by Classroom',
                    prefixIcon: Icon(Icons.meeting_room, color: Colors.white),
                    labelStyle: TextStyle(color: Colors.white),
                    floatingLabelStyle: TextStyle(color: Colors.white),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white, width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  dropdownColor: Theme.of(context).primaryColor,
                  style: TextStyle(color: Colors.white),
                  value: _selectedClassroomFilter,
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Classrooms', style: TextStyle(color: Colors.white)),
                    ),
                    ...classrooms.map((classroom) => DropdownMenuItem<String>(
                      value: classroom,
                      child: Text(classroom, style: TextStyle(color: Colors.white)),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedClassroomFilter = value;
                    });
                  },
                ),
              );
            },
          ),

          // Add Teacher Button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: ElevatedButton.icon(
              onPressed: () => _showAddTeacherDialog(),
              icon: Icon(Icons.person_add),
              label: Text('Add Teacher'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).primaryColor,
              ),
            ),
          ),

          // Export to PDF Button
          StreamBuilder<List<ClassSchedule>>(
            stream: _scheduleService.getSchedules(),
            builder: (context, snapshot) {
              final hasSchedules = snapshot.hasData && snapshot.data!.isNotEmpty;
              return Padding(
                padding: EdgeInsets.only(right: 16),
                child: ElevatedButton.icon(
                  onPressed: hasSchedules
                      ? () => _exportToPdf(snapshot.data!)
                      : null,
                  icon: Icon(Icons.picture_as_pdf),
                  label: Text('Export PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).primaryColor,
                  ),
                ),
              );
            },
          ),
        ],
      ),

      body: Container(
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
        child: StreamBuilder<List<ClassSchedule>>(
          stream: _scheduleService.getSchedules(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      'Error loading schedules',
                      style: TextStyle(fontSize: 18, color: Colors.red),
                    ),
                    SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            final allSchedules = snapshot.data ?? [];
            final filteredSchedules = _applyFilters(allSchedules);

            return _buildStylishScheduleTable(filteredSchedules);
          },
        ),
      ),

      // Floating Action Button - Add New Class
      floatingActionButton: StreamBuilder<List<Teacher>>(
        stream: _teacherService.getTeachers(),
        builder: (context, snapshot) {
          final teachers = snapshot.data ?? [];

          return FloatingActionButton.extended(
            onPressed: teachers.isEmpty
                ? () => _showNoTeachersDialog()
                : () => _showAddClassDialog(teachers),
            icon: Icon(Icons.add),
            label: Text('Add New Class'),
            elevation: 8,
          );
        },
      ),
    );
  }

  List<ClassSchedule> _applyFilters(List<ClassSchedule> schedules) {
    if (_selectedClassroomFilter == null) {
      return schedules;
    }
    return schedules.where((schedule) => schedule.classroom == _selectedClassroomFilter).toList();
  }

  Widget _buildStylishScheduleTable(List<ClassSchedule> schedules) {
    return Container(
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
        children: [
          // Table Header Section
          Container(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade600, Colors.blue.shade500],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  'Class Timetable',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Spacer(),
                if (_selectedClassroomFilter != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.meeting_room, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          _selectedClassroomFilter!,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                        SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedClassroomFilter = null;
                            });
                          },
                          child: Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Scrollable Table
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Container(
                  padding: EdgeInsets.all(16),
                  child: Table(
                    border: TableBorder(
                      horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                      verticalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                    ),
                    defaultColumnWidth: FixedColumnWidth(190),

                    children: [
                      // Header Row with Days
                      TableRow(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade100, Colors.purple.shade100],
                          ),
                        ),
                        children: [
                          _buildModernHeaderCell('Time', isTime: true),
                          ..._days.map((day) => _buildModernHeaderCell(day)),
                        ],
                      ),
                      // Time Slot Rows
                      ..._timeSlots.asMap().entries.map((entry) {
                        int index = entry.key;
                        String timeSlot = entry.value;
                        bool isEvenRow = index % 2 == 0;

                        return TableRow(
                          decoration: BoxDecoration(
                            color: isEvenRow ? Colors.grey.shade50 : Colors.white,
                          ),
                          children: [
                            _buildModernTimeCell(timeSlot),
                            ..._days.map((day) => _buildModernScheduleCell(schedules, timeSlot, day)),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHeaderCell(String text, {bool isTime = false}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isTime)
            Icon(
              Icons.calendar_today,
              size: 16,
              color: Colors.indigo.shade700,
            ),
          if (!isTime) SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isTime ? Colors.purple.shade700 : Colors.indigo.shade700,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModernTimeCell(String timeSlot) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade50, Colors.purple.shade50],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.access_time, size: 16, color: Colors.indigo.shade600),
          SizedBox(width: 8),
          Text(
            timeSlot,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.indigo.shade800,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModernScheduleCell(List<ClassSchedule> schedules, String timeSlot, String day) {
    final classesAtSlot = schedules.where((s) =>
    s.timeSlot == timeSlot && s.days.contains(day)
    ).toList();

    return Container(
      padding: EdgeInsets.all(12),
      constraints: BoxConstraints(minHeight: 100),
      child: classesAtSlot.isEmpty
          ? Center(
        child: Icon(
          Icons.remove_circle_outline,
          color: Colors.grey.shade300,
          size: 24,
        ),
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: classesAtSlot.asMap().entries.map((entry) {
          int index = entry.key;
          ClassSchedule schedule = entry.value;

          // Gradient colors for each class
          List<List<Color>> gradients = [
            [Colors.blue.shade400, Colors.blue.shade600],
            [Colors.purple.shade400, Colors.purple.shade600],
            [Colors.teal.shade400, Colors.teal.shade600],
            [Colors.orange.shade400, Colors.orange.shade600],
          ];

          List<Color> gradient = gradients[index % gradients.length];

          return Container(
            margin: EdgeInsets.only(bottom: classesAtSlot.length > 1 ? 8 : 0),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Batch Name
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.class_, size: 14, color: Colors.white),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        schedule.batchName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),

                // Teacher Name
                Row(
                  children: [
                    Icon(Icons.person, size: 12, color: Colors.white.withOpacity(0.9)),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        schedule.teacherName,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.95),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),

                // Classroom
                Row(
                  children: [
                    Icon(Icons.meeting_room, size: 12, color: Colors.white.withOpacity(0.9)),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        schedule.classroom,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.95),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),

                // Delete Button
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () => _deleteSchedule(schedule),
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showAddTeacherDialog() async {
    final result = await showDialog(
      context: context,
      builder: (context) => AddTeacherDialog(),
    );
  }

  void _showAddClassDialog(List<Teacher> teachers) async {
    final result = await showDialog(
      context: context,
      builder: (context) => AddClassDialog(teachers: teachers),
    );
  }

  void _showNoTeachersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Text('No Teachers Available'),
          ],
        ),
        content: Text(
          'Please add at least one teacher before creating a class schedule.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showAddTeacherDialog();
            },
            child: Text('Add Teacher'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToPdf(List<ClassSchedule> schedules) async {
    try {
      await _pdfService.generateSchedulePdf(schedules);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF generated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteSchedule(ClassSchedule schedule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Text('Delete Class'),
          ],
        ),
        content: Text('Are you sure you want to delete "${schedule.batchName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _scheduleService.deleteSchedule(schedule.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Class deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting class: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}