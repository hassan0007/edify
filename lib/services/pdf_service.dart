import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/class_schedule.dart';
import '../models/category.dart';
import 'package:intl/intl.dart';

class PdfService {
  // ── Global fallback schedule constants ───────────────────────────────────
  static const int _dayStartMinutes   = 11 * 60;       // 11:00 AM
  static const int _breakStartMinutes = 14 * 60;       // 2:00 PM
  static const int _breakEndMinutes   = 14 * 60 + 30;  // 2:30 PM
  static const int _dayEndMinutes     = 19 * 60;       // 7:00 PM
  static const int _slotDuration      = 90;            // minutes

  // ── Public entry point ────────────────────────────────────────────────────

  /// Generates and prints a timetable grid PDF for the given [schedules].
  ///
  /// [classType] controls the header colour and title:
  ///   • [ClassType.regular] → blue theme, "Regular Classes" label
  ///   • [ClassType.navttc]  → green theme, "NAVTTC Classes" label
  ///
  /// [category] — when provided, its full time-slot list is used for columns
  ///   so that every possible slot appears even if no class is scheduled yet.
  ///   When null, the global 11 AM–7 PM / 90-min slot grid is used instead.
  ///
  /// The output is a fixed grid timetable where:
  ///   • Rows    = ALL days (Monday – Saturday), always shown
  ///   • Columns = ALL time slots from the category / global schedule
  ///   • Cells   = Subject / Teacher / Room (empty when no class)
  Future<void> generateSchedulePdf(
      List<ClassSchedule> schedules, {
        ClassType         classType = ClassType.regular,
        ScheduleCategory? category,
      }) async {
    final pdf = pw.Document();

    // ── Theme colours ─────────────────────────────────────────────────────
    final headerBg  = classType == ClassType.navttc
        ? PdfColors.green800 : PdfColors.blue800;
    final dayBg     = classType == ClassType.navttc
        ? PdfColors.green700 : PdfColors.blue700;
    final slotBg    = classType == ClassType.navttc
        ? PdfColors.green50  : PdfColors.blue50;
    final typeLabel = classType == ClassType.navttc
        ? 'NAVTTC Classes' : 'Regular Classes';

    // ── Full time-slot list (ALL slots, not just occupied ones) ───────────
    // Uses the category's defined slots when available; falls back to the
    // global 11 AM–7 PM / 90-min generated grid otherwise.
    final timeSlots = category != null
        ? List<String>.from(category.timeSlots)
        : _generateGlobalTimeSlots();

    // ── Days to show ──────────────────────────────────────────────────────
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
    ];

    // ── Fast lookup: day + timeSlot → ClassSchedule ────────────────────────
    // A cell may have multiple classes; we'll stack them.
    final Map<String, List<ClassSchedule>> lookup = {};
    for (final s in schedules) {
      for (final d in s.days) {
        final key = '$d|${s.timeSlot}';
        lookup.putIfAbsent(key, () => []).add(s);
      }
    }

    // ── Column widths ──────────────────────────────────────────────────────
    // First column = day label (fixed), remaining = one per time slot (flex).
    const double dayColWidth  = 58.0;
    const double slotColWidth = 72.0; // each time-slot column

    // Build column-width map for pw.Table
    final Map<int, pw.TableColumnWidth> colWidths = {
      0: const pw.FixedColumnWidth(dayColWidth),
    };
    for (int i = 0; i < timeSlots.length; i++) {
      colWidths[i + 1] = const pw.FixedColumnWidth(slotColWidth);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 28),

