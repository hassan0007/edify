import 'package:edify/theme/app_theme.dart';
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
import 'package:edify/widgets/add_category.dart';

class AppShell extends StatefulWidget {
  const AppShell({Key? key}) : super(key: key);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int  _selectedIndex    = 0;
  bool _isSidebarVisible = false;

  ClassType? _selectedClassTypeFilter = ClassType.regular;

  final TeacherService  _teacherService  = TeacherService();
  final ScheduleService _scheduleService = ScheduleService();

  late final Stream<List<ClassSchedule>> _schedulesStream;
  late final Stream<List<Teacher>>       _teachersStream;

  List<ClassSchedule> _allSchedules = [];
  List<Teacher>       _allTeachers  = [];

  final GlobalKey<HomeScreenState> _homeScreenKey =
  GlobalKey<HomeScreenState>();

  late final HomeScreen          _homeScreen;
  late final TeacherSearchScreen _searchScreen;

  @override
  void initState() {
    super.initState();
    _schedulesStream =
        _scheduleService.getSchedules().asBroadcastStream();
    _teachersStream =
        _teacherService.getTeachers().asBroadcastStream();
    _homeScreen = HomeScreen(
      key:             _homeScreenKey,
      schedulesStream: _schedulesStream,
    );
    _searchScreen = TeacherSearchScreen();
  }

  bool _isMobile() => MediaQuery.of(context).size.width < 768;

  void _onNavChanged(int index) => setState(() {
    _selectedIndex = index;
    if (_isMobile()) _isSidebarVisible = false;
  });

  void _toggleSidebar() =>
      setState(() => _isSidebarVisible = !_isSidebarVisible);

  // ── Filter forwarding ─────────────────────────────────────────────────────

  void _applyClassTypeFilter(ClassType? type) {
    setState(() => _selectedClassTypeFilter = type);
    _homeScreenKey.currentState?.setClassTypeFilter(type);
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showAddClassDialog() {
    if (_allTeachers.isEmpty) { _showNoTeachersDialog(); return; }
    AppTheme.showPopup(
      builder: (_) => AddClassDialog(
        teachers:          _allTeachers,
        existingSchedules: _allSchedules,
      ),
      context: context,
    );
  }

  void _showAddTeacherDialog() =>
      showDialog(context: context, builder: (_) => const AddTeacherDialog());

  void _showAddClassroomDialog() =>
      showDialog(context: context, builder: (_) => const AddClassroomDialog());

  void _showAddCategoryDialog() =>
      showDialog(context: context, builder: (_) => const AddCategoryDialog());

  void _showFilterDialog() =>
      _homeScreenKey.currentState?.showFilterDialogPublic();

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
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
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
              body: Stack(children: [
                Row(children: [
                  if (!isMobile)
                    CollapsibleSidebar(
                      selectedIndex:       _selectedIndex,
                      onNavigationChanged: _onNavChanged,
                      isMobile:            false,
                    ),
                  Expanded(child: _buildBody()),
                ]),

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
                      curve:    Curves.easeInOut,
                      tween:    Tween<double>(begin: -250, end: 0),
                      builder:  (_, val, child) => Transform.translate(
                          offset: Offset(val, 0), child: child),
                      child: CollapsibleSidebar(
                        selectedIndex:       _selectedIndex,
                        onNavigationChanged: _onNavChanged,
                        isMobile:            true,
                      ),
                    ),
                  ),
                ],
              ]),
              floatingActionButton: _buildFAB(),
            );
          },
        );
      },
    );
  }

  // ── Mobile AppBar ─────────────────────────────────────────────────────────

  AppBar _buildMobileAppBar() {
    final onScheduleTab = _selectedIndex == 0;
    final activeFilters = _homeScreenKey.currentState?.activeFilterCount ?? 0;
    final hasFilters    = activeFilters > 0;

    return AppBar(
      backgroundColor: const Color(0xFF1D4ED8),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: _toggleSidebar,
      ),
      title: const Text('Hussain',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
      actions: [
        PopupMenuButton<String>(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.more_vert, color: Colors.white),
              if (hasFilters)
                Positioned(
                  right: -4, top: -4,
                  child: Container(
                    width: 14, height: 14,
                    decoration: const BoxDecoration(
                        color: Colors.orange, shape: BoxShape.circle),
                    child: Center(
                      child: Text('$activeFilters',
                          style: const TextStyle(
                              color:      Colors.white,
                              fontSize:   8,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
          color: Colors.white,
          onSelected: (v) {
            if (v == 'add_teacher')   _showAddTeacherDialog();
            if (v == 'add_classroom') _showAddClassroomDialog();
            if (v == 'add_category')  _showAddCategoryDialog();
            if (v == 'add_class')     _showAddClassDialog();
            if (v == 'filter')        _showFilterDialog();
            if (v == 'type_regular')  _applyClassTypeFilter(ClassType.regular);
            if (v == 'type_navttc')   _applyClassTypeFilter(ClassType.navttc);
            if (v == 'type_all')      _applyClassTypeFilter(null);
          },
          itemBuilder: (_) => [

            // ── FILTERS ───────────────────────────────────────────────────
            if (onScheduleTab) ...[
              _sectionHeader('Filters'),
              PopupMenuItem<String>(
                value: 'filter',
                child: Row(children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.filter_list,
                          color: hasFilters
                              ? Colors.orange
                              : const Color(0xFF1D4ED8)),
                      if (hasFilters)
                        Positioned(
                          right: -4, top: -4,
                          child: Container(
                            width: 12, height: 12,
                            decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle),
                            child: Center(
                              child: Text('$activeFilters',
                                  style: const TextStyle(
                                      color:      Colors.white,
                                      fontSize:   7,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Text(
                    hasFilters
                        ? 'Filters  ($activeFilters active)'
                        : 'Filters',
                    style: TextStyle(
                      fontWeight: hasFilters
                          ? FontWeight.w600 : FontWeight.normal,
                      color: hasFilters
                          ? Colors.orange.shade800 : Colors.black87,
                    ),
                  ),
                ]),
              ),
              const PopupMenuDivider(),
            ],

            // ── ADD ───────────────────────────────────────────────────────
            _sectionHeader('Add'),
            _popItem('add_teacher',   Icons.person_add,   'Add Teacher',   Colors.blue),
            _popItem('add_classroom', Icons.meeting_room, 'Add Classroom', Colors.green),
            _popItem('add_category',  Icons.category,     'Add Category',  Colors.indigo),
          ],
        ),
      ],
    );
  }

  // ── Menu helpers ──────────────────────────────────────────────────────────

  PopupMenuItem<String> _sectionHeader(String label) =>
      PopupMenuItem<String>(
        enabled: false,
        height:  30,
        child: Text(label.toUpperCase(),
            style: TextStyle(
                fontSize:      10,
                fontWeight:    FontWeight.w700,
                letterSpacing: 1.1,
                color:         Colors.grey.shade500)),
      );

  PopupMenuItem<String> _classTypeItem(
      String   value,
      String   label,
      IconData icon,
      Color    color,
      bool     selected,
      ) =>
      PopupMenuItem<String>(
        value: value,
        child: Row(children: [
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              border: Border.all(
                  color: selected ? color : Colors.grey.shade400, width: 2),
            ),
            child: selected
                ? Center(child: Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: color)))
                : null,
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 16,
              color: selected ? color : Colors.grey.shade400),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontSize:   14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected
                      ? Colors.grey.shade900 : Colors.grey.shade700)),
        ]),
      );

  PopupMenuItem<String> _popItem(
      String   val,
      IconData icon,
      String   label,
      MaterialColor color,
      ) =>
      PopupMenuItem(
        value: val,
        child: Row(children: [
          Icon(icon, color: color.shade600),
          const SizedBox(width: 12),
          Text(label),
        ]),
      );

  // ── FAB ───────────────────────────────────────────────────────────────────

  Widget? _buildFAB() {
    if (_selectedIndex != 0) return null;
    return FloatingActionButton.extended(
      onPressed:       _showAddClassDialog,
      icon:            const Icon(Icons.add),
      label:           const Text('Add New Class'),
      backgroundColor: const Color(0xFF1D4ED8),
      elevation:       8,
    );
  }

  Widget _buildBody() => IndexedStack(
    index:    _selectedIndex,
    children: [_homeScreen, _searchScreen],
  );
}

