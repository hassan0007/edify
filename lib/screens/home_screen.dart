// screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/class_schedule.dart';
import '../models/category.dart';
import '../services/teacher_service.dart';
import '../services/schedule_service.dart';
import '../services/pdf_service.dart';
import '../services/category_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_teacher_dialog.dart';
import '../widgets/add_classroom_dialog.dart';
import '../widgets/add_class_dialog.dart';
import '../widgets/add_category.dart';

class HomeScreen extends StatefulWidget {
  final Stream<List<ClassSchedule>>? schedulesStream;
  const HomeScreen({Key? key, this.schedulesStream}) : super(key: key);

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final TeacherService   _teacherService   = TeacherService();
  final ScheduleService  _scheduleService  = ScheduleService();
  final PdfService       _pdfService       = PdfService();
  final CategoryService  _categoryService  = CategoryService();

  late final Stream<List<ClassSchedule>>    _schedulesStream;
  late final Stream<List<ScheduleCategory>> _categoriesStream;

  List<ClassSchedule>    _allSchedules  = [];
  List<ScheduleCategory> _allCategories = [];

  String?    _selectedClassroomFilter;
  String?    _selectedTeacherFilter;
  String?    _selectedBatchFilter;
  String?    _selectedCategoryFilter; // null = all categories
  ClassType? _selectedClassTypeFilter = ClassType.regular;

  static const String _breakSlotMarker = 'BREAK|2:00 PM-2:30 PM';
  late final List<String> _timeSlots;
  static const List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  @override
  void initState() {
    super.initState();
    _timeSlots       = _generateTimeSlots();
    _schedulesStream = widget.schedulesStream ??
        _scheduleService.getSchedules().asBroadcastStream();
    _categoriesStream = _categoryService.getCategories().asBroadcastStream();
  }

