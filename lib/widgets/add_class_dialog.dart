// widgets/add_class_dialog.dart

import 'package:edify/widgets/add_category.dart';
import 'package:flutter/material.dart';
import '../models/teacher.dart';
import '../models/class_schedule.dart';
import '../models/classroom.dart';
import '../models/category.dart';
import '../services/schedule_service.dart';
import '../services/classroom_service.dart';
import '../services/category_service.dart';

class AddClassDialog extends StatefulWidget {
  final List<Teacher>       teachers;
  final List<ClassSchedule> existingSchedules;

  const AddClassDialog({
    Key? key,
    required this.teachers,
    required this.existingSchedules,
  }) : super(key: key);

  @override
  State<AddClassDialog> createState() => _AddClassDialogState();
}

class _AddClassDialogState extends State<AddClassDialog> {
  final _scheduleService  = ScheduleService();
  final _classroomService = ClassroomService();
  final _categoryService  = CategoryService();
  final _batchController  = TextEditingController();
  final _pageController   = PageController();

  int                _step              = 0;
  ScheduleCategory?  _category;
  Teacher?           _teacher;
  Classroom?         _classroom;
  SchedulePattern?   _pattern;
  String?            _timeSlot;
  List<String>       _availableSlots    = [];
  List<Classroom>    _classrooms        = [];
  List<ScheduleCategory> _categories   = [];
  bool               _saving            = false;
  bool               _loadingClassrooms = true;
  bool               _loadingCategories = true;
  ClassType          _classType         = ClassType.regular;

