// widgets/add_category_dialog.dart

import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/category_service.dart';

class AddCategoryDialog extends StatefulWidget {
  const AddCategoryDialog({Key? key}) : super(key: key);

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _service = CategoryService();

  // null = list view | false = add new | ScheduleCategory = edit existing
  Object? _mode;

  late final Stream<List<ScheduleCategory>> _categoriesStream;

  @override
  void initState() {
    super.initState();
    _categoriesStream = _service.getCategories().asBroadcastStream();
  }

  void _openAdd()                       => setState(() => _mode = false);
  void _openEdit(ScheduleCategory cat)  => setState(() => _mode = cat);
  void _closeForm()                     => setState(() => _mode = null);

  Future<void> _delete(ScheduleCategory cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning, color: Colors.orange),
          SizedBox(width: 10),
          Text('Delete Category'),
        ]),
        content: Text(
          'Delete "${cat.name}"?\n\nSchedules linked to this category will '
              'keep their category label but the category will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon:  const Icon(Icons.delete, size: 18),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _service.deleteCategory(cat.id);
      if (mounted) _snack('"${cat.name}" deleted', Colors.green);
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    }
  }

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: color));

  @override
  Widget build(BuildContext context) {
    if (_mode != null) {
      final editing =
      _mode is ScheduleCategory ? _mode as ScheduleCategory : null;
      return _CategoryForm(
        editing:  editing,
        service:  _service,
        onDone:   _closeForm,
        onCancel: _closeForm,
      );
    }

    final sw      = MediaQuery.of(context).size.width;
    final sh      = MediaQuery.of(context).size.height;
    final isMobile = sw < 600;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical:   isMobile ? 24 : 40,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:  isMobile ? double.infinity : 560,
          maxHeight: sh * (isMobile ? 0.92 : 0.85),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Header ───────────────────────────────────────────────────────
          _ListHeader(onClose: () => Navigator.of(context).pop()),

          // ── List ─────────────────────────────────────────────────────────
          Flexible(
            child: StreamBuilder<List<ScheduleCategory>>(
              stream: _categoriesStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator()));
                }

                final cats = snap.data ?? [];

                if (cats.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.category_outlined,
                            size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No categories yet',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey.shade500)),
                        const SizedBox(height: 4),
                        Text('Tap "Add Category" to create one',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade400)),
                      ]),
                    ),
                  );
                }

                return ListView.separated(
                  padding:          EdgeInsets.all(isMobile ? 12 : 16),
                  shrinkWrap:       true,
                  itemCount:        cats.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _CategoryTile(
                    category:  cats[i],
                    isMobile:  isMobile,
                    onEdit:    () => _openEdit(cats[i]),
                    onDelete:  () => _delete(cats[i]),
                  ),
                );
              },
            ),
          ),

          // ── Footer ───────────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
                isMobile ? 12 : 20, 12, isMobile ? 12 : 20, 16),
            decoration: BoxDecoration(
              color:  Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
              borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close', style: TextStyle(fontSize: 15)),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _openAdd,
                icon:  const Icon(Icons.add, size: 18),
                label: Text(isMobile ? 'Add' : 'Add Category'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.indigo.shade700,
                  padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 14 : 20, vertical: 12),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── List header ───────────────────────────────────────────────────────────────

class _ListHeader extends StatelessWidget {
  final VoidCallback onClose;
  const _ListHeader({required this.onClose});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.purple.shade600]),
      borderRadius:
      const BorderRadius.vertical(top: Radius.circular(20)),
    ),
    child: Row(children: [
      Container(
        padding:    const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:        Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.category_outlined,
            color: Colors.white, size: 20),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Text('Manage Categories',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                color: Colors.white)),
      ),
      IconButton(
        onPressed:    onClose,
        icon:         const Icon(Icons.close, color: Colors.white, size: 20),
        visualDensity: VisualDensity.compact,
      ),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Category tile — responsive layout
// ═════════════════════════════════════════════════════════════════════════════

class _CategoryTile extends StatelessWidget {
  final ScheduleCategory category;
  final bool             isMobile;
  final VoidCallback     onEdit, onDelete;

  const _CategoryTile({
    required this.category,
    required this.isMobile,
    required this.onEdit,
    required this.onDelete,
  });