  // ── Time-slot generation (global fallback) ────────────────────────────────

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
      } else {
        break;
      }
    }
    return slots;
  }

  String _fmt(int m) {
    final h = m ~/ 60, min = m % 60;
    final p  = h >= 12 ? 'PM' : 'AM';
    final dh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$dh:${min.toString().padLeft(2, '0')} $p';
  }

  bool   _isBreak(String s) => s.startsWith('BREAK|');
  String _breakLabel(String s) => s.replaceFirst('BREAK|', '');

  // ── Filters ───────────────────────────────────────────────────────────────

  bool get _hasActiveFilters =>
      _selectedClassroomFilter != null ||
          _selectedTeacherFilter   != null ||
          _selectedBatchFilter     != null ||
          _selectedCategoryFilter  != null;

  /// Applies ALL active filters in order:
  ///   1. Class type  (Regular / NAVTTC / All)
  ///   2. Category    (must match selected category name)
  ///   3. Classroom / Teacher / Batch
  List<ClassSchedule> _applyFilters(List<ClassSchedule> src) {
    var f = _selectedClassTypeFilter == null
        ? src.toList()
        : src.where((s) => s.classType == _selectedClassTypeFilter).toList();
    if (_selectedCategoryFilter  != null)
      f = f.where((s) => s.categoryName == _selectedCategoryFilter).toList();
    if (_selectedClassroomFilter != null)
      f = f.where((s) => s.classroom   == _selectedClassroomFilter).toList();
    if (_selectedTeacherFilter   != null)
      f = f.where((s) => s.teacherName == _selectedTeacherFilter).toList();
    if (_selectedBatchFilter     != null)
      f = f.where((s) => s.batchName   == _selectedBatchFilter).toList();
    return f;
  }

  /// Categories that actually contain at least one class of the selected type.
  /// When class type is null (All), all categories are shown.
  List<ScheduleCategory> get _relevantCategories {
    if (_selectedClassTypeFilter == null) return _allCategories;
    final usedNames = _allSchedules
        .where((s) => s.classType == _selectedClassTypeFilter)
        .map((s) => s.categoryName)
        .whereType<String>()
        .toSet();
    return _allCategories
        .where((c) => usedNames.contains(c.name))
        .toList();
  }

  void _showFilterDialog() {
    // Derive filter option lists from schedules that already pass the
    // class-type + category combination so dropdowns stay coherent.
    var typeFiltered = _selectedClassTypeFilter == null
        ? _allSchedules
        : _allSchedules
        .where((s) => s.classType == _selectedClassTypeFilter)
        .toList();
    if (_selectedCategoryFilter != null) {
      typeFiltered = typeFiltered
          .where((s) => s.categoryName == _selectedCategoryFilter)
          .toList();
    }

    final classrooms = typeFiltered.map((s) => s.classroom)
        .where((c) => c.isNotEmpty).toSet().toList()..sort();
    final teachers   = typeFiltered.map((s) => s.teacherName)
        .where((t) => t.isNotEmpty).toSet().toList()..sort();
    final batches    = typeFiltered.map((s) => s.batchName)
        .where((b) => b.isNotEmpty).toSet().toList()..sort();

    AppTheme.showPopup(
      context: context,
      builder: (_) => FilterDialog(
        classrooms:           classrooms,
        teachers:             teachers,
        batches:              batches,
        // Only show categories relevant to the current class-type selection
        categories:           _relevantCategories,
        allCategories:        _allCategories,
        selectedClassroom:    _selectedClassroomFilter,
        selectedTeacher:      _selectedTeacherFilter,
        selectedBatch:        _selectedBatchFilter,
        selectedCategoryName: _selectedCategoryFilter,
        selectedClassType:    _selectedClassTypeFilter,
        allSchedules:         _allSchedules,
        onApply: (room, teacher, batch, categoryName, classType) =>
            setState(() {
              _selectedClassroomFilter = room;
              _selectedTeacherFilter   = teacher;
              _selectedBatchFilter     = batch;
              _selectedCategoryFilter  = categoryName;
              _selectedClassTypeFilter = classType;
            }),
        onClear: () => setState(() {
          _selectedClassroomFilter = null;
          _selectedTeacherFilter   = null;
          _selectedBatchFilter     = null;
          _selectedCategoryFilter  = null;
          _selectedClassTypeFilter = ClassType.regular;
        }),
      ),
    );
  }

  // ── Public API for AppShell ───────────────────────────────────────────────

  int get activeFilterCount => [
    _selectedClassroomFilter,
    _selectedTeacherFilter,
    _selectedBatchFilter,
    _selectedCategoryFilter,
  ].where((f) => f != null).length;

  void setClassTypeFilter(ClassType? type) => setState(() {
    _selectedClassTypeFilter = type;
    _selectedClassroomFilter = null;
    _selectedTeacherFilter   = null;
    _selectedBatchFilter     = null;
    // Reset category only if it doesn't belong to the new type
    if (type != null && _selectedCategoryFilter != null) {
      final stillValid = _allSchedules.any((s) =>
      s.classType == type &&
          s.categoryName == _selectedCategoryFilter);
      if (!stillValid) _selectedCategoryFilter = null;
    }
  });

  void showFilterDialogPublic() => _showFilterDialog();

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sw              = MediaQuery.of(context).size.width;
    final showCompactMenu = sw < 1069;
    final isMobile        = sw < 768;

    return StreamBuilder<List<ScheduleCategory>>(
      stream: _categoriesStream,
      builder: (context, catSnap) {
        if (catSnap.hasData) _allCategories = catSnap.data!;
        return Scaffold(
          backgroundColor: Colors.grey.shade200,
          appBar: isMobile ? null : _buildAppBar(showCompactMenu),
          body: StreamBuilder<List<ClassSchedule>>(
            stream: _schedulesStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  _allSchedules.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                    child: Text('Error: ${snap.error}',
                        style: const TextStyle(color: Colors.red)));
              }
              if (snap.hasData) _allSchedules = snap.data!;
              final filtered    = _applyFilters(_allSchedules);
              final activeSlots = _activeCategorySlots ?? _timeSlots;
              return _buildTable(filtered, activeSlots);
            },
          ),
        );
      },
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  AppBar _buildAppBar(bool compact) => AppBar(
    actions: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Stack(children: [
          ElevatedButton.icon(
            onPressed: _showFilterDialog,
            icon:  const Icon(Icons.filter_list),
            label: const Text('Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).primaryColor,
            ),
          ),
          if (_hasActiveFilters)
            Positioned(
              right: 0, top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.orange, shape: BoxShape.circle),
                constraints:
                const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  '$activeFilterCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ]),
      ),
      if (!compact) ...[
        _appBarBtn(Icons.person_add,   'Teacher',   _showAddTeacherDialog),
        _appBarBtn(Icons.meeting_room, 'Classroom', _showAddClassroomDialog),
        _appBarBtn(Icons.category,     'Category',  _showAddCategoryDialog),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: ElevatedButton.icon(
            onPressed: _allSchedules.isNotEmpty
                ? () => _exportToPdf(_applyFilters(_allSchedules))
                : null,
            icon:  const Icon(Icons.picture_as_pdf),
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
          icon:  const Icon(Icons.more_vert, color: Colors.white),
          color: Colors.white,
          onSelected: (v) {
            if (v == 'add_teacher')   _showAddTeacherDialog();
            if (v == 'add_classroom') _showAddClassroomDialog();
            if (v == 'add_category')  _showAddCategoryDialog();
            if (v == 'export_pdf' && _allSchedules.isNotEmpty)
              _exportToPdf(_applyFilters(_allSchedules));
          },
          itemBuilder: (_) => [
            _popItem('add_teacher',   Icons.person_add,     'Add Teacher',   true),
            _popItem('add_classroom', Icons.meeting_room,   'Add Classroom', true),
            _popItem('add_category',  Icons.category,       'Add Category',  true),
            _popItem('export_pdf',    Icons.picture_as_pdf, 'Export PDF',
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
          icon:  Icon(icon, size: 18),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).primaryColor,
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      );

  PopupMenuItem<String> _popItem(
      String val, IconData icon, String label, bool enabled) =>
      PopupMenuItem(
        value:   val,
        enabled: enabled,
        child: Row(children: [
          Icon(icon,
              color: enabled
                  ? Theme.of(context).primaryColor
                  : Colors.grey),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  color: enabled ? Colors.black : Colors.grey)),
        ]),
      );

  /// Returns the time slots for the currently selected category (with break
  /// marker injected), or null to fall back to the global slot list.
  List<String>? get _activeCategorySlots {
    if (_selectedCategoryFilter == null) return null;
    final cat = _allCategories.cast<ScheduleCategory?>().firstWhere(
          (c) => c?.name == _selectedCategoryFilter,
      orElse: () => null,
    );
    if (cat == null) return null;
    if (!cat.hasBreak) return cat.timeSlots;

    final slots      = <String>[];
    final breakLabel = '${_fmtMin(cat.breakStartTotal)}-'
        '${_fmtMin(cat.breakEndTotal)}';
    final breakMarker = 'BREAK|$breakLabel';

    for (final slot in cat.timeSlots) {
      if (slots.isNotEmpty && !slots.contains(breakMarker)) {
        final slotStartMin =
        _parseMin(slot.split('-').first.trim());
        if (slotStartMin >= cat.breakEndTotal) slots.add(breakMarker);
      }
      slots.add(slot);
    }
    return slots;
  }

  String _fmtMin(int m) {
    final h  = m ~/ 60, min = m % 60;
    final p  = h >= 12 ? 'PM' : 'AM';
    final dh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$dh:${min.toString().padLeft(2, '0')} $p';
  }

  int _parseMin(String time) {
    final parts  = time.trim().split(' ');
    final hm     = parts[0].split(':');
    final isPM   = parts[1].toUpperCase() == 'PM';
    int    hour  = int.parse(hm[0]);
    final minute = int.parse(hm[1]);
    if (isPM  && hour != 12) hour += 12;
    if (!isPM && hour == 12) hour  = 0;
    return hour * 60 + minute;
  }

  // ── Table ─────────────────────────────────────────────────────────────────

  Widget _buildTable(
      List<ClassSchedule> schedules, List<String> activeSlots) {
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
                  horizontalInside:
                  BorderSide(color: Colors.grey.shade300),
                  verticalInside:
                  BorderSide(color: Colors.grey.shade300),
                ),
                columnWidths: {
                  0: const FixedColumnWidth(150),
                  for (int i = 0; i < activeSlots.length; i++)
                    i + 1: _isBreak(activeSlots[i])
                        ? const FixedColumnWidth(80)
                        : const FixedColumnWidth(150),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.blue.shade100,
                        Colors.purple.shade100,
                      ]),
                    ),
                    children: [
                      _headerCell('Day', isDay: true),
                      ...activeSlots.map((s) => _isBreak(s)
                          ? _breakHeaderCell(s)
                          : _headerCell(s, isTimeSlot: true)),
                    ],
                  ),
                  ..._days.asMap().entries.map((e) {
                    final isEven = e.key % 2 == 0;
                    return TableRow(
                      decoration: BoxDecoration(
                          color: isEven
                              ? Colors.grey.shade50
                              : Colors.white),
                      children: [
                        _dayCell(e.value),
                        ...activeSlots.map((s) => _isBreak(s)
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
        padding:
        const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isTimeSlot) ...[
                Icon(Icons.access_time,
                    size: 14, color: Colors.purple.shade700),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isTimeSlot ? 10 : 13,
                    color: isDay
                        ? Colors.purple.shade700
                        : Colors.indigo.shade700,
                    letterSpacing: 0.4,
                  ),
                  textAlign: TextAlign.center,
                  maxLines:  2,
                  overflow:  TextOverflow.ellipsis,
                ),
              ),
            ]),
      );

  Widget _breakHeaderCell(String slot) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [
        Colors.amber.shade200, Colors.orange.shade200,
      ]),
    ),
    child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.free_breakfast,
              size: 16, color: Colors.orange.shade800),
          const SizedBox(height: 4),
          Text('BREAK',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: Colors.orange.shade900,
                  letterSpacing: 0.5),
              textAlign: TextAlign.center),
          Text(_breakLabel(slot),
              style: TextStyle(
                  fontSize: 8, color: Colors.orange.shade800),
              textAlign: TextAlign.center),
        ]),
  );

  Widget _dayCell(String day) => Container(
    padding:
    const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.indigo.shade50,
          Colors.purple.shade50,
        ])),
    child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today,
              size: 14, color: Colors.indigo.shade600),
          const SizedBox(width: 6),
          Expanded(
              child: Text(day,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Colors.indigo.shade800),
                  textAlign: TextAlign.center)),
        ]),
  );

  Widget _breakBodyCell() => Container(
    constraints: const BoxConstraints(minHeight: 70),
    color: Colors.amber.shade50,
    child: CustomPaint(
      painter:
      _StripePainter(color: Colors.amber.shade100, gap: 8),
      child: Center(
          child: Icon(Icons.coffee,
              size: 22, color: Colors.orange.shade300)),
    ),
  );

  Widget _scheduleCell(
      List<ClassSchedule> schedules, String slot, String day) {
    final classes = schedules
        .where((s) => s.timeSlot == slot && s.days.contains(day))
        .toList();

    return Container(
      padding:     const EdgeInsets.all(8),
      constraints: const BoxConstraints(minHeight: 70),
      child: classes.isEmpty
          ? Center(
          child: Icon(Icons.remove_circle_outline,
              color: Colors.grey.shade300, size: 20))
          : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize:       MainAxisSize.min,
        children: classes.asMap().entries.map((e) {
          final s        = e.value;
          final isNavttc = s.classType == ClassType.navttc;
          final gradients = isNavttc
              ? const [
            [Color(0xFF43A047), Color(0xFF2E7D32)],
            [Color(0xFF00897B), Color(0xFF00695C)],
            [Color(0xFF7CB342), Color(0xFF558B2F)],
            [Color(0xFF00ACC1), Color(0xFF00838F)],
          ]
              : const [
            [Color(0xFF42A5F5), Color(0xFF1E88E5)],
            [Color(0xFFAB47BC), Color(0xFF8E24AA)],
            [Color(0xFF26A69A), Color(0xFF00897B)],
            [Color(0xFFFFA726), Color(0xFFFB8C00)],
          ];
          final g = gradients[e.key % gradients.length];

          return Container(
            margin: EdgeInsets.only(
                bottom: classes.length > 1 ? 5 : 0),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                  colors: g),
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                    color:      g[0].withOpacity(0.2),
                    blurRadius: 4,
                    offset:     const Offset(0, 2))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNavttc) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    margin:
                    const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius:
                      BorderRadius.circular(4),
                    ),
                    child: const Text('NAVTTC',
                        style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.8)),
                  ),
                ],
                if (s.categoryName != null &&
                    s.categoryName!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    margin:
                    const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius:
                      BorderRadius.circular(4),
                    ),
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                              Icons.category_outlined,
                              size:  7,
                              color: Colors.white),
                          const SizedBox(width: 2),
                          Flexible(
                              child: Text(s.categoryName!,
                                  style: const TextStyle(
                                      fontSize: 7,
                                      fontWeight:
                                      FontWeight.w700,
                                      color: Colors.white),
                                  overflow:
                                  TextOverflow.ellipsis)),
                        ]),
                  ),
                ],
                _cardRow(Icons.class_, s.batchName,
                    bold: true),
                const SizedBox(height: 4),
                _cardRow(Icons.person, s.teacherName),
                const SizedBox(height: 3),
                _cardRow(Icons.meeting_room, s.classroom),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () => _deleteSchedule(s),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius:
                        BorderRadius.circular(3.5),
                      ),
                      child: const Icon(
                          Icons.delete_outline,
                          size:  14,
                          color: Colors.white),
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

  Widget _cardRow(IconData icon, String text,
      {bool bold = false}) =>
      Row(children: [
        Icon(icon,
            size:  bold ? 12 : 10,
            color: Colors.white.withOpacity(bold ? 1.0 : 0.9)),
        const SizedBox(width: 3),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: bold ? 11 : 9,
                    fontWeight: bold
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: Colors.white
                        .withOpacity(bold ? 1.0 : 0.95)),
                overflow: TextOverflow.ellipsis,
                maxLines: 1)),
      ]);

  // ── Actions ───────────────────────────────────────────────────────────────

  void _showAddTeacherDialog() => AppTheme.showPopup(
      builder: (_) => AddTeacherDialog(), context: context);

  void _showAddClassroomDialog() => AppTheme.showPopup(
      builder: (_) => AddClassroomDialog(), context: context);

  void _showAddCategoryDialog() => AppTheme.showPopup(
      builder: (_) => const AddCategoryDialog(), context: context);

  Future<void> _exportToPdf(List<ClassSchedule> schedules) async {
    try {
      final ScheduleCategory? activeCategory =
      _selectedCategoryFilter == null
          ? null
          : _allCategories.cast<ScheduleCategory?>().firstWhere(
            (c) => c?.name == _selectedCategoryFilter,
        orElse: () => null,
      );

      await _pdfService.generateSchedulePdf(
        schedules,
        classType: _selectedClassTypeFilter ?? ClassType.regular,
        category:  activeCategory,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:         Text('PDF generated successfully'),
            backgroundColor: Colors.green));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:         Text('Error generating PDF: $e'),
            backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteSchedule(ClassSchedule schedule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning, color: Colors.orange),
          SizedBox(width: 12),
          Text('Delete Class'),
        ]),
        content: Text('Delete "${schedule.batchName}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _scheduleService.deleteSchedule(schedule.id);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:         Text('Class deleted'),
            backgroundColor: Colors.green));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:         Text('Error: $e'),
            backgroundColor: Colors.red));
    }
  }
}