  // 5 steps: Category → Teacher & Room → Days Pattern → Time Slot → Batch Name
  static const _stepTitles = [
    'Select Category',
    'Teacher & Room',
    'Days Pattern',
    'Time Slot',
    'Batch Name',
  ];
  static const int _totalSteps = 5;

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
    _loadCategories();
  }

  @override
  void dispose() {
    _batchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Loaders ───────────────────────────────────────────────────────────────

  Future<void> _loadClassrooms() async {
    try {
      final list = await _classroomService.getClassrooms().first;
      if (mounted) setState(() { _classrooms = list; _loadingClassrooms = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingClassrooms = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final list = await _categoryService.getCategoriesOnce();
      if (mounted) setState(() { _categories = list; _loadingCategories = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _computeAvailableSlots() {
    if (_pattern == null || _teacher == null || _classroom == null || _category == null) return;
    final days = ClassSchedule.getDaysForPattern(_pattern!);
    final allSlots = _category!.timeSlots;
    final busy = {
      ...widget.existingSchedules
          .where((s) => s.teacherId == _teacher!.id && s.days.any(days.contains))
          .map((s) => s.timeSlot),
      ...widget.existingSchedules
          .where((s) => s.classroom == _classroom!.name && s.days.any(days.contains))
          .map((s) => s.timeSlot),
    };
    _availableSlots = allSlots.where((s) => !busy.contains(s)).toList();
    _timeSlot = null;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _scheduleService.addSchedule(ClassSchedule(
        id:           '',
        teacherId:    _teacher!.id,
        teacherName:  _teacher!.name,
        batchName:    _batchController.text.trim(),
        classroom:    _classroom!.name,
        pattern:      _pattern!,
        timeSlot:     _timeSlot!,
        days:         ClassSchedule.getDaysForPattern(_pattern!),
        createdAt:    DateTime.now(),
        classType:    _classType,
        categoryId:   _category!.id,
        categoryName: _category!.name,
      ));
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Class scheduled successfully'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _canContinue() => switch (_step) {
    0 => _category != null,
    1 => _teacher  != null && _classroom != null,
    2 => _pattern  != null,
    3 => _timeSlot != null,
    4 => _batchController.text.trim().isNotEmpty,
    _ => false,
  };

  void _next() {
    if (!_canContinue()) return;
    if (_step == 4) { _save(); return; }
    if (_step == 2) _computeAvailableSlots();
    setState(() => _step++);
    _pageController.animateToPage(_step,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOutCubic);
  }

  void _back() {
    if (_step == 0) { Navigator.of(context).pop(); return; }
    setState(() => _step--);
    _pageController.animateToPage(_step,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOutCubic);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.hardEdge,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:  620,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          RepaintBoundary(child: _Header(step: _step, saving: _saving)),
          _ClassTypeBar(
            classType: _classType,
            saving:    _saving,
            onChanged: (t) => setState(() => _classType = t),
          ),
          _StepDots(current: _step, total: _totalSteps),
          Flexible(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Step 0 — Category
                _PageWrap(child: _StepCategory(
                  categories:      _categories,
                  loading:         _loadingCategories,
                  selected:        _category,
                  onChanged:       (c) => setState(() {
                    _category = c;
                    // Reset downstream when category changes
                    _timeSlot       = null;
                    _availableSlots = [];
                  }),
                  onCategoryAdded: _loadCategories,
                )),
                // Step 1 — Teacher & Room
                _PageWrap(child: _StepTeacherRoom(
                  teachers:        widget.teachers,
                  classrooms:      _classrooms,
                  loadingRooms:    _loadingClassrooms,
                  selectedTeacher: _teacher,
                  selectedRoom:    _classroom,
                  onTeacher:       (t) => setState(() => _teacher   = t),
                  onRoom:          (r) => setState(() => _classroom = r),
                  onGoBack:        () => Navigator.of(context).pop(),
                )),
                // Step 2 — Days Pattern
                _PageWrap(child: _StepPattern(
                  selected:  _pattern,
                  onChanged: (p) => setState(() => _pattern = p),
                )),
                // Step 3 — Time Slot
                _PageWrap(child: _StepTimeSlot(
                  slots:     _availableSlots,
                  selected:  _timeSlot,
                  teacher:   _teacher,
                  room:      _classroom,
                  pattern:   _pattern,
                  category:  _category,
                  onChanged: (s) => setState(() => _timeSlot = s),
                )),
                // Step 4 — Batch Name
                _PageWrap(child: _StepBatchName(
                  controller:   _batchController,
                  classType:    _classType,
                  teacher:      _teacher,
                  room:         _classroom,
                  pattern:      _pattern,
                  timeSlot:     _timeSlot,
                  categoryName: _category?.name,
                  onChanged:    () => setState(() {}),
                )),
              ],
            ),
          ),
          _ActionBar(
            step:        _step,
            totalSteps:  _totalSteps,
            saving:      _saving,
            canContinue: _canContinue(),
            onNext:      _next,
            onBack:      _back,
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ═════════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final int  step;
  final bool saving;
  const _Header({required this.step, required this.saving});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.indigo.shade600]),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.add_circle_outline,
            color: Colors.white, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add New Class',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                  color: Colors.white)),
          Text(
            'Step ${step + 1} of ${_AddClassDialogState._totalSteps}  ·  '
                '${_AddClassDialogState._stepTitles[step]}',
            style: TextStyle(fontSize: 11,
                color: Colors.white.withOpacity(0.85)),
          ),
        ]),
      ),
      IconButton(
        onPressed: saving ? null : () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close, color: Colors.white, size: 20),
        visualDensity: VisualDensity.compact,
      ),
    ]),
  );
}

// ── Class type selector ───────────────────────────────────────────────────────

