import 'package:flutter/material.dart';
import '../models/classroom.dart';
import '../services/classroom_service.dart';

class AddClassroomDialog extends StatefulWidget {
  const AddClassroomDialog({Key? key}) : super(key: key);

  @override
  State<AddClassroomDialog> createState() => _AddClassroomDialogState();
}

class _AddClassroomDialogState extends State<AddClassroomDialog> {
  final _formKey             = GlobalKey<FormState>();
  final _classroomController = TextEditingController();
  final _classroomService    = ClassroomService();

  // Classrooms loaded ONCE on open — no live stream needed here.
  List<Classroom> _existing = [];
  bool _isSaving    = false;
  bool _loadingList = true;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final list = await _classroomService.getClassrooms().first;
      if (mounted) setState(() { _existing = list; _loadingList = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  @override
  void dispose() {
    _classroomController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _classroomController.text.trim();
    final exists = await _classroomService.classroomExists(name);
    if (exists) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Classroom "$name" already exists!'),
          backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _classroomService.addClassroom(Classroom(
        id: '', name: name, capacity: '', location: '',
        createdAt: DateTime.now(),
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Classroom "$name" added!'),
            backgroundColor: Colors.green));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500, padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header
                Row(children: [
                  Icon(Icons.meeting_room, color: Colors.blue.shade600, size: 35),
                  const SizedBox(width: 16),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Add New Classroom', style: TextStyle(fontSize: 24,
                        fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                    Text('Configure classroom details',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  ])),
                  IconButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close), color: Colors.grey.shade600,
                  ),
                ]),

                const SizedBox(height: 24), const Divider(), const SizedBox(height: 24),

                // Name field
                TextFormField(
                  controller: _classroomController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText:  'Classroom Name *',
                    hintText:   'e.g., Room 101, Lab A',
                    prefixIcon: Icon(Icons.meeting_room, color: Colors.blue.shade600),
                    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue.shade600, width: 2)),
                    filled: true, fillColor: Colors.grey.shade50,
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
                ),

                const SizedBox(height: 20),

                // Existing classrooms — loaded once, no live rebuild
                if (_loadingList)
                  const Center(child: Padding(
                      padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                else if (_existing.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text('Existing Classrooms (${_existing.length})',
                            style: TextStyle(fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700)),
                      ]),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8,
                        children: _existing.take(5).map((r) => Chip(
                          label: Text(r.name, style: const TextStyle(fontSize: 12)),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.blue.shade200),
                        )).toList(),
                      ),
                      if (_existing.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('+ ${_existing.length - 5} more',
                              style: TextStyle(fontSize: 12,
                                  color: Colors.blue.shade600,
                                  fontStyle: FontStyle.italic)),
                        ),
                    ]),
                  ),

                const SizedBox(height: 24),

                // Buttons
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white)))
                        : const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add, size: 20),
                      SizedBox(width: 8),
                      Text('Add Classroom',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ]),
              ]),
        ),
      ),
    );
  }
}