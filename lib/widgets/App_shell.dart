import 'package:flutter/material.dart';
import 'package:edify/screens/home_screen.dart';
import 'package:edify/screens/search_screen.dart';
import 'package:edify/models/teacher.dart';
import 'package:edify/models/class_schedule.dart';
import 'package:edify/services/teacher_service.dart';
import 'package:edify/services/schedule_service.dart';
import 'package:edify/widgets/add_teacher_dialog.dart';
import 'package:edify/widgets/add_class_dialog.dart';
import 'package:edify/widgets/add_classroom_dialog.dart';

class AppShell extends StatefulWidget {
  const AppShell({Key? key}) : super(key: key);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int  _selectedIndex   = 0;
  bool _isSidebarVisible = false;

  final TeacherService  _teacherService  = TeacherService();
  final ScheduleService _scheduleService = ScheduleService();

  // ── ONE broadcast stream shared by the whole shell ────────────────────────
  late final Stream<List<ClassSchedule>> _schedulesStream;
  late final Stream<List<Teacher>>       _teachersStream;

  // Latest values — updated by the root StreamBuilders below so every
  // child widget reads from memory, never from Firebase directly.
  List<ClassSchedule> _allSchedules = [];
  List<Teacher>       _allTeachers  = [];

  // Screens are created once and kept alive via IndexedStack
  late final HomeScreen     _homeScreen;
  late final TeacherSearchScreen _searchScreen;

  @override
  void initState() {
    super.initState();
    _schedulesStream = _scheduleService.getSchedules().asBroadcastStream();
    _teachersStream  = _teacherService.getTeachers().asBroadcastStream();
    _homeScreen   = HomeScreen(schedulesStream: _schedulesStream);
    _searchScreen = TeacherSearchScreen();
  }

  bool _isMobile() => MediaQuery.of(context).size.width < 768;

  void _onNavChanged(int index) {
    setState(() {
      _selectedIndex = index;
      if (_isMobile()) _isSidebarVisible = false;
    });
  }

  void _toggleSidebar() =>
      setState(() => _isSidebarVisible = !_isSidebarVisible);