class _ClassTypeBar extends StatelessWidget {
  final ClassType classType;
  final bool      saving;
  final ValueChanged<ClassType> onChanged;
  const _ClassTypeBar(
      {required this.classType, required this.saving, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isNavttc = classType == ClassType.navttc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isNavttc ? Colors.indigo.shade50 : Colors.blue.shade50,
      child: Row(children: [
        Text('Class Type:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: Colors.grey.shade700)),
        const SizedBox(width: 10),
        _Pill(
          label: 'Regular', icon: Icons.school_outlined,
          selected: !isNavttc,
          activeColor: Colors.blue.shade700,
          activeBg:   Colors.blue.shade100,
          onTap: saving ? null : () => onChanged(ClassType.regular),
        ),
        const SizedBox(width: 6),
        _Pill(
          label: 'NAVTTC', icon: Icons.account_balance_outlined,
          selected: isNavttc,
          activeColor: Colors.indigo.shade700,
          activeBg:   Colors.indigo.shade100,
          onTap: saving ? null : () => onChanged(ClassType.navttc),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String      label;
  final IconData    icon;
  final bool        selected;
  final Color       activeColor, activeBg;
  final VoidCallback? onTap;
  const _Pill({required this.label, required this.icon, required this.selected,
    required this.activeColor, required this.activeBg, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? activeBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: selected ? activeColor : Colors.grey.shade300,
            width: selected ? 1.5 : 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13,
            color: selected ? activeColor : Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? activeColor : Colors.grey.shade600)),
      ]),
    ),
  );
}

// ── Progress dots ─────────────────────────────────────────────────────────────

class _StepDots extends StatelessWidget {
  final int current;
  final int total;
  const _StepDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (int i = 0; i < total; i++) ...[
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width:  i == current ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i <= current
                ? Colors.blue.shade600 : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        if (i < total - 1) const SizedBox(width: 5),
      ],
    ]),
  );
}

// ── Page wrapper ──────────────────────────────────────────────────────────────

class _PageWrap extends StatelessWidget {
  final Widget child;
  const _PageWrap({required this.child});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
    child: child,
  );
}

// ── Action bar ────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final int  step, totalSteps;
  final bool saving, canContinue;
  final VoidCallback onNext, onBack;
  const _ActionBar({required this.step, required this.totalSteps,
    required this.saving, required this.canContinue,
    required this.onNext, required this.onBack});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Colors.grey.shade100)),
    ),
    child: Row(children: [
      OutlinedButton.icon(
        onPressed: saving ? null : onBack,
        icon: const Icon(Icons.arrow_back, size: 15),
        label: Text(step == 0 ? 'Cancel' : 'Back'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          side: BorderSide(color: Colors.grey.shade300),
          foregroundColor: Colors.grey.shade700,
        ),
      ),
      const Spacer(),
      FilledButton.icon(
        onPressed: (saving || !canContinue) ? null : onNext,
        icon: saving
            ? const SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white)))
            : Icon(step == totalSteps - 1
            ? Icons.check_circle_outline : Icons.arrow_forward, size: 15),
        label: Text(step == totalSteps - 1 ? 'Save Class' : 'Continue'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          disabledBackgroundColor: Colors.grey.shade200,
        ),
      ),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Step 0 — Category
// ═════════════════════════════════════════════════════════════════════════════

class _StepCategory extends StatelessWidget {
  final List<ScheduleCategory> categories;
  final bool                   loading;
  final ScheduleCategory?      selected;
  final ValueChanged<ScheduleCategory?> onChanged;
  final VoidCallback onCategoryAdded;

  const _StepCategory({
    required this.categories,
    required this.loading,
    required this.selected,
    required this.onChanged,
    required this.onCategoryAdded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Choose a category for this class',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      const SizedBox(height: 12),

      if (loading)
        const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(strokeWidth: 2)))
      else if (categories.isEmpty)
        _NoCategoriesWarning(onAdd: () async {
          await _openAddCategory(context);
          onCategoryAdded();
        })
      else ...[
          ...categories.map((cat) => _CategoryCard(
            category:   cat,
            selected:   selected?.id == cat.id,
            onTap:      () => onChanged(cat),
          )),
          const SizedBox(height: 12),
          // Add category inline button
          OutlinedButton.icon(
            onPressed: () async {
              await _openAddCategory(context);
              onCategoryAdded();
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add New Category'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.indigo.shade700,
              side: BorderSide(color: Colors.indigo.shade300),
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      const SizedBox(height: 8),
    ]);
  }

  Future<void> _openAddCategory(BuildContext context) async {
    // Import add_category_dialog at top of file
    await showDialog(
      context: context,
      builder: (_) => const AddCategoryDialogWrapper(),
    );
  }
}

/// Thin wrapper so we can import AddCategoryDialog without circular deps.
/// Replace with your actual import path.
class AddCategoryDialogWrapper extends StatelessWidget {
  const AddCategoryDialogWrapper({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    // Import add_category_dialog.dart at the top of this file and
    // replace this with: return const AddCategoryDialog();
    return const AddCategoryDialog();
  }
}

class _CategoryCard extends StatelessWidget {
  final ScheduleCategory category;
  final bool             selected;
  final VoidCallback     onTap;
  const _CategoryCard(
      {required this.category, required this.selected, required this.onTap});

