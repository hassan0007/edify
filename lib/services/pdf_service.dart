import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/class_schedule.dart';
import 'package:intl/intl.dart';

class PdfService {
  Future<void> generateSchedulePdf(List<ClassSchedule> schedules) async {
    final pdf = pw.Document();

    // Group schedules by day
    Map<String, List<ClassSchedule>> schedulesByDay = {};
    List<String> allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    for (var day in allDays) {
      schedulesByDay[day] = [];
    }

    for (var schedule in schedules) {
      for (var day in schedule.days) {
        schedulesByDay[day]!.add(schedule);
      }
    }

    // Sort schedules by time within each day
    for (var day in schedulesByDay.keys) {
      schedulesByDay[day]!.sort((a, b) => a.timeSlot.compareTo(b.timeSlot));
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              padding: pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue700,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Center(
                child: pw.Text(
                  'Institute Weekly Schedule',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            // Generated date
            pw.Text(
              'Generated: ${DateFormat('MMMM dd, yyyy - hh:mm a').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),

            // Schedule for each day
            ...allDays.map((day) {
              final daySchedules = schedulesByDay[day]!;

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue100,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      day,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 10),

                  if (daySchedules.isEmpty)
                    pw.Padding(
                      padding: pw.EdgeInsets.only(left: 12, bottom: 15),
                      child: pw.Text(
                        'No classes scheduled',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey600,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300),
                      children: [
                        // Header row
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            _buildTableCell('Time', isHeader: true),
                            _buildTableCell('Teacher', isHeader: true),
                            _buildTableCell('Batch', isHeader: true),
                            _buildTableCell('Classroom', isHeader: true),
                          ],
                        ),
                        // Data rows
                        ...daySchedules.map((schedule) => pw.TableRow(
                          children: [
                            _buildTableCell(schedule.timeSlot),
                            _buildTableCell(schedule.teacherName),
                            _buildTableCell(schedule.batchName),
                            _buildTableCell(schedule.classroom),
                          ],
                        )),
                      ],
                    ),
                  pw.SizedBox(height: 20),
                ],
              );
            }).toList(),

            // Footer
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text(
              'Total Classes: ${schedules.length}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ];
        },
      ),
    );

    // Print or download
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 11,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.blue900 : PdfColors.black,
        ),
      ),
    );
  }
}