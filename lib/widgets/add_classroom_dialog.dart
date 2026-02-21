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

  late final Stream<List<Classroom>> _classroomsStream;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _classroomsStream = _classroomService.getClassrooms();
  }

  @override
  void dispose() {
    _classroomController.dispose();
    super.dispose();
  }

  // ── Add ───────────────────────────────────────────────────────────────────

  Future<void> _saveClassroom() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _classroomController.text.trim();

    final exists = await _classroomService.classroomExists(name);
    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('Classroom "$name" already exists!'),
          backgroundColor: Colors.orange,
        ));
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _classroomService.addClassroom(Classroom(
        id:        '',
        name:      name,
        capacity:  '',
        location:  '',
        createdAt: DateTime.now(),
      ));
      if (mounted) {
        _classroomController.clear();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('Classroom "$name" added successfully!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('Error saving classroom: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Edit ──────────────────────────────────────────────────────────────────

  Future<void> _editClassroom(Classroom classroom) async {
    final ctrl    = TextEditingController(text: classroom.name);
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        final sw = MediaQuery.of(context).size.width;
        return Dialog(
          insetPadding: sw < 600
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
              : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Icon(Icons.edit, color: Colors.blue.shade600),
                  const SizedBox(width: 10),
                  const Text('Edit Classroom',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 16),
                Form(
                  key: formKey,
                  child: TextFormField(
                    controller:         ctrl,
                    textCapitalization: TextCapitalization.words,
                    autofocus:          true,
                    decoration: InputDecoration(
                      labelText:  'Classroom Name',
                      prefixIcon: Icon(Icons.meeting_room, color: Colors.blue.shade600),
                      border:     OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:  BorderSide(color: Colors.blue.shade600, width: 2),
                      ),
                    ),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name cannot be empty' : null,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child:     const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (formKey.currentState!.validate())
                          Navigator.pop(context, true);
                      },
                      icon:  const Icon(Icons.check, size: 18),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    final newName = ctrl.text.trim();
    if (newName == classroom.name) return;

    try {
      await _classroomService.updateClassroom(classroom.copyWith(name: newName));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('Renamed to "$newName"'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _deleteClassroom(Classroom classroom) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning, color: Colors.orange),
          SizedBox(width: 10),
          Text('Delete Classroom'),
        ]),
        content: Text(
          'Delete "${classroom.name}"?\n\nAny classes assigned to this room will keep their room label but the classroom will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:     const Text('Cancel'),
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

    if (confirmed != true) return;

    try {
      await _classroomService.deleteClassroom(classroom.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('"${classroom.name}" deleted'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth  = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmall      = screenWidth < 600;

    final dialogWidth = isSmall
        ? screenWidth * 0.95
        : screenWidth < 900
        ? screenWidth * 0.7
        : 520.0;

    final padding = isSmall ? 16.0 : 24.0;

    // Cap list height relative to screen so dialog never overflows
    final listMaxHeight = (screenHeight * 0.3).clamp(160.0, 260.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: isSmall
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 16)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:  dialogWidth,
          maxHeight: screenHeight * 0.92,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize:       MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Header ─────────────────────────────────────────────
                  Row(children: [
                    Container(
                      padding:    EdgeInsets.all(isSmall ? 8 : 12),
                      decoration: BoxDecoration(
                        color:        Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.meeting_room,
                          color: Colors.blue.shade600,
                          size:  isSmall ? 26 : 35),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Manage Classroom',
                              style: TextStyle(
                                  fontSize:   isSmall ? 18 : 22,
                                  fontWeight: FontWeight.bold,
                                  color:      Colors.grey.shade800)),
                          Text('Add, edit or remove classrooms',
                              style: TextStyle(
                                  fontSize: isSmall ? 12 : 14,
                                  color:    Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ]),

                  SizedBox(height: isSmall ? 16 : 24),
                  const Divider(),
                  SizedBox(height: isSmall ? 12 : 20),

                  // ── Add field ──────────────────────────────────────────
                  TextFormField(
                    controller:         _classroomController,
                    enabled:            !_isSaving,
                    textCapitalization: TextCapitalization.words,
                    textInputAction:    TextInputAction.done,
                    onFieldSubmitted:   (_) => _isSaving ? null : _saveClassroom(),
                    decoration: InputDecoration(
                      labelText: 'New Classroom Name *',
                      hintText:  'e.g., Room 101, Lab A, Auditorium',
                      prefixIcon: Icon(Icons.meeting_room,
                          color: Colors.blue.shade600),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          BorderSide(color: Colors.blue.shade600, width: 2)),
                      filled:    true,
                      fillColor: Colors.grey.shade50,
                    ),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Please enter a classroom name'
                        : null,
                  ),

                  const SizedBox(height: 12),

                  // ── Add button — full width ────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveClassroom,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                            vertical: isSmall ? 12 : 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        width:  20,
                        height: 20,
                        child:  CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                          AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add, size: 20),
                          const SizedBox(width: 8),
                          Text('Add Classroom',
                              style: TextStyle(
                                  fontSize:   isSmall ? 14 : 16,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: isSmall ? 16 : 24),
                  const Divider(),
                  const SizedBox(height: 12),

                  // ── Existing classrooms list ───────────────────────────
                  StreamBuilder<List<Classroom>>(
                    stream: _classroomsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: Padding(
                                padding: EdgeInsets.all(16),
                                child:   CircularProgressIndicator()));
                      }

                      final classrooms = snapshot.data ?? [];

                      if (classrooms.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('No classrooms added yet',
                                style: TextStyle(
                                    color:     Colors.grey.shade500,
                                    fontStyle: FontStyle.italic)),
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.list_alt,
                                size: 16, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Existing Classrooms (${classrooms.length})',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize:   isSmall ? 13 : 14,
                                  color:      Colors.blue.shade700),
                            ),
                          ]),
                          const SizedBox(height: 10),

                          // Scrollable list — height adapts to screen
                          ConstrainedBox(
                            constraints:
                            BoxConstraints(maxHeight: listMaxHeight),
                            child: ListView.separated(
                              shrinkWrap:  true,
                              itemCount:   classrooms.length,
                              separatorBuilder: (_, __) =>
                                  Divider(height: 1, color: Colors.grey.shade200),
                              itemBuilder: (_, i) {
                                final c = classrooms[i];
                                return ListTile(
                                  dense:          true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: isSmall ? 4 : 8,
                                      vertical:   2),
                                  leading: Container(
                                    padding:    const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color:        Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.meeting_room,
                                        size:  18,
                                        color: Colors.blue.shade600),
                                  ),
                                  title: Text(c.name,
                                      style: TextStyle(
                                          fontSize:   isSmall ? 13 : 14,
                                          fontWeight: FontWeight.w500)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip:   'Edit',
                                        iconSize:  isSmall ? 20 : 24,
                                        icon: Icon(Icons.edit_outlined,
                                            size:  18,
                                            color: Colors.blue.shade500),
                                        onPressed: () => _editClassroom(c),
                                      ),
                                      IconButton(
                                        tooltip:   'Delete',
                                        iconSize:  isSmall ? 20 : 24,
                                        icon: Icon(Icons.delete_outline,
                                            size:  18,
                                            color: Colors.red.shade400),
                                        onPressed: () => _deleteClassroom(c),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // ── Close button ───────────────────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Close',
                          style: TextStyle(fontSize: isSmall ? 14 : 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}