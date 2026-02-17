import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/class_schedule.dart';
import '../services/teacher_service.dart';
import '../services/schedule_service.dart';
import '../services/pdf_service.dart';
import '../widgets/add_teacher_dialog.dart';
import '../widgets/add_classroom_dialog.dart';
import '../widgets/add_class_dialog.dart';

class HomeScreen extends StatefulWidget {
  /// Optional shared stream from AppShell. When provided, HomeScreen reuses
  /// it instead of creating its own Firebase subscription.
  final Stream<List<ClassSchedule>>? schedulesStream;

  const HomeScreen({Key? key, this.schedulesStream}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TeacherService   _teacherService   = TeacherService();
  final ScheduleService  _scheduleService  = ScheduleService();
  final PdfService       _pdfService       = PdfService();

  // ── Cached stream — ONE subscription for the whole screen ────────────────
  late final Stream<List<ClassSchedule>> _schedulesStream;

  // Latest snapshot held in state so filters, AppBar buttons and the table
  // all read the SAME data without triggering extra Firebase reads.
  List<ClassSchedule> _allSchedules = [];

  String? _selectedClassroomFilter;
  String? _selectedTeacherFilter;
  String? _selectedBatchFilter;

  static const String _breakSlotMarker = 'BREAK|2:00 PM-2:30 PM';
  late final List<String> _timeSlots;
  static const List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  @override
  void initState() {
    super.initState();
    _timeSlots = _generateTimeSlots();
    // Reuse the stream passed in from AppShell when available; otherwise create
    // a new one. This prevents a duplicate Firebase subscription.
    _schedulesStream = widget.schedulesStream ??
        _scheduleService.getSchedules().asBroadcastStream();
  }

  // ── Time-slot generation ──────────────────────────────────────────────────

  List<String> _generateTimeSlots() {
    const int breakStart = 14 * 60;
    const int breakEnd   = 14 * 60 + 30;
    const int dayEnd     = 19 * 60;
    final List<String> slots = [];
    int cur = 11 * 60;

    while (cur < dayEnd) {
      final end = cur + 90;
      if (cur <= breakStart && end > breakStart) {
        if (cur < breakStart) slots.add('${_fmt(cur)}-${_fmt(breakStart)}');
        slots.add(_breakSlotMarker);
        cur = breakEnd;
        continue;
      }
      if (end <= dayEnd) {
        slots.add('${_fmt(cur)}-${_fmt(end)}');
        cur = end;
      } else { break; }
    }
    return slots;
  }

  String _fmt(int m) {
    final h = m ~/ 60, min = m % 60;
    final p = h >= 12 ? 'PM' : 'AM';
    final dh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$dh:${min.toString().padLeft(2, '0')} $p';
  }

  bool   _isBreak(String s) => s.startsWith('BREAK|');
  String _breakLabel(String s) => s.replaceFirst('BREAK|', '');

  // ── Filters ───────────────────────────────────────────────────────────────

  bool get _hasActiveFilters =>
      _selectedClassroomFilter != null ||
          _selectedTeacherFilter   != null ||
          _selectedBatchFilter     != null;

  List<ClassSchedule> _applyFilters(List<ClassSchedule> src) {
    var f = src;
    if (_selectedClassroomFilter != null)
      f = f.where((s) => s.classroom  == _selectedClassroomFilter).toList();
    if (_selectedTeacherFilter != null)
      f = f.where((s) => s.teacherName == _selectedTeacherFilter).toList();
    if (_selectedBatchFilter != null)
      f = f.where((s) => s.batchName   == _selectedBatchFilter).toList();
    return f;
  }

  // Filter dialog reads from the cached _allSchedules — NO extra Firebase call
  void _showFilterDialog() {
    final classrooms = _allSchedules.map((s) => s.classroom)
        .where((c) => c.isNotEmpty).toSet().toList()..sort();
    final teachers = _allSchedules.map((s) => s.teacherName)
        .where((t) => t.isNotEmpty).toSet().toList()..sort();
    final batches = _allSchedules.map((s) => s.batchName)
        .where((b) => b.isNotEmpty).toSet().toList()..sort();

    showDialog(
      context: context,
      builder: (_) => FilterDialog(
        classrooms: classrooms, teachers: teachers, batches: batches,
        selectedClassroom: _selectedClassroomFilter,
        selectedTeacher:   _selectedTeacherFilter,
        selectedBatch:     _selectedBatchFilter,
        onApply: (room, teacher, batch) => setState(() {
          _selectedClassroomFilter = room;
          _selectedTeacherFilter   = teacher;
          _selectedBatchFilter     = batch;
        }),
        onClear: () => setState(() {
          _selectedClassroomFilter = null;
          _selectedTeacherFilter   = null;
          _selectedBatchFilter     = null;
        }),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sw              = MediaQuery.of(context).size.width;
    final showCompactMenu = sw < 796;
    final isMobile        = sw < 768;

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: isMobile ? null : _buildAppBar(showCompactMenu),
      // ONE StreamBuilder at the root; all children read from _allSchedules
      body: StreamBuilder<List<ClassSchedule>>(
        stream: _schedulesStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && _allSchedules.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}',
                style: const TextStyle(color: Colors.red)));
          }
          if (snap.hasData) _allSchedules = snap.data!;

          final filtered = _applyFilters(_allSchedules);
          return _buildTable(filtered);
        },
      ),
    );
  }

  // ── AppBar — reads _allSchedules, no extra stream ─────────────────────────

  AppBar _buildAppBar(bool compact) => AppBar(
    actions: [
      // Filter badge button
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Stack(children: [
          ElevatedButton.icon(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_list),
            label: const Text('Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _hasActiveFilters
                  ? Colors.white : Colors.white.withOpacity(0.9),
              foregroundColor: Theme.of(context).primaryColor,
            ),
          ),
          if (_hasActiveFilters)
            Positioned(right: 0, top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.orange, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  '${[_selectedClassroomFilter, _selectedTeacherFilter,
                    _selectedBatchFilter].where((f) => f != null).length}',
                  style: const TextStyle(color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ]),
      ),

      if (!compact) ...[
        _appBarBtn(Icons.person_add,  'Teacher',    _showAddTeacherDialog),
        _appBarBtn(Icons.meeting_room,'Classroom',  _showAddClassroomDialog),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: ElevatedButton.icon(
            onPressed: _allSchedules.isNotEmpty
                ? () => _exportToPdf(_allSchedules) : null,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Export PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).primaryColor,
            ),
          ),
        ),
      ],

      if (compact)
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          color: Colors.white,
          onSelected: (v) {
            if (v == 'add_teacher')    _showAddTeacherDialog();
            if (v == 'add_classroom')  _showAddClassroomDialog();
            if (v == 'export_pdf' && _allSchedules.isNotEmpty)
              _exportToPdf(_allSchedules);
          },
          itemBuilder: (_) => [
            _popItem('add_teacher',   Icons.person_add,    'Add Teacher',    true),
            _popItem('add_classroom', Icons.meeting_room,  'Add Classroom',  true),
            _popItem('export_pdf',    Icons.picture_as_pdf,'Export PDF',
                _allSchedules.isNotEmpty),
          ],
        ),
    ],
  );

  Widget _appBarBtn(IconData icon, String label, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      );

  PopupMenuItem<String> _popItem(
      String val, IconData icon, String label, bool enabled) =>
      PopupMenuItem(
        value: val, enabled: enabled,
        child: Row(children: [
          Icon(icon, color: enabled
              ? Theme.of(context).primaryColor : Colors.grey),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(
              color: enabled ? Colors.black : Colors.grey)),
        ]),
      );

  // ── Table ─────────────────────────────────────────────────────────────────

  Widget _buildTable(List<ClassSchedule> schedules) {
    return Container(
      color: Colors.white,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Table(
                border: TableBorder(
                  horizontalInside: BorderSide(color: Colors.grey.shade300),
                  verticalInside:   BorderSide(color: Colors.grey.shade300),
                ),
                columnWidths: {
                  0: const FixedColumnWidth(150),
                  for (int i = 0; i < _timeSlots.length; i++)
                    i + 1: _isBreak(_timeSlots[i])
                        ? const FixedColumnWidth(80)
                        : const FixedColumnWidth(150),
                },
                children: [
                  // Header
                  TableRow(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.blue.shade100, Colors.purple.shade100
                      ]),
                    ),
                    children: [
                      _headerCell('Day', isDay: true),
                      ..._timeSlots.map((s) => _isBreak(s)
                          ? _breakHeaderCell(s) : _headerCell(s, isTimeSlot: true)),
                    ],
                  ),
                  // Day rows
                  ..._days.asMap().entries.map((e) {
                    final isEven = e.key % 2 == 0;
                    return TableRow(
                      decoration: BoxDecoration(
                          color: isEven ? Colors.grey.shade50 : Colors.white),
                      children: [
                        _dayCell(e.value),
                        ..._timeSlots.map((s) => _isBreak(s)
                            ? _breakBodyCell()
                            : _scheduleCell(schedules, s, e.value)),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerCell(String text,
      {bool isDay = false, bool isTimeSlot = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (isTimeSlot) ...[
            Icon(Icons.access_time, size: 14, color: Colors.purple.shade700),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(text,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize:   isTimeSlot ? 10 : 13,
                color: isDay ? Colors.purple.shade700 : Colors.indigo.shade700,
                letterSpacing: 0.4,
              ),
              textAlign: TextAlign.center, maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      );

  Widget _breakHeaderCell(String slot) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
    decoration: BoxDecoration(
      gradient: LinearGradient(
          colors: [Colors.amber.shade200, Colors.orange.shade200]),
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.free_breakfast, size: 16, color: Colors.orange.shade800),
      const SizedBox(height: 4),
      Text('BREAK', style: TextStyle(fontWeight: FontWeight.bold,
          fontSize: 10, color: Colors.orange.shade900, letterSpacing: 0.5),
          textAlign: TextAlign.center),
      Text(_breakLabel(slot),
          style: TextStyle(fontSize: 8, color: Colors.orange.shade800),
          textAlign: TextAlign.center),
    ]),
  );

  Widget _dayCell(String day) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(gradient: LinearGradient(
        colors: [Colors.indigo.shade50, Colors.purple.shade50])),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.calendar_today, size: 14, color: Colors.indigo.shade600),
      const SizedBox(width: 6),
      Expanded(child: Text(day,
          style: TextStyle(fontWeight: FontWeight.w600,
              fontSize: 12, color: Colors.indigo.shade800),
          textAlign: TextAlign.center)),
    ]),
  );

  Widget _breakBodyCell() => Container(
    constraints: const BoxConstraints(minHeight: 70),
    color: Colors.amber.shade50,
    child: CustomPaint(
      painter: _StripePainter(color: Colors.amber.shade100, gap: 8),
      child: Center(child: Icon(Icons.coffee,
          size: 22, color: Colors.orange.shade300)),
    ),
  );

  Widget _scheduleCell(
      List<ClassSchedule> schedules, String slot, String day) {
    final classes = schedules
        .where((s) => s.timeSlot == slot && s.days.contains(day))
        .toList();

    return Container(
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minHeight: 70),
      child: classes.isEmpty
          ? Center(child: Icon(Icons.remove_circle_outline,
          color: Colors.grey.shade300, size: 20))
          : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: classes.asMap().entries.map((e) {
          const gradients = [
            [Color(0xFF42A5F5), Color(0xFF1E88E5)],
            [Color(0xFFAB47BC), Color(0xFF8E24AA)],
            [Color(0xFF26A69A), Color(0xFF00897B)],
            [Color(0xFFFFA726), Color(0xFFFB8C00)],
          ];
          final g = gradients[e.key % gradients.length];
          final s = e.value;
          return Container(
            margin: EdgeInsets.only(
                bottom: classes.length > 1 ? 5 : 0),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: g),
              borderRadius: BorderRadius.circular(7),
              boxShadow: [BoxShadow(color: g[0].withOpacity(0.2),
                  blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardRow(Icons.class_,       s.batchName,   bold: true),
                const SizedBox(height: 4),
                _cardRow(Icons.person,        s.teacherName),
                const SizedBox(height: 3),
                _cardRow(Icons.meeting_room,  s.classroom),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () => _deleteSchedule(s),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3.5),
                      ),
                      child: const Icon(Icons.delete_outline,
                          size: 14, color: Colors.white),
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

  Widget _cardRow(IconData icon, String text, {bool bold = false}) => Row(
    children: [
      Icon(icon, size: bold ? 12 : 10,
          color: Colors.white.withOpacity(bold ? 1.0 : 0.9)),
      const SizedBox(width: 3),
      Expanded(child: Text(text,
          style: TextStyle(fontSize: bold ? 11 : 9,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: Colors.white.withOpacity(bold ? 1.0 : 0.95)),
          overflow: TextOverflow.ellipsis, maxLines: 1)),
    ],
  );

  // ── Actions ───────────────────────────────────────────────────────────────

  void _showAddTeacherDialog() =>
      showDialog(context: context, builder: (_) => const AddTeacherDialog());

  void _showAddClassroomDialog() =>
      showDialog(context: context, builder: (_) => const AddClassroomDialog());

  Future<void> _showAddClassDialog() async {
    final teachers = await _teacherService.getTeachers().first;
    if (!mounted) return;
    if (teachers.isEmpty) {
      showDialog(context: context, builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning, color: Colors.orange),
          SizedBox(width: 12), Text('No Teachers'),
        ]),
        content: const Text('Add at least one teacher before scheduling a class.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('OK'))],
      ));
      return;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AddClassDialog(
        teachers:          teachers,
        existingSchedules: _allSchedules,
      ),
    );
  }

  Future<void> _exportToPdf(List<ClassSchedule> schedules) async {
    try {
      await _pdfService.generateSchedulePdf(schedules);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PDF generated successfully'),
          backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteSchedule(ClassSchedule schedule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.warning, color: Colors.orange),
          const SizedBox(width: 12),
          const Text('Delete Class'),
        ]),
        content: Text('Delete "${schedule.batchName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _scheduleService.deleteSchedule(schedule.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Class deleted'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }
}