  String _fmtT(int h, int m) {
    final p  = h >= 12 ? 'PM' : 'AM';
    final dh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$dh:${m.toString().padLeft(2, '0')} $p';
  }

  String get _durLabel {
    final d = category.slotDuration;
    return d >= 60
        ? '${d ~/ 60}h${d % 60 > 0 ? ' ${d % 60}m' : ''}'
        : '${d}m';
  }

  @override
  Widget build(BuildContext context) {
    final startStr = _fmtT(category.startHour,  category.startMinute);
    final endStr   = _fmtT(category.endHour,    category.endMinute);
    final slots    = category.timeSlots.length;

    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset:     const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: icon + name + action buttons
          Row(children: [
            Container(
              padding:    EdgeInsets.all(isMobile ? 8 : 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.indigo.shade400, Colors.purple.shade400,
                ]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.category_outlined,
                  color: Colors.white, size: isMobile ? 16 : 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(category.name,
                  style: TextStyle(
                      fontSize:   isMobile ? 13 : 15,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ),
            // Action buttons — always visible, compact on mobile
            IconButton(
              tooltip:      'Edit',
              icon:         Icon(Icons.edit_outlined,
                  size: isMobile ? 18 : 20,
                  color: Colors.indigo.shade400),
              onPressed:    onEdit,
              visualDensity: VisualDensity.compact,
              padding:      EdgeInsets.zero,
              constraints:  const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            IconButton(
              tooltip:      'Delete',
              icon:         Icon(Icons.delete_outline,
                  size: isMobile ? 18 : 20,
                  color: Colors.red.shade400),
              onPressed:    onDelete,
              visualDensity: VisualDensity.compact,
              padding:      EdgeInsets.zero,
              constraints:  const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ]),

          const SizedBox(height: 8),

          // Info chips — wrap freely on any width
          Wrap(spacing: 6, runSpacing: 6, children: [
            _chip(Icons.schedule,
                isMobile ? '$startStr–$endStr' : '$startStr – $endStr',
                Colors.blue),
            _chip(Icons.timelapse, _durLabel, Colors.teal),
            _chip(Icons.view_column,
                '$slots slot${slots == 1 ? '' : 's'}', Colors.purple),
            if (category.hasBreak)
              _chip(Icons.free_breakfast, 'Break', Colors.orange),
          ]),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, MaterialColor color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color:        color.shade50,
      borderRadius: BorderRadius.circular(20),
      border:       Border.all(color: color.shade100),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: color.shade600),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontSize:   10,
              color:      color.shade700,
              fontWeight: FontWeight.w500)),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Multi-step form — Add & Edit, fully responsive
// ═════════════════════════════════════════════════════════════════════════════

class _CategoryForm extends StatefulWidget {
  final ScheduleCategory? editing;
  final CategoryService   service;
  final VoidCallback       onDone, onCancel;

  const _CategoryForm({
    required this.editing,
    required this.service,
    required this.onDone,
    required this.onCancel,
  });

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  final _pageCtrl    = PageController();
  final _nameCtrl    = TextEditingController();
  final _nameFormKey = GlobalKey<FormState>();

  int _step = 0;
  static const int          _totalSteps = 4;
  static const List<String> _stepTitles = [
    'Category Name', 'Day Timing', 'Slot Duration & Break', 'Summary',
  ];

  TimeOfDay _startTime  = const TimeOfDay(hour: 8,  minute: 0);
  TimeOfDay _endTime    = const TimeOfDay(hour: 17, minute: 0);
  int       _slotDur    = 90;
  bool      _hasBreak   = false;
  TimeOfDay _breakStart = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _breakEnd   = const TimeOfDay(hour: 14, minute: 30);
  bool      _saving     = false;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _startTime     = TimeOfDay(hour: e.startHour,      minute: e.startMinute);
      _endTime       = TimeOfDay(hour: e.endHour,        minute: e.endMinute);
      _slotDur       = e.slotDuration;
      _hasBreak      = e.hasBreak;
      _breakStart    = TimeOfDay(hour: e.breakStartHour, minute: e.breakStartMinute);
      _breakEnd      = TimeOfDay(hour: e.breakEndHour,   minute: e.breakEndMinute);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  int    _toMin(TimeOfDay t) => t.hour * 60 + t.minute;
  String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  ScheduleCategory _build(String id) => ScheduleCategory(
    id:               id,
    name:             _nameCtrl.text.trim(),
    startHour:        _startTime.hour,
    startMinute:      _startTime.minute,
    endHour:          _endTime.hour,
    endMinute:        _endTime.minute,
    slotDuration:     _slotDur,
    hasBreak:         _hasBreak,
    breakStartHour:   _breakStart.hour,
    breakStartMinute: _breakStart.minute,
    breakEndHour:     _breakEnd.hour,
    breakEndMinute:   _breakEnd.minute,
    createdAt:        widget.editing?.createdAt ?? DateTime.now(),
  );

  List<String> get _previewSlots => _build('__preview__').timeSlots;

  bool _canContinue() {
    switch (_step) {
      case 0: return _nameCtrl.text.trim().isNotEmpty;
      case 1: return _toMin(_endTime) > _toMin(_startTime);
      case 2:
        if (_hasBreak) {
          return _toMin(_breakStart) > _toMin(_startTime) &&
              _toMin(_breakEnd)   < _toMin(_endTime)   &&
              _toMin(_breakEnd)   > _toMin(_breakStart);
        }
        return true;
      case 3: return true;
      default: return false;
    }
  }

  Future<void> _next() async {
    if (_step == 0 && !_nameFormKey.currentState!.validate()) return;
    if (!_canContinue()) return;
    if (_step == _totalSteps - 1) { await _save(); return; }
    setState(() => _step++);
    _pageCtrl.animateToPage(_step,
        duration: const Duration(milliseconds: 260),
        curve:    Curves.easeInOutCubic);
  }

  void _back() {
    if (_step == 0) { widget.onCancel(); return; }
    setState(() => _step--);
    _pageCtrl.animateToPage(_step,
        duration: const Duration(milliseconds: 260),
        curve:    Curves.easeInOutCubic);
  }

  Future<void> _save() async {
    if (_previewSlots.isEmpty) {
      _snack('These settings produce no valid time slots', Colors.orange);
      return;
    }
    final name = _nameCtrl.text.trim();
    if (!_isEdit) {
      final exists = await widget.service.categoryExists(name);
      if (exists) { _snack('Category "$name" already exists!', Colors.orange); return; }
    }
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await widget.service.updateCategory(_build(widget.editing!.id));
        if (mounted) _snack('Category "$name" updated!', Colors.green);
      } else {
        await widget.service.addCategory(_build(''));
        if (mounted) _snack('Category "$name" added!', Colors.green);
      }
      if (mounted) widget.onDone();
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: color));

  Future<void> _pickTime(
      String label, TimeOfDay initial, ValueChanged<TimeOfDay> onPicked) async {
    final t = await showTimePicker(
        context: context, initialTime: initial, helpText: label);
    if (t != null) setState(() => onPicked(t));
  }

  @override
  Widget build(BuildContext context) {
    final sw       = MediaQuery.of(context).size.width;
    final sh       = MediaQuery.of(context).size.height;
    final isMobile = sw < 600;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 40,
        vertical:   isMobile ? 16 : 40,
      ),
      shape:        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.hardEdge,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:  isMobile ? double.infinity : 560,
          maxHeight: sh * (isMobile ? 0.95 : 0.88),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          _FormHeader(
            isEdit:     _isEdit,
            step:       _step,
            totalSteps: _totalSteps,
            stepTitles: _stepTitles,
            saving:     _saving,
            onCancel:   widget.onCancel,
          ),
          // Dots
          _Dots(step: _step, totalSteps: _totalSteps),
          // Pages
          Flexible(
            child: PageView(
              controller: _pageCtrl,
              physics:    const NeverScrollableScrollPhysics(),
              children: [
                _PageWrap(isMobile: isMobile, child: _StepName(
                  formKey:    _nameFormKey,
                  controller: _nameCtrl,
                  saving:     _saving,
                  onChanged:  () => setState(() {}),
                )),
                _PageWrap(isMobile: isMobile, child: _StepTiming(
                  startTime:   _startTime,
                  endTime:     _endTime,
                  saving:      _saving,
                  isMobile:    isMobile,
                  fmtTime:     _fmtTime,
                  onPickStart: () => _pickTime('Start Time', _startTime,
                          (t) => _startTime = t),
                  onPickEnd:   () => _pickTime('End Time', _endTime,
                          (t) => _endTime = t),
                  isValid: _toMin(_endTime) > _toMin(_startTime),
                )),
                _PageWrap(isMobile: isMobile, child: _StepSlotBreak(
                  slotDuration:  _slotDur,
                  hasBreak:      _hasBreak,
                  breakStart:    _breakStart,
                  breakEnd:      _breakEnd,
                  saving:        _saving,
                  isMobile:      isMobile,
                  fmtTime:       _fmtTime,
                  previewSlots:  _previewSlots,
                  onDuration:    (d) => setState(() => _slotDur = d),
                  onBreakToggle: (v) => setState(() => _hasBreak = v),
                  onPickBStart:  () => _pickTime('Break Start', _breakStart,
                          (t) => _breakStart = t),
                  onPickBEnd:    () => _pickTime('Break End', _breakEnd,
                          (t) => _breakEnd = t),
                )),
                _PageWrap(isMobile: isMobile, child: _StepSummary(
                  category:     _build('__preview__'),
                  previewSlots: _previewSlots,
                )),
              ],
            ),
          ),
          // Actions
          _FormActions(
            step:       _step,
            totalSteps: _totalSteps,
            isEdit:     _isEdit,
            saving:     _saving,
            canContinue: _canContinue(),
            isMobile:   isMobile,
            onBack:     _back,
            onNext:     _next,
          ),
        ]),
      ),
    );
  }
}

