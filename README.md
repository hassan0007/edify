
## 🎓 Academic Timetable Management System
A sophisticated Flutter application built for real-time academic scheduling. This system eliminates manual scheduling errors by providing a logic-based interface for managing teachers, classrooms, and course categories with an automated slot-generation engine.

## ✨ Key Features
## 📅 Intelligent Class Scheduling
Automated Slot Generation: Users define a "Category" with specific start/end times and slot durations; the system then automatically generates available time blocks.

Conflict Prevention: When adding a new class, the system intelligently hides slots that are already occupied by another teacher or classroom, ensuring no double-booking occurs.

Flexible Day Formats: Supports multiple academic cycles, including:

5-Day: Monday – Friday.

6-Day: Monday – Saturday.

Alternating: Mon/Wed/Fri or Tue/Thu/Sat.

Streamlined Workflow: A simple 5-step creation process (Add Category ➔ Add Teacher ➔ Add Classroom ➔ Select Slots➔ Create Class).

## 🔍 Advanced Teacher Analytics
Centralized Teacher Directory: A dedicated second screen listing all faculty members with integrated search functionality.

Individual Schedules: Clicking on a specific teacher instantly displays their complete, filtered class schedule across the entire week.

## 🛠️ Administrative Control Panel
Dynamic Management: Dedicated buttons to manage Teachers, Classrooms, Categories, and Classes.

Global Filtering: Powerful filter options to sort the main schedule by specific teachers, categories, or classrooms.

Export Capabilities: Support for exporting schedules to PDF for physical distribution.

## 🚀 Technical Highlights
Frontend: Flutter (High-performance UI for Web/Desktop).

Real-time Engine: Firebase Realtime Database for instant synchronization of schedule changes across all administrative devices.

Logic Layer: Custom conditions for calculating and validating time-slot availability based on duration and existing entries.