// ── Stripe painter ────────────────────────────────────────────────────────────

class _StripePainter extends CustomPainter {
  final Color color;
  final double gap;
  const _StripePainter({required this.color, required this.gap});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (double d = 0; d < size.width + size.height; d += gap) {
      canvas.drawLine(
        Offset(d < size.height ? 0 : d - size.height,
            d < size.height ? d : size.height),
        Offset(d < size.width  ? d : size.width,
            d < size.width  ? 0 : d - size.width),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) =>
      old.color != color || old.gap != gap;
}

// ── Filter Dialog ─────────────────────────────────────────────────────────────

class FilterDialog extends StatefulWidget {
  final List<String> classrooms, teachers, batches;
  final String? selectedClassroom, selectedTeacher, selectedBatch;
  final Function(String?, String?, String?) onApply;
  final VoidCallback onClear;

  const FilterDialog({
    Key? key,
    required this.classrooms, required this.teachers, required this.batches,
    this.selectedClassroom, this.selectedTeacher, this.selectedBatch,
    required this.onApply, required this.onClear,
  }) : super(key: key);

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  String? _room, _teacher, _batch;

  @override
  void initState() {
    super.initState();
    _room    = widget.selectedClassroom;
    _teacher = widget.selectedTeacher;
    _batch   = widget.selectedBatch;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500, padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.purple.shade400]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.filter_list, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Filter Schedule', style: TextStyle(fontSize: 24,
                      fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                  Text('Refine your schedule view',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                ])),
                IconButton(onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close), color: Colors.grey.shade600),
              ]),
              const SizedBox(height: 24), const Divider(), const SizedBox(height: 24),

              _dropdown('Filter by Teacher',   Icons.person,       Colors.blue,
                  widget.teachers,   _teacher, (v) => setState(() => _teacher = v)),
              const SizedBox(height: 16),
              _dropdown('Filter by Classroom', Icons.meeting_room,  Colors.green,
                  widget.classrooms, _room,    (v) => setState(() => _room = v)),
              const SizedBox(height: 16),
              _dropdown('Filter by Batch',     Icons.group,         Colors.orange,
                  widget.batches,    _batch,   (v) => setState(() => _batch = v)),
              const SizedBox(height: 24),

              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() { _room = null; _teacher = null; _batch = null; });
                    widget.onClear();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.clear_all), label: const Text('Clear All'),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                ),
                Row(children: [
                  TextButton(onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      widget.onApply(_room, _teacher, _batch);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check), label: const Text('Apply'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ]),
              ]),
            ]),
      ),
    );
  }

  Widget _dropdown(String label, IconData icon, MaterialColor color,
      List<String> items, String? value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText:  label,
        prefixIcon: Icon(icon, color: color.shade600),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: color.shade600, width: 2)),
        filled: true, fillColor: Colors.grey.shade50,
      ),
      value: value,
      items: [
        DropdownMenuItem<String>(value: null,
            child: Text('All ${label.split(' ').last}s')),
        ...items.map((i) => DropdownMenuItem<String>(value: i, child: Text(i))),
      ],
      onChanged: onChanged,
    );
  }
}