  // ── Filter dialog — reads from _allSchedules, zero Firebase call ──────────
  void _showFilterDialog() {
    if (_selectedIndex != 0) return;

    final classrooms = _allSchedules.map((s) => s.classroom)
        .where((c) => c.isNotEmpty).toSet().toList()..sort();
    final teachers = _allSchedules.map((s) => s.teacherName)
        .where((t) => t.isNotEmpty).toSet().toList()..sort();
    final batches = _allSchedules.map((s) => s.batchName)
        .where((b) => b.isNotEmpty).toSet().toList()..sort();

    showDialog(
      context: context,
      builder: (_) => _FilterDialog(
        classrooms: classrooms, teachers: teachers, batches: batches,
        onApply: (room, teacher, batch) {
          // Delegate to HomeScreen's own filter state via its GlobalKey or
          // just show feedback; HomeScreen owns its filter state.
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Use the Filters button on the schedule for full filter support.'),
            backgroundColor: Colors.blue.shade600,
          ));
        },
        onClear: () {},
      ),
    );
  }

  // ── Add-class dialog — passes cached data, no extra reads ─────────────────
  void _showAddClassDialog() {
    if (_allTeachers.isEmpty) {
      _showNoTeachersDialog();
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AddClassDialog(
        teachers:          _allTeachers,
        existingSchedules: _allSchedules,
      ),
    );
  }

  void _showAddTeacherDialog() =>
      showDialog(context: context, builder: (_) => const AddTeacherDialog());

  void _showAddClassroomDialog() =>
      showDialog(context: context, builder: (_) => const AddClassroomDialog());

  void _showNoTeachersDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning, color: Colors.orange),
          SizedBox(width: 12),
          Text('No Teachers Available'),
        ]),
        content: const Text(
            'Please add at least one teacher before creating a class schedule.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showAddTeacherDialog();
            },
            child: const Text('Add Teacher'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = _isMobile();

    // Two root StreamBuilders that feed _allSchedules / _allTeachers.
    // Everything else reads from those fields — zero extra subscriptions.
    return StreamBuilder<List<ClassSchedule>>(
      stream: _schedulesStream,
      builder: (context, schedSnap) {
        if (schedSnap.hasData) _allSchedules = schedSnap.data!;

        return StreamBuilder<List<Teacher>>(
          stream: _teachersStream,
          builder: (context, teachSnap) {
            if (teachSnap.hasData) _allTeachers = teachSnap.data!;

            return Scaffold(
              appBar: isMobile ? _buildMobileAppBar() : null,
              body: Stack(
                children: [
                  Row(children: [
                    if (!isMobile)
                      CollapsibleSidebar(
                        selectedIndex:        _selectedIndex,
                        onNavigationChanged:  _onNavChanged,
                        isMobile:             false,
                      ),
                    Expanded(child: _buildBody()),
                  ]),

                  // Mobile sidebar overlay
                  if (isMobile && _isSidebarVisible) ...[
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _toggleSidebar,
                        child: Container(color: Colors.black.withOpacity(0.5)),
                      ),
                    ),
                    Positioned(
                      left: 0, top: 0, bottom: 0, width: 250,
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        tween: Tween<double>(begin: -250, end: 0),
                        builder: (_, val, child) =>
                            Transform.translate(offset: Offset(val, 0), child: child),
                        child: CollapsibleSidebar(
                          selectedIndex:       _selectedIndex,
                          onNavigationChanged: _onNavChanged,
                          isMobile:            true,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              floatingActionButton: _buildFAB(),
            );
          },
        );
      },
    );
  }

  // ── Mobile AppBar — reads from cached fields, no StreamBuilders ───────────

  AppBar _buildMobileAppBar() => AppBar(
    backgroundColor: const Color(0xFF1D4ED8),
    leading: IconButton(
      icon: const Icon(Icons.menu, color: Colors.white),
      onPressed: _toggleSidebar,
    ),
    title: const Text('Hussain', style: TextStyle(color: Colors.white)),
    actions: [
      if (_selectedIndex == 0)
        IconButton(
          icon: const Icon(Icons.filter_list, color: Colors.white),
          onPressed: _showFilterDialog,
          tooltip: 'Filters',
        ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        color: Colors.white,
        onSelected: (v) {
          if (v == 'add_teacher')   _showAddTeacherDialog();
          if (v == 'add_classroom') _showAddClassroomDialog();
          if (v == 'add_class')     _showAddClassDialog();
        },
        itemBuilder: (_) => [
          _popItem('add_teacher',   Icons.person_add,   'Add Teacher'),
          _popItem('add_classroom', Icons.meeting_room, 'Add Classroom'),
          _popItem('add_class',     Icons.add,          'Add New Class'),
        ],
      ),
    ],
  );

  PopupMenuItem<String> _popItem(String val, IconData icon, String label) =>
      PopupMenuItem(
        value: val,
        child: Row(children: [
          Icon(icon, color: const Color(0xFF0f029c)),
          const SizedBox(width: 12),
          Text(label),
        ]),
      );

  // ── FAB — reads from cached _allTeachers, no StreamBuilder ───────────────

  Widget? _buildFAB() {
    if (_selectedIndex != 0) return null;
    return FloatingActionButton.extended(
      onPressed: _showAddClassDialog,   // _allTeachers already cached
      icon: const Icon(Icons.add),
      label: const Text('Add New Class'),
      backgroundColor: const Color(0xFF1D4ED8),
      elevation: 8,
    );
  }

  Widget _buildBody() => IndexedStack(
    index: _selectedIndex,
    children: [_homeScreen, _searchScreen],
  );
}

// ── Collapsible Sidebar ───────────────────────────────────────────────────────

class CollapsibleSidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavigationChanged;
  final bool isMobile;

  const CollapsibleSidebar({
    Key? key,
    required this.selectedIndex,
    required this.onNavigationChanged,
    this.isMobile = false,
  }) : super(key: key);

  @override
  State<CollapsibleSidebar> createState() => _CollapsibleSidebarState();
}

class _CollapsibleSidebarState extends State<CollapsibleSidebar> {
  bool _isExpanded = true;
  bool _showText   = true;

  static const _navItems = [
    _NavItem(Icons.calendar_month, 'Schedule'),
    _NavItem(Icons.person_search,  'Teacher Search'),
  ];

  void _toggle() {
    if (_isExpanded) {
      setState(() => _showText = false);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _isExpanded = false);
      });
    } else {
      setState(() => _isExpanded = true);
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _showText = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final expanded  = widget.isMobile ? true : _isExpanded;
    final showText  = widget.isMobile ? true : _showText;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: expanded ? 250 : 80,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: const Color(0xFF1D4ED8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2),
            blurRadius: 10, offset: const Offset(2, 0))],
      ),
      child: Column(children: [
        // Header (desktop only)
        if (!widget.isMobile)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(
                color: Colors.white.withOpacity(0.2)))),
            child: Row(children: [
              const Icon(Icons.school, color: Colors.white, size: 32),
              if (showText && expanded) ...[
                const SizedBox(width: 12),
                const Expanded(child: Text('Hussain\nCollege of IT',
                    style: TextStyle(color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.bold, height: 1.2))),
              ],
            ]),
          ),

        // Nav items
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: _navItems.length,
            itemBuilder: (_, i) {
              final item       = _navItems[i];
              final isSelected = widget.selectedIndex == i;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => widget.onNavigationChanged(i),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white.withOpacity(0.3)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(children: [
                        Icon(item.icon, color: Colors.white, size: 24),
                        if (showText && expanded) ...[
                          const SizedBox(width: 16),
                          Expanded(child: Text(item.label,
                              style: TextStyle(color: Colors.white, fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w600 : FontWeight.w400))),
                        ],
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Collapse button (desktop only)
        if (!widget.isMobile)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(top: BorderSide(
                color: Colors.white.withOpacity(0.2)))),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggle,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_isExpanded
                          ? Icons.chevron_left : Icons.chevron_right,
                          color: Colors.white, size: 24),
                      if (_showText && _isExpanded) ...[
                        const SizedBox(width: 8),
                        const Text('Collapse',
                            style: TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String   label;
  const _NavItem(this.icon, this.label);
}

// ── Filter Dialog ─────────────────────────────────────────────────────────────

class _FilterDialog extends StatefulWidget {
  final List<String> classrooms, teachers, batches;
  final Function(String?, String?, String?) onApply;
  final VoidCallback onClear;

  const _FilterDialog({
    required this.classrooms,
    required this.teachers,
    required this.batches,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  String? _room, _teacher, _batch;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

              _dropdown('Filter by Teacher',   Icons.person,      Colors.blue,
                  widget.teachers,   _teacher, (v) => setState(() => _teacher = v)),
              const SizedBox(height: 16),
              _dropdown('Filter by Classroom', Icons.meeting_room, Colors.green,
                  widget.classrooms, _room,    (v) => setState(() => _room = v)),
              const SizedBox(height: 16),
              _dropdown('Filter by Batch',     Icons.group,        Colors.orange,
                  widget.batches,    _batch,   (v) => setState(() => _batch = v)),

              const SizedBox(height: 24),
              Wrap(
                spacing: 12, runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() { _room = null; _teacher = null; _batch = null; });
                      widget.onClear();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.clear_all), label: const Text('Clear All'),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12)),
                  ),
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    TextButton(onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    ElevatedButton.icon(
                      onPressed: () {
                        widget.onApply(_room, _teacher, _batch);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check), label: const Text('Apply'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown(String label, IconData icon, MaterialColor color,
      List<String> items, String? value, ValueChanged<String?> onChange) {
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
      onChanged: onChange,
    );
  }
}