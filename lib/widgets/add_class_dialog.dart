import 'package:flutter/material.dart';
import '../models/teacher.dart';
import '../models/class_schedule.dart';
import '../services/schedule_service.dart';

class AddClassDialog extends StatefulWidget {
  final List<Teacher> teachers;

  const AddClassDialog({Key? key, required this.teachers}) : super(key: key);

  @override
  State<AddClassDialog> createState() => _AddClassDialogState();
}

class _AddClassDialogState extends State<AddClassDialog> {
  final _scheduleService = ScheduleService();
  final _batchController = TextEditingController();
  final _classroomController = TextEditingController();

  int _currentStep = 0;
  Teacher? _selectedTeacher;
  SchedulePattern? _selectedPattern;
  String? _selectedTimeSlot;
  List<String> _availableTimeSlots = [];
  bool _isLoading = false;
  bool _loadingSlots = false;

  @override
  void dispose() {
    _batchController.dispose();
    _classroomController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableSlots() async {
    if (_selectedPattern == null) return;

    setState(() {
      _loadingSlots = true;
    });

    try {
      final slots = await _scheduleService.getAvailableTimeSlots(_selectedPattern!);
      setState(() {
        _availableTimeSlots = slots;
        _selectedTimeSlot = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading slots: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _loadingSlots = false;
      });
    }
  }

  Future<void> _saveSchedule() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final schedule = ClassSchedule(
        id: '',
        teacherId: _selectedTeacher!.id,
        teacherName: _selectedTeacher!.name,
        batchName: _batchController.text.trim(),
        classroom: _classroomController.text.trim(),
        pattern: _selectedPattern!,
        timeSlot: _selectedTimeSlot!,
        days: ClassSchedule.getDaysForPattern(_selectedPattern!),
        createdAt: DateTime.now(),
      );

      await _scheduleService.addSchedule(schedule);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Class scheduled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // AppBar with classroom input
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.add_circle, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Add New Class',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _classroomController,
                    decoration: InputDecoration(
                      labelText: 'Classroom Name',
                      hintText: 'e.g., Room 101, Lab A',
                      prefixIcon: Icon(Icons.meeting_room),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stepper content
            Flexible(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Stepper(
                  currentStep: _currentStep,
                  onStepContinue: () {
                    if (_currentStep == 0 && _selectedTeacher != null) {
                      setState(() => _currentStep++);
                    } else if (_currentStep == 1 && _selectedPattern != null) {
                      _loadAvailableSlots();
                      setState(() => _currentStep++);
                    } else if (_currentStep == 2 && _selectedTimeSlot != null) {
                      setState(() => _currentStep++);
                    } else if (_currentStep == 3 && _batchController.text.trim().isNotEmpty && _classroomController.text.trim().isNotEmpty) {
                      _saveSchedule();
                    }
                  },
                  onStepCancel: () {
                    if (_currentStep > 0) {
                      setState(() => _currentStep--);
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  controlsBuilder: (context, details) {
                    return Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Row(
                        children: [
                          if (_currentStep < 3)
                            ElevatedButton(
                              onPressed: details.onStepContinue,
                              child: Text(_currentStep == 3 ? 'Save' : 'Continue'),
                            ),
                          if (_currentStep == 3)
                            ElevatedButton(
                              onPressed: _isLoading ? null : details.onStepContinue,
                              child: _isLoading
                                  ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                                  : Text('Save Class'),
                            ),
                          SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: _isLoading ? null : details.onStepCancel,
                            child: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
                          ),
                        ],
                      ),
                    );
                  },
                  steps: [
                    // Step 1: Select Teacher
                    Step(
                      title: Text('Select Teacher'),
                      isActive: _currentStep >= 0,
                      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                      content: Column(
                        children: widget.teachers.map((teacher) {
                          return RadioListTile<Teacher>(
                            title: Text(teacher.name),
                            subtitle: Text(teacher.email),
                            value: teacher,
                            groupValue: _selectedTeacher,
                            onChanged: (value) {
                              setState(() {
                                _selectedTeacher = value;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),

                    // Step 2: Select Schedule Pattern
                    Step(
                      title: Text('Select Days Pattern'),
                      isActive: _currentStep >= 1,
                      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                      content: Column(
                        children: SchedulePattern.values.map((pattern) {
                          return RadioListTile<SchedulePattern>(
                            title: Text(ClassSchedule.getPatternLabel(pattern)),
                            subtitle: Text(ClassSchedule.getDaysForPattern(pattern).join(', ')),
                            value: pattern,
                            groupValue: _selectedPattern,
                            onChanged: (value) {
                              setState(() {
                                _selectedPattern = value;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),

                    // Step 3: Select Time Slot
                    Step(
                      title: Text('Select Time Slot'),
                      isActive: _currentStep >= 2,
                      state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                      content: _loadingSlots
                          ? Center(child: CircularProgressIndicator())
                          : _availableTimeSlots.isEmpty
                          ? Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No available time slots for this pattern',
                          style: TextStyle(color: Colors.red),
                        ),
                      )
                          : Column(
                        children: _availableTimeSlots.map((slot) {
                          return RadioListTile<String>(
                            title: Text(slot),
                            value: slot,
                            groupValue: _selectedTimeSlot,
                            onChanged: (value) {
                              setState(() {
                                _selectedTimeSlot = value;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),

                    // Step 4: Enter Batch Name
                    Step(
                      title: Text('Enter Batch Name'),
                      isActive: _currentStep >= 3,
                      state: _currentStep > 3 ? StepState.complete : StepState.indexed,
                      content: TextFormField(
                        controller: _batchController,
                        decoration: InputDecoration(
                          labelText: 'Batch Name',
                          hintText: 'e.g., Batch A, Advanced Java',
                          prefixIcon: Icon(Icons.class_),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}