// ── Stripe painter ────────────────────────────────────────────────────────────

class _StripePainter extends CustomPainter {
  final Color  color;
  final double gap;
  const _StripePainter({required this.color, required this.gap});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = color
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke;
    for (double d = 0; d < size.width + size.height; d += gap) {
      canvas.drawLine(
        Offset(d < size.height ? 0 : d - size.height,
            d < size.height ? d : size.height),
        Offset(d < size.width ? d : size.width,
            d < size.width ? 0 : d - size.width),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) =>
      old.color != color || old.gap != gap;
}

// ── Filter Dialog ─────────────────────────────────────────────────────────────

// ── Filter Dialog ─────────────────────────────────────────────────────────────

class FilterDialog extends StatefulWidget {
  final List<String>           classrooms, teachers, batches;
  final List<ScheduleCategory> categories;
  final List<ScheduleCategory> allCategories;
  final String?                selectedClassroom, selectedTeacher,
      selectedBatch, selectedCategoryName;
  final ClassType?             selectedClassType;
  final List<ClassSchedule>    allSchedules;
  final Function(String?, String?, String?, String?, ClassType?) onApply;
  final VoidCallback           onClear;

  const FilterDialog({
    Key? key,
    required this.classrooms,
    required this.teachers,
    required this.batches,
    required this.categories,
    required this.allCategories,
    required this.allSchedules,
    this.selectedClassroom,
    this.selectedTeacher,
    this.selectedBatch,
    this.selectedCategoryName,
    this.selectedClassType,
    required this.onApply,
    required this.onClear,
  }) : super(key: key);

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  String?    _room;
  String?    _teacher;
  String?    _batch;
  String?    _categoryName;
  ClassType? _classType;

