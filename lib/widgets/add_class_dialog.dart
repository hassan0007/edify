import 'package:flutter/material.dart';
import '../models/teacher.dart';
import '../models/class_schedule.dart';
import '../models/classroom.dart';
import '../services/schedule_service.dart';
import '../services/classroom_service.dart';

/// Accepts [existingSchedules] from the caller so it never needs to hit
/// Firebase itself — the HomeScreen's single stream already has the data.
class AddClassDialog extends StatefulWidget {
  final List<Teacher>        teachers;
  final List<ClassSchedule>  existingSchedules; // ← passed in, no extra read

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
  final _batchController  = TextEditingController();

  int              _step             = 0;
  Teacher?         _teacher;
  Classroom?       _classroom;
  SchedulePattern? _pattern;
  String?          _timeSlot;
  List<String>     _availableSlots   = [];
  List<Classroom>  _classrooms       = [];
  bool             _saving           = false;
  bool             _loadingClassrooms = true;

  // ── Constants ─────────────────────────────────────────────────────────────
  static const int _breakStart = 14 * 60;
  static const int _breakEnd   = 14 * 60 + 30;
  static const int _dayStart   = 11 * 60;
  static const int _dayEnd     = 19 * 60;
  static const int _duration   = 90;

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }

  @override
  void dispose() { _batchController.dispose(); super.dispose(); }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<String> _allSlots() {
    final slots = <String>[];
    int cur = _dayStart;
    while (cur < _dayEnd) {
      final end = cur + _duration;
      if (cur >= _breakStart && cur < _breakEnd) { cur = _breakEnd; continue; }
      if (cur < _breakStart && end > _breakStart) { cur = _breakEnd; continue; }
      if (end <= _dayEnd) {
        slots.add('${_fmt(cur)}-${_fmt(end)}'); cur = end;
      } else break;
    }
    return slots;
  }

  String _fmt(int m) {
    final h = m ~/ 60, min = m % 60;
    final p = h >= 12 ? 'PM' : 'AM';
    final dh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$dh:${min.toString().padLeft(2, '0')} $p';
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadClassrooms() async {
    try {
      final list = await _classroomService.getClassrooms().first;
      if (mounted) setState(() { _classrooms = list; _loadingClassrooms = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingClassrooms = false);
    }
  }

  /// Computes available slots synchronously from the already-loaded
  /// existingSchedules — zero extra network calls.
  void _computeAvailableSlots() {
    if (_pattern == null || _teacher == null || _classroom == null) return;

    final days = ClassSchedule.getDaysForPattern(_pattern!);

    final teacherBusy = widget.existingSchedules
        .where((s) => s.teacherId == _teacher!.id &&
        s.days.any((d) => days.contains(d)))
        .map((s) => s.timeSlot).toSet();

    final roomBusy = widget.existingSchedules
        .where((s) => s.classroom == _classroom!.name &&
        s.days.any((d) => days.contains(d)))
        .map((s) => s.timeSlot).toSet();

    final blocked = teacherBusy.union(roomBusy);

    setState(() {
      _availableSlots = _allSlots().where((s) => !blocked.contains(s)).toList();
      _timeSlot = null;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _scheduleService.addSchedule(ClassSchedule(
        id:          '',
        teacherId:   _teacher!.id,
        teacherName: _teacher!.name,
        batchName:   _batchController.text.trim(),
        classroom:   _classroom!.name,
        pattern:     _pattern!,
        timeSlot:    _timeSlot!,
        days:        ClassSchedule.getDaysForPattern(_pattern!),
        createdAt:   DateTime.now(),
      ));
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Class scheduled successfully'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _canContinue() {
    switch (_step) {
      case 0: return _teacher != null && _classroom != null;
      case 1: return _pattern != null;
      case 2: return _timeSlot != null;
      case 3: return _batchController.text.trim().isNotEmpty;
      default: return false;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _header(),
          _breakBanner(),
          Flexible(child: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(24),
              child: Stepper(
                currentStep: _step,
                onStepContinue: () {
                  if (!_canContinue()) return;
                  if (_step < 3) {
                    // Compute slots synchronously when leaving Step 1
                    if (_step == 1) _computeAvailableSlots();
                    setState(() => _step++);
                  } else { _save(); }
                },
                onStepCancel: () {
                  if (_step > 0) setState(() => _step--);
                  else Navigator.of(context).pop();
                },
                controlsBuilder: _controls,
                steps: [
                  _stepTeacherRoom(),
                  _stepPattern(),
                  _stepTimeSlot(),
                  _stepBatchName(),
                ],
              ),
            ),
          )),
        ]),
      ),
    );
  }

  // ── Header / banner ───────────────────────────────────────────────────────

  Widget _header() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.purple.shade600]),
      borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16), topRight: Radius.circular(16)),
    ),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.add_circle, color: Colors.white, size: 28)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add New Class', style: TextStyle(fontSize: 22,
                fontWeight: FontWeight.bold, color: Colors.white)),
            Text('Step ${_step + 1} of 4', style: TextStyle(fontSize: 14,
                color: Colors.white.withOpacity(0.9))),
          ])),
      IconButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: Colors.white)),
    ]),
  );

  Widget _breakBanner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    color: Colors.amber.shade50,
    child: Row(children: [
      Icon(Icons.free_breakfast, size: 16, color: Colors.orange.shade700),
      const SizedBox(width: 8),
      Expanded(child: Text('Break: 2:00 PM – 2:30 PM is not available.',
          style: TextStyle(fontSize: 12, color: Colors.orange.shade900,
              fontWeight: FontWeight.w500))),
    ]),
  );

  Widget _controls(BuildContext ctx, ControlsDetails d) {
    final sm = MediaQuery.of(ctx).size.width < 500;
    return Padding(padding: const EdgeInsets.only(top: 16),
      child: Wrap(spacing: 12, runSpacing: 12, children: [
        ElevatedButton.icon(
          onPressed: (_saving || !_canContinue()) ? null : d.onStepContinue,
          icon: _saving
              ? const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white)))
              : Icon(_step == 3 ? Icons.check : Icons.arrow_forward, size: 18),
          label: Text(_step == 3 ? 'Save Class' : 'Continue'),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600, foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: sm ? 16 : 24, vertical: 12)),
        ),
        OutlinedButton.icon(
          onPressed: _saving ? null : d.onStepCancel,
          icon: const Icon(Icons.arrow_back, size: 18),
          label: Text(_step == 0 ? 'Cancel' : 'Back'),
          style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: sm ? 16 : 24, vertical: 12)),
        ),
      ]),
    );
  }

  // ── Steps ─────────────────────────────────────────────────────────────────

  Step _stepTeacherRoom() => Step(
    title: const Text('Teacher & Classroom'),
    isActive: _step >= 0,
    state: _step > 0 ? StepState.complete : StepState.indexed,
    content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(Icons.person, 'Select Teacher', Colors.blue),
      const SizedBox(height: 8),
      ...widget.teachers.map((t) => Card(margin: const EdgeInsets.only(bottom: 8),
          child: RadioListTile<Teacher>(
            title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(t.email),
            secondary: CircleAvatar(backgroundColor: Colors.blue.shade100,
                child: Icon(Icons.person, color: Colors.blue.shade700)),
            value: t, groupValue: _teacher,
            onChanged: (v) => setState(() => _teacher = v),
          ))),

      const SizedBox(height: 16), const Divider(), const SizedBox(height: 12),
      _label(Icons.meeting_room, 'Select Classroom', Colors.green),
      const SizedBox(height: 8),

      if (_loadingClassrooms)
        const Center(child: CircularProgressIndicator())
      else if (_classrooms.isEmpty)
        _noRoomsWarning()
      else
        ..._classrooms.map((r) => Card(margin: const EdgeInsets.only(bottom: 8),
            child: RadioListTile<Classroom>(
              title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: (r.capacity.isNotEmpty || r.location.isNotEmpty)
                  ? Text([if (r.capacity.isNotEmpty) '${r.capacity} seats',
                if (r.location.isNotEmpty) r.location].join(' • '),
                  style: TextStyle(color: Colors.grey.shade600)) : null,
              secondary: CircleAvatar(backgroundColor: Colors.green.shade100,
                  child: Icon(Icons.meeting_room, color: Colors.green.shade700)),
              value: r, groupValue: _classroom,
              onChanged: (v) => setState(() => _classroom = v),
            ))),

      if (_teacher != null && _classroom != null)
        Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100)),
            child: Row(children: [
              Icon(Icons.info_outline, size: 15, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(child: Text(
                  'Two classes can share a slot only with a different teacher AND different classroom.',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade800))),
            ])),
    ]),
  );

  Step _stepPattern() => Step(
    title: const Text('Select Days Pattern'),
    isActive: _step >= 1,
    state: _step > 1 ? StepState.complete : StepState.indexed,
    content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Choose which days the class meets',
          style: TextStyle(color: Colors.grey.shade600)),
      const SizedBox(height: 12),
      ...SchedulePattern.values.map((p) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: RadioListTile<SchedulePattern>(
            title: Text(ClassSchedule.getPatternLabel(p),
                style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(ClassSchedule.getDaysForPattern(p).join(', '),
                style: TextStyle(color: Colors.blue.shade700)),
            secondary: CircleAvatar(backgroundColor: Colors.purple.shade100,
                child: Icon(Icons.calendar_today, color: Colors.purple.shade700)),
            value: p, groupValue: _pattern,
            onChanged: (v) => setState(() => _pattern = v),
          ))),
    ]),
  );

  Step _stepTimeSlot() => Step(
    title: const Text('Select Time Slot'),
    isActive: _step >= 2,
    state: _step > 2 ? StepState.complete : StepState.indexed,
    content: _availableSlots.isEmpty
        ? _noSlotsWarning()
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 6, runSpacing: 4, children: [
        _chip(Icons.person,       _teacher!.name,  Colors.blue),
        _chip(Icons.meeting_room, _classroom!.name, Colors.green),
        _chip(Icons.calendar_today,
            ClassSchedule.getDaysForPattern(_pattern!).join(', '),
            Colors.purple),
      ]),
      const SizedBox(height: 4),
      Text('Slots blocked by this teacher or room on selected days are hidden.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
      const SizedBox(height: 12),
      ..._availableSlots.map((slot) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: RadioListTile<String>(
            title: Text(slot, style: const TextStyle(
                fontWeight: FontWeight.w500, fontSize: 16)),
            secondary: CircleAvatar(backgroundColor: Colors.teal.shade100,
                child: Icon(Icons.access_time, color: Colors.teal.shade700)),
            value: slot, groupValue: _timeSlot,
            onChanged: (v) => setState(() => _timeSlot = v),
          ))),
    ]),
  );

  Step _stepBatchName() => Step(
    title: const Text('Batch Name'),
    isActive: _step >= 3,
    state: _step > 3 ? StepState.complete : StepState.indexed,
    content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Give this class a name',
          style: TextStyle(color: Colors.grey.shade600)),
      const SizedBox(height: 16),
      TextFormField(
        controller: _batchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Batch Name *', hintText: 'e.g., Batch A, Advanced Java',
          prefixIcon: Icon(Icons.class_, color: Colors.blue.shade600),
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue.shade600, width: 2)),
          filled: true, fillColor: Colors.grey.shade50,
        ),
      ),
      const SizedBox(height: 16),
      // Summary
      Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Summary', style: TextStyle(fontWeight: FontWeight.bold,
              color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          _summaryRow(Icons.person,         'Teacher',   _teacher?.name    ?? '-', Colors.blue),
          _summaryRow(Icons.meeting_room,   'Classroom', _classroom?.name  ?? '-', Colors.green),
          _summaryRow(Icons.calendar_today, 'Days',
              _pattern != null
                  ? ClassSchedule.getDaysForPattern(_pattern!).join(', ') : '-',
              Colors.purple),
          _summaryRow(Icons.access_time, 'Time', _timeSlot ?? '-', Colors.teal),
        ]),
      ),
    ]),
  );

  // ── Small helpers ─────────────────────────────────────────────────────────

  Widget _label(IconData icon, String text, MaterialColor c) =>
      Row(children: [
        Icon(icon, size: 16, color: c.shade700), const SizedBox(width: 6),
        Text(text, style: TextStyle(fontWeight: FontWeight.w600,
            color: Colors.grey.shade700)),
      ]);

  Widget _chip(IconData icon, String label, MaterialColor c) =>
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: c.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.shade200)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 12, color: c.shade700), const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: c.shade800)),
          ]));

  Widget _summaryRow(IconData icon, String label, String val, MaterialColor c) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Icon(icon, size: 14, color: c.shade600), const SizedBox(width: 6),
            Text('$label: ', style: TextStyle(fontSize: 12,
                color: Colors.grey.shade600)),
            Expanded(child: Text(val, style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w500, color: Colors.grey.shade800),
                overflow: TextOverflow.ellipsis)),
          ]));

  Widget _noSlotsWarning() => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200)),
      child: Row(children: [
        Icon(Icons.warning, color: Colors.orange.shade700),
        const SizedBox(width: 12),
        Expanded(child: Text(
            'No available slots for this teacher / classroom / day combination.\n'
                'Try a different classroom or pattern.',
            style: TextStyle(color: Colors.orange.shade900))),
      ]));

  Widget _noRoomsWarning() => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200)),
      child: Column(children: [
        Row(children: [
          Icon(Icons.warning, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          const Expanded(child: Text('No classrooms available. Add one first.')),
        ]),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.meeting_room),
          label: const Text('Go Back to Add Classroom'),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
        ),
      ]));
}