// ── Form header ───────────────────────────────────────────────────────────────

class _FormHeader extends StatelessWidget {
  final bool             isEdit, saving;
  final int              step, totalSteps;
  final List<String>     stepTitles;
  final VoidCallback     onCancel;

  const _FormHeader({
    required this.isEdit,
    required this.step,
    required this.totalSteps,
    required this.stepTitles,
    required this.saving,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.purple.shade600]),
    ),
    child: Row(children: [
      Container(
        padding:    const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:        Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.category_outlined,
            color: Colors.white, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isEdit ? 'Edit Category' : 'Add Category',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: Colors.white)),
          Text(
            'Step ${step + 1} of $totalSteps  ·  ${stepTitles[step]}',
            style: const TextStyle(fontSize: 10, color: Colors.white70),
          ),
        ]),
      ),
      IconButton(
        onPressed:    saving ? null : onCancel,
        icon:         const Icon(Icons.close, color: Colors.white, size: 20),
        visualDensity: VisualDensity.compact,
      ),
    ]),
  );
}

// ── Progress dots ─────────────────────────────────────────────────────────────

class _Dots extends StatelessWidget {
  final int step, totalSteps;
  const _Dots({required this.step, required this.totalSteps});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (int i = 0; i < totalSteps; i++) ...[
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width:  i == step ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color:        i <= step ? Colors.indigo.shade500 : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        if (i < totalSteps - 1) const SizedBox(width: 5),
      ],
    ]),
  );
}