  @override
  void initState() {
    super.initState();
    _room         = widget.selectedClassroom;
    _teacher      = widget.selectedTeacher;
    _batch        = widget.selectedBatch;
    _categoryName = widget.selectedCategoryName;
    _classType    = widget.selectedClassType ?? ClassType.regular;
  }

  List<ScheduleCategory> get _availableCategories {
    if (_classType == null) return widget.allCategories;
    final usedNames = widget.allSchedules
        .where((s) => s.classType == _classType)
        .map((s) => s.categoryName)
        .whereType<String>()
        .toSet();
    return widget.allCategories
        .where((c) => usedNames.contains(c.name))
        .toList();
  }

  void _onClassTypeChanged(ClassType? newType) {
    setState(() {
      _classType = newType;
      if (_categoryName != null) {
        final usedNames = widget.allSchedules
            .where((s) => newType == null || s.classType == newType)
            .map((s) => s.categoryName)
            .whereType<String>()
            .toSet();
        if (!usedNames.contains(_categoryName)) _categoryName = null;
      }
    });
  }

  void _applyAndPop() {
    widget.onApply(_room, _teacher, _batch, _categoryName, _classType);
    Navigator.pop(context);
  }

  void _clearAndPop() {
    setState(() {
      _room = _teacher = _batch = _categoryName = null;
      _classType = ClassType.regular;
    });
    widget.onClear();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return isMobile ? _buildBottomSheet() : _buildDesktopDialog();
  }