// ── Collapsible Sidebar ───────────────────────────────────────────────────────

class CollapsibleSidebar extends StatefulWidget {
  final int               selectedIndex;
  final ValueChanged<int> onNavigationChanged;
  final bool              isMobile;

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
    final expanded = widget.isMobile ? true : _isExpanded;
    final showText = widget.isMobile ? true : _showText;

    return AnimatedContainer(
      duration:     const Duration(milliseconds: 200),
      width:        expanded ? 250 : 80,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: const Color(0xFF1D4ED8),
        boxShadow: [BoxShadow(
            color:      Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset:     const Offset(2, 0))],
      ),
      child: Column(children: [
        // Logo / brand
        if (!widget.isMobile)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(
                    color: Colors.white.withOpacity(0.2)))),
            child: Row(children: [
              const Icon(Icons.school, color: Colors.white, size: 32),
              if (showText && expanded) ...[
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Hussain\nCollege of IT',
                      style: TextStyle(
                          color:      Colors.white,
                          fontSize:   16,
                          fontWeight: FontWeight.bold,
                          height:     1.2)),
                ),
              ],
            ]),
          ),

        // Nav items
        Expanded(
          child: ListView.builder(
            padding:    const EdgeInsets.symmetric(vertical: 16),
            itemCount:  _navItems.length,
            itemBuilder: (_, i) {
              final item       = _navItems[i];
              final isSelected = widget.selectedIndex == i;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap:         () => widget.onNavigationChanged(i),
                    borderRadius:  BorderRadius.circular(12),
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
                          Expanded(
                            child: Text(item.label,
                                style: TextStyle(
                                    color:      Colors.white,
                                    fontSize:   15,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal)),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Collapse toggle (desktop only)
        if (!widget.isMobile)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                border: Border(top: BorderSide(
                    color: Colors.white.withOpacity(0.2)))),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap:        _toggle,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize:      MainAxisSize.min,
                    children: [
                      Icon(
                          _isExpanded
                              ? Icons.chevron_left
                              : Icons.chevron_right,
                          color: Colors.white, size: 24),
                      if (_showText && _isExpanded) ...[
                        const SizedBox(width: 8),
                        const Text('Collapse',
                            style: TextStyle(
                                color: Colors.white, fontSize: 14)),
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