  String _fmtT(int h, int m) {
    final p  = h >= 12 ? 'PM' : 'AM';
    final dh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$dh:${m.toString().padLeft(2, '0')} $p';
  }

  @override
  Widget build(BuildContext context) {
    final slots    = category.timeSlots;
    final startLbl = _fmtT(category.startHour, category.startMinute);
    final endLbl   = _fmtT(category.endHour,   category.endMinute);
    final durLbl   = category.slotDuration >= 60
        ? '${category.slotDuration ~/ 60}h'
        '${category.slotDuration % 60 > 0 ? ' ${category.slotDuration % 60}m' : ''}'
        : '${category.slotDuration}m';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: selected ? 1 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: selected
                ? Colors.indigo.shade400 : Colors.grey.shade200,
            width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // Radio indicator
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected
                        ? Colors.indigo.shade500 : Colors.grey.shade400,
                    width: 2),
              ),
              child: selected
                  ? Center(child: Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.indigo.shade600)))
                  : null,
            ),
            const SizedBox(width: 12),
            // Category icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.indigo.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.category_outlined,
                  size: 18,
                  color: selected
                      ? Colors.indigo.shade600 : Colors.grey.shade400),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.name,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.indigo.shade800 : Colors.grey.shade800)),
                  const SizedBox(height: 2),
                  Text('$startLbl – $endLbl  ·  $durLbl slots  ·  '
                      '${slots.length} time slot${slots.length == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                  if (category.hasBreak) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.free_breakfast,
                          size: 10, color: Colors.orange.shade400),
                      const SizedBox(width: 3),
                      Text(
                        'Break ${_fmtT(category.breakStartHour, category.breakStartMinute)}'
                            ' – ${_fmtT(category.breakEndHour, category.breakEndMinute)}',
                        style: TextStyle(
                            fontSize: 10, color: Colors.orange.shade600),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _NoCategoriesWarning extends StatelessWidget {
  final VoidCallback onAdd;
  const _NoCategoriesWarning({required this.onAdd});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200)),
    child: Column(children: [
      Row(children: [
        Icon(Icons.warning_amber, color: Colors.orange.shade700),
        const SizedBox(width: 10),
        const Expanded(
            child: Text('No categories yet. Create one first.',
                style: TextStyle(fontSize: 13))),
      ]),
      const SizedBox(height: 12),
      ElevatedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add Category'),
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
      ),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Steps 1-4 (unchanged logic, updated numbering)
// ═════════════════════════════════════════════════════════════════════════════

class _StepTeacherRoom extends StatelessWidget {
  final List<Teacher>   teachers;
  final List<Classroom> classrooms;
  final bool            loadingRooms;
  final Teacher?        selectedTeacher;
  final Classroom?      selectedRoom;
  final ValueChanged<Teacher?>   onTeacher;
  final ValueChanged<Classroom?> onRoom;
  final VoidCallback             onGoBack;

  const _StepTeacherRoom({
    required this.teachers, required this.classrooms,
    required this.loadingRooms, required this.selectedTeacher,
    required this.selectedRoom, required this.onTeacher,
    required this.onRoom, required this.onGoBack,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionLabel(icon: Icons.person, text: 'Select Teacher', color: Colors.blue),
      const SizedBox(height: 8),
      ...teachers.map((t) => _RadioCard<Teacher>(
        value: t, groupValue: selectedTeacher,
        title: t.name, subtitle: t.email,
        avatarIcon: Icons.person, avatarColor: Colors.blue,
        onChanged: onTeacher,
      )),
      const SizedBox(height: 14),
      Divider(color: Colors.grey.shade200),
      const SizedBox(height: 10),
      _SectionLabel(icon: Icons.meeting_room, text: 'Select Classroom', color: Colors.green),
      const SizedBox(height: 8),
      if (loadingRooms)
        const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2)))
      else if (classrooms.isEmpty)
        _NoRoomsWarning(onGoBack: onGoBack)
      else
        ...classrooms.map((r) => _RadioCard<Classroom>(
          value: r, groupValue: selectedRoom,
          title: r.name,
          subtitle: [if (r.capacity.isNotEmpty) '${r.capacity} seats',
            if (r.location.isNotEmpty) r.location].join(' • '),
          avatarIcon: Icons.meeting_room, avatarColor: Colors.green,
          onChanged: onRoom,
        )),
      if (selectedTeacher != null && selectedRoom != null)
        _InfoNote(
            text: 'Two classes can share a slot only with a different '
                'teacher AND different classroom.'),
      const SizedBox(height: 8),
    ],
  );
}