  // ── Desktop Dialog ────────────────────────────────────────────────────────

  Widget _buildDesktopDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width:   500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize:       MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 20),
              _filterBody(),
              const SizedBox(height: 24),
              _actions(isMobile: false),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mobile Bottom Sheet ───────────────────────────────────────────────────

  Widget _buildBottomSheet() {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width:        double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width:  40,
                height: 4,
                decoration: BoxDecoration(
                  color:        Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Sticky header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: _header(),
              ),
              const Divider(height: 24),
              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _filterBody(),
                ),
              ),
              // Sticky action bar
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
                child: _actions(isMobile: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared Sections ───────────────────────────────────────────────────────

  Widget _header() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.blue.shade400,
            Colors.purple.shade400,
          ]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.filter_list,
            color: Colors.white, size: isMobile ? 22 : 28),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter Schedule',
                style: TextStyle(
                    fontSize:   isMobile ? 18 : 24,
                    fontWeight: FontWeight.bold,
                    color:      Colors.grey.shade800)),
            Text('Refine your schedule view',
                style: TextStyle(
                    fontSize: 13,
                    color:    Colors.grey.shade600)),
          ],
        ),
      ),
      IconButton(
          onPressed: () => Navigator.pop(context),
          icon:  const Icon(Icons.close),
          color: Colors.grey.shade600),
    ]);
  }

  Widget _filterBody() {
    final availableCats = _availableCategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _classTypePicker(),
        const SizedBox(height: 16),
        if (availableCats.isNotEmpty) ...[
          _dropdown(
            'Filter by Category',
            Icons.category,
            Colors.indigo,
            availableCats.map((c) => c.name).toList(),
            _categoryName,
                (v) => setState(() => _categoryName = v),
          ),
          const SizedBox(height: 16),
        ],
        _dropdown('Filter by Teacher',   Icons.person,
            Colors.blue,   widget.teachers,   _teacher,
                (v) => setState(() => _teacher = v)),
        const SizedBox(height: 16),
        _dropdown('Filter by Classroom', Icons.meeting_room,
            Colors.green,  widget.classrooms, _room,
                (v) => setState(() => _room = v)),
        const SizedBox(height: 16),
        _dropdown('Filter by Batch',     Icons.group,
            Colors.orange, widget.batches,    _batch,
                (v) => setState(() => _batch = v)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _actions({required bool isMobile}) {
    final clearBtn = TextButton.icon(
      onPressed: _clearAndPop,
      icon:  const Icon(Icons.clear_all),
      label: const Text('Clear All'),
      style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
    );

    final applyBtn = ElevatedButton.icon(
      onPressed: _applyAndPop,
      icon:  const Icon(Icons.check),
      label: const Text('Apply'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        padding:         const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    if (isMobile) {
      // On mobile: full-width Apply + smaller Clear below
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _applyAndPop,
              icon:  const Icon(Icons.check),
              label: const Text('Apply Filters',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: clearBtn),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        clearBtn,
        Row(children: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          const SizedBox(width: 12),
          applyBtn,
        ]),
      ],
    );
  }

  // ── Class type picker ─────────────────────────────────────────────────────

  Widget _classTypePicker() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final options = <ClassType?, _TypeOption>{
      ClassType.regular: _TypeOption(
          Icons.school_outlined, 'Regular', Colors.blue),
      ClassType.navttc: _TypeOption(
          Icons.account_balance_outlined, 'NAVTTC', Colors.green),
      null: _TypeOption(
          Icons.list_alt_outlined, 'All', Colors.purple),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Class Type',
            style: TextStyle(
                fontSize:   12,
                fontWeight: FontWeight.w600,
                color:      Colors.grey.shade700)),
        const SizedBox(height: 8),
        // Use Wrap so it wraps on very narrow screens
        isMobile
            ? Row(
          children: options.entries.map((entry) =>
              Expanded(child: _typeChip(entry.key, entry.value))
          ).toList(),
        )
            : Row(
          children: options.entries.map((entry) =>
              Expanded(child: _typeChip(entry.key, entry.value))
          ).toList(),
        ),
      ],
    );
  }

  Widget _typeChip(ClassType? type, _TypeOption opt) {
    final isSelected = _classType == type;
    final isMobile   = MediaQuery.of(context).size.width < 600;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _onClassTypeChanged(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
              vertical: isMobile ? 12 : 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? opt.color.withOpacity(0.12)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? opt.color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(children: [
            Icon(opt.icon,
                size:  isMobile ? 22 : 20,
                color: isSelected ? opt.color : Colors.grey),
            const SizedBox(height: 4),
            Text(opt.label,
                style: TextStyle(
                    fontSize:   isMobile ? 12 : 11,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected ? opt.color : Colors.grey)),
          ]),
        ),
      ),
    );
  }

  // ── Dropdown ──────────────────────────────────────────────────────────────

  Widget _dropdown(
      String label,
      IconData icon,
      MaterialColor color,
      List<String> items,
      String? value,
      ValueChanged<String?> onChanged,
      ) =>
      DropdownButtonFormField<String>(
        isExpanded:  true,
        decoration: InputDecoration(
          labelText:  label,
          prefixIcon: Icon(icon, color: color.shade600),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
              BorderSide(color: color.shade600, width: 2)),
          filled:    true,
          fillColor: Colors.grey.shade50,
        ),
        value: value,
        items: [
          DropdownMenuItem<String>(
              value: null,
              child: Text('All ${label.split(' ').last}s')),
          ...items.map(
                  (i) => DropdownMenuItem<String>(value: i, child: Text(i))),
        ],
        onChanged: onChanged,
      );
}

class _TypeOption {
  final IconData icon;
  final String   label;
  final Color    color;
  const _TypeOption(this.icon, this.label, this.color);
}