// ── Form action bar ───────────────────────────────────────────────────────────

class _FormActions extends StatelessWidget {
  final int        step, totalSteps;
  final bool       isEdit, saving, canContinue, isMobile;
  final VoidCallback onBack, onNext;

  const _FormActions({
    required this.step,
    required this.totalSteps,
    required this.isEdit,
    required this.saving,
    required this.canContinue,
    required this.isMobile,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 20, 10, isMobile ? 12 : 20, 16),
    decoration: BoxDecoration(
      color:  Colors.white,
      border: Border(top: BorderSide(color: Colors.grey.shade100)),
    ),
    child: Row(children: [
      OutlinedButton.icon(
        onPressed: saving ? null : onBack,
        icon:  const Icon(Icons.arrow_back, size: 15),
        label: Text(step == 0 ? 'Cancel' : 'Back'),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16, vertical: 10),
          side:            BorderSide(color: Colors.grey.shade300),
          foregroundColor: Colors.grey.shade700,
        ),
      ),
      const Spacer(),
      FilledButton.icon(
        onPressed: (saving || !canContinue) ? null : onNext,
        icon: saving
            ? const SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white)))
            : Icon(
            step == totalSteps - 1
                ? Icons.check_circle_outline
                : Icons.arrow_forward,
            size: 15),
        label: Text(
          step == totalSteps - 1
              ? (isMobile
              ? (isEdit ? 'Save' : 'Save')
              : (isEdit ? 'Save Changes' : 'Save Category'))
              : 'Continue',
        ),
        style: FilledButton.styleFrom(
          backgroundColor:         Colors.indigo.shade700,
          padding:                 EdgeInsets.symmetric(
              horizontal: isMobile ? 14 : 20, vertical: 10),
          disabledBackgroundColor: Colors.grey.shade200,
        ),
      ),
    ]),
  );
}

