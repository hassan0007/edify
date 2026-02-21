// screens/teacher_search_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
  final TeacherService   _teacherService  = TeacherService();
  final ScheduleService  _scheduleService = ScheduleService();
  final TextEditingController _searchCtrl = TextEditingController();

  // Stream stored once — not recreated on every rebuild
  late final Stream<List<Teacher>> _teachersStream;

  String   _searchQuery    = '';
  Teacher? _selectedTeacher;

  @override
  void initState() {
    super.initState();
    _teachersStream = _teacherService.getTeachers().asBroadcastStream();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade50, Colors.white, Colors.purple.shade50],
        ),
      ),
      child: Column(children: [
        _buildHeader(),
        _buildSearchBar(),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.person_search, size: 32, color: Colors.indigo.shade700),
        const SizedBox(width: 12),
        Text('Teacher Search',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                color: Colors.indigo.shade900)),
      ]),
      const SizedBox(height: 8),
      Text('Search for a teacher to view their complete class schedule',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
    ]),
  );

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.all(24),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.indigo.withOpacity(0.1),
            blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Icon(Icons.search, color: Colors.indigo.shade400, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Type teacher name...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
              border: InputBorder.none,
            ),
            style: const TextStyle(fontSize: 16),
            onChanged: (v) => setState(() {
              _searchQuery    = v.toLowerCase();
              _selectedTeacher = null;
            }),
          ),
        ),
        if (_searchCtrl.text.isNotEmpty)
          IconButton(
            icon: Icon(Icons.clear, color: Colors.grey.shade400),
            onPressed: () {
              _searchCtrl.clear();
              setState(() { _searchQuery = ''; _selectedTeacher = null; });
            },
          ),
      ]),
    ),
  );

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {

    return StreamBuilder<List<Teacher>>(
      stream: _teachersStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return _errorState(snap.error.toString());

        final filtered = (snap.data ?? [])
            .where((t) => t.name.toLowerCase().contains(_searchQuery))
            .toList();

        if (filtered.isEmpty) return _noResultsState();
        return _searchResults(filtered);
      },
    );
  }

  Widget _searchResults(List<Teacher> teachers) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Teachers (${teachers.length})',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade900)),
          const SizedBox(height: 16),
          ...teachers.map((t) => _TeacherCard(
            teacher:         t,
            isSelected:      _selectedTeacher?.id == t.id,
            onTap: () => setState(() =>
            _selectedTeacher = _selectedTeacher?.id == t.id ? null : t),
          )),
          const SizedBox(height: 16),
          if (_selectedTeacher != null) ...[
            const Divider(height: 32),
            _ScheduleSection(
              teacher:         _selectedTeacher!,
              scheduleService: _scheduleService,
            ),
            const SizedBox(height: 24),
          ],
        ]),
      ),
    );
  }

  // ── State placeholders ────────────────────────────────────────────────────

  Widget _emptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search, size: 80, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      Text('Search for a Teacher',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600,
              color: Colors.grey.shade600)),
      const SizedBox(height: 8),
      Text("Enter a teacher's name in the search box above",
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
    ]),
  );

  Widget _noResultsState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.person_off_outlined, size: 80, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      Text('No Teachers Found',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600,
              color: Colors.grey.shade600)),
      const SizedBox(height: 8),
      Text('No teachers match "$_searchQuery"',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
    ]),
  );

  Widget _errorState(String error) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
      const SizedBox(height: 16),
      Text('Error Loading Teachers',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600,
              color: Colors.red.shade700)),
      const SizedBox(height: 8),
      Text(error,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          textAlign: TextAlign.center),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Teacher card — isolated widget, only rebuilds when selection changes
// ═════════════════════════════════════════════════════════════════════════════

class _TeacherCard extends StatelessWidget {
  final Teacher  teacher;
  final bool     isSelected;
  final VoidCallback onTap;

  const _TeacherCard({
    required this.teacher,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
            colors: [Colors.indigo.shade400, Colors.indigo.shade600])
            : null,
        color:         isSelected ? null : Colors.white,
        borderRadius:  BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: isSelected
                ? Colors.indigo.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: isSelected ? 12 : 8,
            offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              // Avatar
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person, size: 30,
                    color: isSelected ? Colors.white : Colors.indigo.shade600),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(teacher.name,
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    _iconRow(Icons.email_outlined, teacher.email, isSelected),
                    const SizedBox(height: 2),
                    _iconRow(Icons.phone_outlined, teacher.phone, isSelected),
                  ],
                ),
              ),
              Icon(isSelected ? Icons.expand_less : Icons.expand_more,
                  color: isSelected ? Colors.white : Colors.grey.shade400,
                  size: 26),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _iconRow(IconData icon, String text, bool selected) => Row(children: [
    Icon(icon, size: 13,
        color: selected ? Colors.white.withOpacity(0.8) : Colors.grey.shade500),
    const SizedBox(width: 5),
    Flexible(child: Text(text,
        style: TextStyle(fontSize: 13,
            color: selected
                ? Colors.white.withOpacity(0.9) : Colors.grey.shade600),
        overflow: TextOverflow.ellipsis)),
  ]);
}