        // ── Page header ───────────────────────────────────────────────────
        header: (pw.Context ctx) => pw.Column(children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: pw.BoxDecoration(
              color: headerBg,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Institute Weekly Timetable',
                        style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white)),
                    pw.SizedBox(height: 3),
                    pw.Text(typeLabel,
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.white)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.white),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      DateFormat('MMM dd, yyyy').format(DateTime.now()),
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
        ]),

        // ── Page footer ───────────────────────────────────────────────────
        footer: (pw.Context ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated: ${DateFormat('MMMM dd, yyyy  hh:mm a').format(DateTime.now())}',
                style: const pw.TextStyle(
                    fontSize: 7, color: PdfColors.grey600),
              ),
              pw.Divider(color: PdfColors.grey400),
              pw.Text(
                'Total classes: ${schedules.length}',
                style: const pw.TextStyle(
                    fontSize: 7, color: PdfColors.grey600),
              ),
            ],
          ),
        ),

        build: (pw.Context ctx) => [
          pw.Table(
            border: pw.TableBorder.all(
              color: PdfColors.grey400,
              width: 0.5,
            ),
            columnWidths: colWidths,
            children: [
              // ── Header row: period numbers + time slots ─────────────────
              pw.TableRow(
                children: [
                  // Top-left empty corner cell
                  _headerCell('Days', bg: headerBg, fg: PdfColors.white,),

                  // One column per time slot
                  ...timeSlots.asMap().entries.map((e) {
                    final periodNum = e.key + 1;
                    final slot      = e.value;
                    return pw.Container(
                      color: headerBg,
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 5, horizontal: 4),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            '$periodNum',
                            style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            slot,
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(
                                fontSize: 7, color: PdfColors.white),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),

              // ── Data rows: one per day ───────────────────────────────────
              ...days.map((day) {
                return pw.TableRow(
                  children: [
                    // Day label cell
                    pw.Container(
                      color: dayBg,
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 6, horizontal: 4),
                      child: pw.Center(
                        child: pw.Text(
                          day,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white),
                        ),
                      ),
                    ),

                    // Time-slot cells for this day
                    ...timeSlots.map((slot) {
                      final key      = '$day|$slot';
                      final classes  = lookup[key] ?? [];
                      final isEvenDay = days.indexOf(day).isEven;
                      final cellBg   = isEvenDay
                          ? PdfColors.white : slotBg;

                      if (classes.isEmpty) {
                        return pw.Container(color: cellBg);
                      }

                      // Stack multiple classes in the same cell
                      return pw.Container(
                        color: cellBg,
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            for (int i = 0; i < classes.length; i++) ...[
                              if (i > 0)
                                pw.Divider(
                                    height: 4,
                                    thickness: 0.5,
                                    color: PdfColors.grey400),
                              _classCell(classes[i]),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Renders Subject / Teacher / Room stacked in a timetable cell.
  pw.Widget _classCell(ClassSchedule s) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          s.batchName,
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black),
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          s.teacherName,
          style: const pw.TextStyle(
              fontSize: 7, color: PdfColors.grey800),
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          s.classroom,
          style: const pw.TextStyle(
              fontSize: 7, color: PdfColors.grey700),
        ),
      ],
    );
  }

  /// Simple bold header cell with custom background / foreground.
  pw.Widget _headerCell(
      String text, {
        PdfColor bg = PdfColors.grey200,
        PdfColor fg = PdfColors.black,
      }) {
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: fg),
        ),
      ),
    );
  }

  // ── Time-slot generation (mirrors ScheduleService logic) ──────────────────

  /// Generates the global fallback slot list: 11 AM to 7 PM, 90-min slots,
  /// skipping the 2:00–2:30 PM prayer break.
  List<String> _generateGlobalTimeSlots() {
    final List<String> slots = [];
    int cur = _dayStartMinutes;

    while (cur < _dayEndMinutes) {
      final end = cur + _slotDuration;

      if (cur >= _breakStartMinutes && cur < _breakEndMinutes) {
        cur = _breakEndMinutes;
        continue;
      }
      if (cur < _breakStartMinutes && end > _breakStartMinutes) {
        cur = _breakEndMinutes;
        continue;
      }
      if (end <= _dayEndMinutes) {
        slots.add('${_minutesToTime(cur)}-${_minutesToTime(end)}');
        cur = end;
      } else {
        break;
      }
    }
    return slots;
  }

  String _minutesToTime(int totalMinutes) {
    final hour        = totalMinutes ~/ 60;
    final minute      = totalMinutes % 60;
    final period      = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }
}