// ── Page wrapper ──────────────────────────────────────────────────────────────

class _PageWrap extends StatelessWidget {
  final Widget child;
  final bool   isMobile;
  const _PageWrap({required this.child, required this.isMobile});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24, 14, isMobile ? 16 : 24, 8),
    child: child,
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Step 0 — Name
// ═════════════════════════════════════════════════════════════════════════════

class _StepName extends StatelessWidget {
  final GlobalKey<FormState>  formKey;
  final TextEditingController controller;
  final bool                  saving;
  final VoidCallback          onChanged;

  const _StepName({
    required this.formKey,
    required this.controller,
    required this.saving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(Icons.label_outline, 'Category Name', Colors.indigo),
      const SizedBox(height: 6),
      Text('Give this schedule category a descriptive name.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      const SizedBox(height: 14),
      TextFormField(
        controller:         controller,
        enabled:            !saving,
        autofocus:          true,
        textCapitalization: TextCapitalization.words,
        onChanged:          (_) => onChanged(),
        decoration: InputDecoration(
          hintText:   'e.g. Morning Batch, Evening Program',
          prefixIcon: Icon(Icons.label, color: Colors.indigo.shade600),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.indigo.shade600, width: 2)),
          filled:    true,
          fillColor: Colors.grey.shade50,
        ),
        validator: (v) =>
        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: Colors.indigo.shade100),
        ),
        child: Row(children: [
          Icon(Icons.info_outline, size: 14, color: Colors.indigo.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Categories let you define custom timing and slot durations '
                  'for different programs (e.g. morning vs evening schedules).',
              style: TextStyle(fontSize: 11, color: Colors.indigo.shade700),
            ),
          ),
        ]),
      ),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Step 1 — Day Timing
// ═════════════════════════════════════════════════════════════════════════════

class _StepTiming extends StatelessWidget {
  final TimeOfDay  startTime, endTime;
  final bool       saving, isValid, isMobile;
  final String Function(TimeOfDay) fmtTime;
  final VoidCallback onPickStart, onPickEnd;