class _StepPattern extends StatelessWidget {
  final SchedulePattern?               selected;
  final ValueChanged<SchedulePattern?> onChanged;
  const _StepPattern({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Choose which days the class meets',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      const SizedBox(height: 10),
      ...SchedulePattern.values.map((p) => _RadioCard<SchedulePattern>(
        value: p, groupValue: selected,
        title:    ClassSchedule.getPatternLabel(p),
        subtitle: ClassSchedule.getDaysForPattern(p).join(', '),
        avatarIcon: Icons.calendar_today, avatarColor: Colors.purple,
        onChanged: onChanged,
      )),
      const SizedBox(height: 8),
    ],
  );
}

class _StepTimeSlot extends StatelessWidget {
  final List<String>      slots;
  final String?           selected;
  final Teacher?          teacher;
  final Classroom?        room;
  final SchedulePattern?  pattern;
  final ScheduleCategory? category;
  final ValueChanged<String?> onChanged;
  const _StepTimeSlot({required this.slots, required this.selected,
    required this.teacher, required this.room, required this.pattern,
    required this.category, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) return _NoSlotsWarning();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 5, runSpacing: 4, children: [
        if (category != null)
          _MiniChip(Icons.category_outlined, category!.name, Colors.indigo),
        if (teacher != null)
          _MiniChip(Icons.person, teacher!.name, Colors.blue),
        if (room != null)
          _MiniChip(Icons.meeting_room, room!.name, Colors.green),
        if (pattern != null)
          _MiniChip(Icons.calendar_today,
              ClassSchedule.getDaysForPattern(pattern!).join(', '),
              Colors.purple),
      ]),
      const SizedBox(height: 6),
      Text('Blocked slots are hidden.',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
      const SizedBox(height: 10),
      ...slots.map((slot) => _RadioCard<String>(
        value: slot, groupValue: selected,
        title: slot, subtitle: '',
        avatarIcon: Icons.access_time, avatarColor: Colors.teal,
        onChanged: onChanged,
      )),
      const SizedBox(height: 8),
    ]);
  }
}

class _StepBatchName extends StatelessWidget {
  final TextEditingController controller;
  final ClassType             classType;
  final Teacher?              teacher;
  final Classroom?            room;
  final SchedulePattern?      pattern;
  final String?               timeSlot;
  final String?               categoryName;
  final VoidCallback          onChanged;
  const _StepBatchName({required this.controller, required this.classType,
    required this.teacher, required this.room, required this.pattern,
    required this.timeSlot, required this.categoryName, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Give this class a name',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      const SizedBox(height: 14),
      TextFormField(
        controller: controller,
        onChanged:  (_) => onChanged(),
        autofocus:  true,
        decoration: InputDecoration(
          labelText: 'Batch Name *',
          hintText:  'e.g., Batch A, Advanced Java',
          prefixIcon: Icon(Icons.class_, color: Colors.blue.shade600),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.blue.shade600, width: 2)),
          filled: true, fillColor: Colors.grey.shade50,
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Summary', style: TextStyle(fontWeight: FontWeight.w700,
              fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          if (categoryName != null)
            _SummaryRow(Icons.category_outlined, 'Category',
                categoryName!, Colors.indigo),
          _SummaryRow(
            classType == ClassType.navttc
                ? Icons.account_balance_outlined : Icons.school_outlined,
            'Type',
            ClassSchedule.getClassTypeLabel(classType),
            classType == ClassType.navttc ? Colors.indigo : Colors.blue,
          ),
          _SummaryRow(Icons.person, 'Teacher', teacher?.name ?? '—', Colors.blue),
          _SummaryRow(Icons.meeting_room, 'Room', room?.name ?? '—', Colors.green),
          _SummaryRow(Icons.calendar_today, 'Days',
              pattern != null
                  ? ClassSchedule.getDaysForPattern(pattern!).join(', ')
                  : '—',
              Colors.purple),
          _SummaryRow(Icons.access_time, 'Time', timeSlot ?? '—', Colors.teal),
        ]),
      ),
      const SizedBox(height: 8),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Shared micro-widgets
