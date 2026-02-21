// models/category.dart

class ScheduleCategory {
  final String   id;
  final String   name;
  final int      startHour;
  final int      startMinute;
  final int      endHour;
  final int      endMinute;
  final int      slotDuration;    // minutes
  final bool     hasBreak;
  final int      breakStartHour;
  final int      breakStartMinute;
  final int      breakEndHour;
  final int      breakEndMinute;
  final DateTime createdAt;

  const ScheduleCategory({
    required this.id,
    required this.name,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.slotDuration,
    this.hasBreak            = false,
    this.breakStartHour      = 14,
    this.breakStartMinute    = 0,
    this.breakEndHour        = 14,
    this.breakEndMinute      = 30,
    required this.createdAt,
  });

  // ── Computed helpers ──────────────────────────────────────────────────────

  int get startTotal      => startHour * 60 + startMinute;
  int get endTotal        => endHour   * 60 + endMinute;
  int get breakStartTotal => breakStartHour * 60 + breakStartMinute;
  int get breakEndTotal   => breakEndHour   * 60 + breakEndMinute;

  List<String> get timeSlots {
    final slots = <String>[];
    int cur = startTotal;

    while (cur < endTotal) {
      final end = cur + slotDuration;

      if (hasBreak) {
        if (cur >= breakStartTotal && cur < breakEndTotal) {
          cur = breakEndTotal;
          continue;
        }
        if (cur < breakStartTotal && end > breakStartTotal) {
          cur = breakEndTotal;
          continue;
        }
      }

      if (end <= endTotal) {
        slots.add('${_fmt(cur)}-${_fmt(end)}');
        cur = end;
      } else {
        break;
      }
    }
    return slots;
  }

  static String _fmt(int m) {
    final h   = m ~/ 60;
    final min = m % 60;
    final p   = h >= 12 ? 'PM' : 'AM';
    final dh  = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$dh:${min.toString().padLeft(2, '0')} $p';
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    // All primitive types — no nulls, no Lists — fully RTDB-safe.
    'name':               name,
    'startHour':          startHour,
    'startMinute':        startMinute,
    'endHour':            endHour,
    'endMinute':          endMinute,
    'slotDuration':       slotDuration,
    'hasBreak':           hasBreak,
    'breakStartHour':     breakStartHour,
    'breakStartMinute':   breakStartMinute,
    'breakEndHour':       breakEndHour,
    'breakEndMinute':     breakEndMinute,
    'createdAt':          createdAt.toIso8601String(),
  };

  factory ScheduleCategory.fromMap(String id, Map<String, dynamic> map) =>
      ScheduleCategory(
        id:               id,
        name:             map['name']              as String,
        startHour:        (map['startHour']        as num).toInt(),
        startMinute:      (map['startMinute']      as num).toInt(),
        endHour:          (map['endHour']          as num).toInt(),
        endMinute:        (map['endMinute']        as num).toInt(),
        slotDuration:     (map['slotDuration']     as num).toInt(),
        hasBreak:         (map['hasBreak']         as bool?) ?? false,
        breakStartHour:   (map['breakStartHour']   as num?)?.toInt() ?? 14,
        breakStartMinute: (map['breakStartMinute'] as num?)?.toInt() ?? 0,
        breakEndHour:     (map['breakEndHour']     as num?)?.toInt() ?? 14,
        breakEndMinute:   (map['breakEndMinute']   as num?)?.toInt() ?? 30,
        createdAt:        DateTime.parse(map['createdAt'] as String),
      );

  ScheduleCategory copyWith({
    String?   id,
    String?   name,
    int?      startHour,
    int?      startMinute,
    int?      endHour,
    int?      endMinute,
    int?      slotDuration,
    bool?     hasBreak,
    int?      breakStartHour,
    int?      breakStartMinute,
    int?      breakEndHour,
    int?      breakEndMinute,
    DateTime? createdAt,
  }) => ScheduleCategory(
    id:               id               ?? this.id,
    name:             name             ?? this.name,
    startHour:        startHour        ?? this.startHour,
    startMinute:      startMinute      ?? this.startMinute,
    endHour:          endHour          ?? this.endHour,
    endMinute:        endMinute        ?? this.endMinute,
    slotDuration:     slotDuration     ?? this.slotDuration,
    hasBreak:         hasBreak         ?? this.hasBreak,
    breakStartHour:   breakStartHour   ?? this.breakStartHour,
    breakStartMinute: breakStartMinute ?? this.breakStartMinute,
    breakEndHour:     breakEndHour     ?? this.breakEndHour,
    breakEndMinute:   breakEndMinute   ?? this.breakEndMinute,
    createdAt:        createdAt        ?? this.createdAt,
  );
}