// ═════════════════════════════════════════════════════════════════════════════
// Schedule section — own StreamBuilder so teacher card never waits for it
// ═════════════════════════════════════════════════════════════════════════════

class _ScheduleSection extends StatelessWidget {
  final Teacher         teacher;
  final ScheduleService scheduleService;

  const _ScheduleSection({
    required this.teacher,
    required this.scheduleService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClassSchedule>>(
      // Filtered server-side by teacherId — no need to load all schedules
      stream: scheduleService.getSchedulesByTeacher(teacher.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return _errorBox(snap.error.toString());
        }

        final schedules = snap.data ?? [];

        if (schedules.isEmpty) return _noClassesBox(teacher.name);

        // Group schedules by category for organised display
        final grouped = <String, List<ClassSchedule>>{};
        for (final s in schedules) {
          final key = s.categoryName?.isNotEmpty == true
              ? s.categoryName!
              : 'Uncategorised';
          grouped.putIfAbsent(key, () => []).add(s);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.class_, size: 22, color: Colors.indigo.shade700),
              const SizedBox(width: 10),
              Text("${teacher.name}'s Classes",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade900)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.indigo.shade100)),
                child: Text('${schedules.length} class${schedules.length == 1 ? '' : 'es'}',
                    style: TextStyle(fontSize: 12, color: Colors.indigo.shade700,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 16),

            // Render each category group
            for (final entry in grouped.entries) ...[
              if (grouped.length > 1) ...[
                _categoryGroupHeader(entry.key),
                const SizedBox(height: 8),
              ],
              ...entry.value.asMap().entries.map((e) =>
                  _ClassCard(schedule: e.value, index: e.key)),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  Widget _categoryGroupHeader(String name) => Row(children: [
    Icon(Icons.category_outlined, size: 14, color: Colors.indigo.shade400),
    const SizedBox(width: 6),
    Text(name,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: Colors.indigo.shade600)),
    const SizedBox(width: 8),
    Expanded(child: Divider(color: Colors.indigo.shade100)),
  ]);

  Widget _noClassesBox(String name) => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200)),
    child: Center(child: Column(children: [
      Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
      const SizedBox(height: 16),
      Text('No Classes Assigned',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
              color: Colors.grey.shade700)),
      const SizedBox(height: 8),
      Text('$name has no scheduled classes',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
    ])),
  );

  Widget _errorBox(String error) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200)),
    child: Row(children: [
      Icon(Icons.error_outline, color: Colors.red.shade400),
      const SizedBox(width: 10),
      Expanded(child: Text(error,
          style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Class card — stateless, const-friendly
// ═════════════════════════════════════════════════════════════════════════════

class _ClassCard extends StatelessWidget {
  final ClassSchedule schedule;
  final int           index;

  const _ClassCard({required this.schedule, required this.index});

  static const _gradients = [
    [Color(0xFF3F51B5), Color(0xFF283593)], // indigo
    [Color(0xFF7B1FA2), Color(0xFF4A148C)], // purple
    [Color(0xFF00838F), Color(0xFF006064)], // cyan
    [Color(0xFF2E7D32), Color(0xFF1B5E20)], // green
  ];

  @override
  Widget build(BuildContext context) {
    final isNavttc = schedule.classType == ClassType.navttc;
    final g        = isNavttc
        ? const [Color(0xFF2E7D32), Color(0xFF1B5E20)]
        : _gradients[index % _gradients.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
            colors: g),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: g[0].withOpacity(0.3),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: batch name + type badges
            Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.class_, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(schedule.batchName,
                  style: const TextStyle(fontSize: 18,
                      fontWeight: FontWeight.bold, color: Colors.white))),
              // NAVTTC badge
              if (isNavttc) _badge('NAVTTC', Colors.white.withOpacity(0.25)),
            ]),

            // Category badge
            if (schedule.categoryName?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.category_outlined,
                    size: 12, color: Colors.white.withOpacity(0.8)),
                const SizedBox(width: 5),
                Text(schedule.categoryName!,
                    style: TextStyle(fontSize: 11,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500)),
              ]),
            ],

            const SizedBox(height: 14),

            // Time slot
            _infoRow(Icons.access_time, schedule.timeSlot),
            const SizedBox(height: 8),

            // Classroom
            _infoRow(Icons.meeting_room, schedule.classroom),
            const SizedBox(height: 14),

            // Days chips
            Wrap(
              spacing: 6, runSpacing: 6,
              children: schedule.days.map((day) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.35), width: 1),
                ),
                child: Text(day,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w600)),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(children: [
    Icon(icon, color: Colors.white.withOpacity(0.85), size: 16),
    const SizedBox(width: 8),
    Expanded(child: Text(text,
        style: TextStyle(fontSize: 15,
            color: Colors.white.withOpacity(0.95),
            fontWeight: FontWeight.w500))),
  ]);

  Widget _badge(String label, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(label,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
            color: Colors.white, letterSpacing: 0.6)),
  );
}