// ═════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final IconData      icon;
  final String        text;
  final MaterialColor color;
  const _SectionLabel({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: color.shade700),
    const SizedBox(width: 5),
    Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
        color: Colors.grey.shade700)),
  ]);
}

class _RadioCard<T> extends StatelessWidget {
  final T             value;
  final T?            groupValue;
  final String        title, subtitle;
  final IconData      avatarIcon;
  final MaterialColor avatarColor;
  final ValueChanged<T?> onChanged;

  const _RadioCard({required this.value, required this.groupValue,
    required this.title, required this.subtitle,
    required this.avatarIcon, required this.avatarColor,
    required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final sel = value == groupValue;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: sel ? 1 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
            color: sel ? avatarColor.shade400 : Colors.grey.shade200,
            width: sel ? 1.5 : 1),
      ),
      child: RadioListTile<T>(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        value: value, groupValue: groupValue,
        activeColor: avatarColor.shade600,
        title: Text(title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                color: sel ? avatarColor.shade800 : Colors.grey.shade800)),
        subtitle: subtitle.isNotEmpty
            ? Text(subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500))
            : null,
        secondary: CircleAvatar(
          radius: 15,
          backgroundColor: avatarColor.shade50,
          child: Icon(avatarIcon, size: 15, color: avatarColor.shade600),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData      icon;
  final String        label;
  final MaterialColor color;
  const _MiniChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade100)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color.shade600),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 10, color: color.shade700)),
    ]),
  );
}

class _SummaryRow extends StatelessWidget {
  final IconData      icon;
  final String        label, value;
  final MaterialColor color;
  const _SummaryRow(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Icon(icon, size: 12, color: color.shade500),
      const SizedBox(width: 5),
      Text('$label: ',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      Expanded(child: Text(value,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: Colors.grey.shade800),
          overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _InfoNote extends StatelessWidget {
  final String text;
  const _InfoNote({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100)),
    child: Row(children: [
      Icon(Icons.info_outline, size: 13, color: Colors.blue.shade600),
      const SizedBox(width: 7),
      Expanded(child: Text(text,
          style: TextStyle(fontSize: 11, color: Colors.blue.shade800))),
    ]),
  );
}

class _NoSlotsWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200)),
    child: Row(children: [
      Icon(Icons.warning_amber, color: Colors.orange.shade700),
      const SizedBox(width: 10),
      Expanded(child: Text(
          'No available slots for this combination.\n'
              'Try a different classroom or pattern.',
          style: TextStyle(fontSize: 12, color: Colors.orange.shade900))),
    ]),
  );
}

class _NoRoomsWarning extends StatelessWidget {
  final VoidCallback onGoBack;
  const _NoRoomsWarning({required this.onGoBack});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200)),
    child: Column(children: [
      Row(children: [
        Icon(Icons.warning_amber, color: Colors.orange.shade700),
        const SizedBox(width: 10),
        const Expanded(child: Text('No classrooms found. Add one first.',
            style: TextStyle(fontSize: 12))),
      ]),
      const SizedBox(height: 10),
      ElevatedButton.icon(
        onPressed: onGoBack,
        icon: const Icon(Icons.meeting_room, size: 15),
        label: const Text('Go Back'),
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
      ),
    ]),
  );
}

// ── Import this at the top of add_class_dialog.dart ──────────────────────────
// import 'add_category_dialog.dart';
// and replace AddCategoryDialogWrapper with AddCategoryDialog directly.