  const _StepTiming({
    required this.startTime,
    required this.endTime,
    required this.saving,
    required this.isValid,
    required this.isMobile,
    required this.fmtTime,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    // On very narrow screens stack time tiles vertically
    final tiles = [
      Expanded(child: _timeTile('Start Time', startTime, Colors.blue,
          saving, fmtTime, onPickStart)),
      SizedBox(width: isMobile ? 0 : 12, height: isMobile ? 10 : 0),
      Expanded(child: _timeTile('End Time', endTime, Colors.red,
          saving, fmtTime, onPickEnd)),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(Icons.schedule, 'Day Timing', Colors.blue),
      const SizedBox(height: 6),
      Text('Set when the day starts and ends for this category.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      const SizedBox(height: 18),
      isMobile
          ? Column(children: tiles)
          : Row(children: tiles),
      const SizedBox(height: 16),
      if (!isValid)
        _warningBox('End time must be after start time.')
      else
        Builder(builder: (_) {
          final totalMin = endTime.hour * 60 + endTime.minute -
              (startTime.hour * 60 + startTime.minute);
          final h = totalMin ~/ 60, m = totalMin % 60;
          final label = h > 0
              ? '$h hr${h > 1 ? 's' : ''}${m > 0 ? ' $m min' : ''}'
              : '$m min';
          return _infoBox('Total day length: $label', Colors.blue);
        }),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Step 2 — Slot Duration & Break
// ═════════════════════════════════════════════════════════════════════════════

class _StepSlotBreak extends StatelessWidget {
  final int      slotDuration;
  final bool     hasBreak, saving, isMobile;
  final TimeOfDay breakStart, breakEnd;
  final String Function(TimeOfDay) fmtTime;
  final List<String>   previewSlots;
  final ValueChanged<int>  onDuration;
  final ValueChanged<bool> onBreakToggle;
  final VoidCallback onPickBStart, onPickBEnd;

  const _StepSlotBreak({
    required this.slotDuration,
    required this.hasBreak,
    required this.saving,
    required this.isMobile,
    required this.breakStart,
    required this.breakEnd,
    required this.fmtTime,
    required this.previewSlots,
    required this.onDuration,
    required this.onBreakToggle,
    required this.onPickBStart,
    required this.onPickBEnd,
  });

  @override
  Widget build(BuildContext context) {
    const options = [30, 45, 60, 90, 120];

    final breakTiles = [
      Expanded(child: _timeTile('Break Start', breakStart, Colors.orange,
          saving, fmtTime, onPickBStart)),
      SizedBox(width: isMobile ? 0 : 12, height: isMobile ? 10 : 0),
      Expanded(child: _timeTile('Break End', breakEnd, Colors.orange,
          saving, fmtTime, onPickBEnd)),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(Icons.timelapse, 'Slot Duration', Colors.teal),
      const SizedBox(height: 6),
      Text('How long is each class slot?',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: options.map((min) {
          final sel   = slotDuration == min;
          final label = min >= 60
              ? '${min ~/ 60}h${min % 60 > 0 ? ' ${min % 60}m' : ''}'
              : '${min}m';
          return ChoiceChip(
            label:    Text(label),
            selected: sel,
            onSelected: saving ? null : (_) => onDuration(min),
            selectedColor: Colors.teal.shade100,
            labelStyle: TextStyle(
              color:      sel ? Colors.teal.shade800 : Colors.grey.shade700,
              fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
            ),
            side: BorderSide(
                color: sel ? Colors.teal.shade400 : Colors.grey.shade300),
          );
        }).toList(),
      ),
      const SizedBox(height: 20),
      const Divider(),
      const SizedBox(height: 12),
      _label(Icons.free_breakfast, 'Break (optional)', Colors.orange),
      const SizedBox(height: 4),
      SwitchListTile(
        value:    hasBreak,
        onChanged: saving ? null : onBreakToggle,
        title: Text(
          hasBreak ? 'Break enabled' : 'No break',
          style: TextStyle(
            fontSize:   13,
            fontWeight: FontWeight.w500,
            color: hasBreak ? Colors.orange.shade800 : Colors.grey.shade500,
          ),
        ),
        activeColor:    Colors.orange,
        contentPadding: EdgeInsets.zero,
      ),
      if (hasBreak) ...[
        const SizedBox(height: 8),
        isMobile
            ? Column(children: breakTiles)
            : Row(children: breakTiles),
        const SizedBox(height: 12),
      ],
      const SizedBox(height: 12),
      const Divider(),
      const SizedBox(height: 12),
      _label(Icons.preview, 'Slot Preview', Colors.purple),
      const SizedBox(height: 8),
      _slotPreview(previewSlots),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Step 3 — Summary
// ═════════════════════════════════════════════════════════════════════════════

class _StepSummary extends StatelessWidget {
  final ScheduleCategory category;
  final List<String>     previewSlots;

  const _StepSummary({
    required this.category,
    required this.previewSlots,
  });

  String _fmtT(int h, int m) {
    final p  = h >= 12 ? 'PM' : 'AM';
    final dh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$dh:${m.toString().padLeft(2, '0')} $p';
  }

  @override
  Widget build(BuildContext context) {
    final durLabel = category.slotDuration >= 60
        ? '${category.slotDuration ~/ 60}h'
        '${category.slotDuration % 60 > 0 ? ' ${category.slotDuration % 60}m' : ''}'
        : '${category.slotDuration}m';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(Icons.check_circle_outline, 'Review & Confirm', Colors.green),
      const SizedBox(height: 6),
      Text('Confirm the settings before saving.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      const SizedBox(height: 16),
      Container(
        width:   double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: Colors.grey.shade200),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _summaryRow(Icons.label,    'Name',  category.name, Colors.indigo),
          const Divider(height: 16),
          _summaryRow(Icons.schedule, 'Start',
              _fmtT(category.startHour, category.startMinute), Colors.blue),
          _summaryRow(Icons.schedule, 'End',
              _fmtT(category.endHour,   category.endMinute),   Colors.red),
          const Divider(height: 16),
          _summaryRow(Icons.timelapse,   'Slot Duration', durLabel, Colors.teal),
          _summaryRow(Icons.view_column, 'Total Slots',
              '${previewSlots.length} slot${previewSlots.length == 1 ? '' : 's'}',
              Colors.purple),
          if (category.hasBreak) ...[
            const Divider(height: 16),
            _summaryRow(Icons.free_breakfast, 'Break',
                '${_fmtT(category.breakStartHour, category.breakStartMinute)}'
                    ' – ${_fmtT(category.breakEndHour, category.breakEndMinute)}',
                Colors.orange),
          ],
        ]),
      ),
      const SizedBox(height: 16),
      _slotPreview(previewSlots),
    ]);
  }

  Widget _summaryRow(
      IconData icon, String label, String value, MaterialColor color) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 14, color: color.shade500),
          const SizedBox(width: 8),
          Text('$label: ',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                    color:      Colors.grey.shade800),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// Shared micro-widgets
// ═════════════════════════════════════════════════════════════════════════════

Widget _label(IconData icon, String text, MaterialColor color) =>
    Row(children: [
      Icon(icon, size: 14, color: color.shade700),
      const SizedBox(width: 6),
      Text(text,
          style: TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.w600,
              color:      Colors.grey.shade700)),
    ]);

Widget _timeTile(
    String label, TimeOfDay time, MaterialColor color,
    bool saving, String Function(TimeOfDay) fmtTime, VoidCallback onTap,
    ) =>
    InkWell(
      onTap:        saving ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:        color.shade50,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: color.shade200),
        ),
        child: Row(children: [
          Icon(Icons.access_time, size: 16, color: color.shade600),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: color.shade600,
                    fontWeight: FontWeight.w500)),
            Text(fmtTime(time),
                style: TextStyle(
                    fontSize:   14,
                    fontWeight: FontWeight.bold,
                    color:      color.shade800)),
          ]),
        ]),
      ),
    );

Widget _slotPreview(List<String> slots) {
  if (slots.isEmpty) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: Colors.orange.shade200),
      ),
      child: Row(children: [
        Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text('No slots generated — adjust times or duration.',
            style: TextStyle(fontSize: 12, color: Colors.orange.shade800))),
      ]),
    );
  }
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color:        Colors.purple.shade50,
      borderRadius: BorderRadius.circular(8),
      border:       Border.all(color: Colors.purple.shade100),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${slots.length} slot${slots.length == 1 ? '' : 's'} generated:',
          style: TextStyle(
              fontSize: 11, color: Colors.purple.shade700,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6, runSpacing: 6,
        children: slots.map((s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(6),
            border:       Border.all(color: Colors.purple.shade200),
          ),
          child: Text(s,
              style: TextStyle(fontSize: 11, color: Colors.purple.shade800)),
        )).toList(),
      ),
    ]),
  );
}

Widget _infoBox(String text, MaterialColor color) => Container(
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(
    color:        color.shade50,
    borderRadius: BorderRadius.circular(8),
    border:       Border.all(color: color.shade100),
  ),
  child: Row(children: [
    Icon(Icons.info_outline, size: 13, color: color.shade600),
    const SizedBox(width: 7),
    Expanded(child: Text(text,
        style: TextStyle(fontSize: 11, color: color.shade800))),
  ]),
);

Widget _warningBox(String text) => Container(
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(
    color:        Colors.orange.shade50,
    borderRadius: BorderRadius.circular(8),
    border:       Border.all(color: Colors.orange.shade200),
  ),
  child: Row(children: [
    Icon(Icons.warning_amber, size: 13, color: Colors.orange.shade700),
    const SizedBox(width: 7),
    Expanded(child: Text(text,
        style: TextStyle(fontSize: 11, color: Colors.orange.shade800))),
  ]),
);