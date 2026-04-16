import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'style.dart';
import 'today_report.dart';   // 일일 리포트 파일 연결
import 'monthly_report.dart'; // 월간 리포트 파일 연결

class ReportView extends StatefulWidget {
  const ReportView({super.key});

  @override
  _ReportViewState createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // 달력 위젯
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: TableCalendar(
                firstDay: DateTime.utc(2025, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  // 날짜 클릭 시 일일 리포트로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TodayReportView(date: selectedDay)),
                  );
                },
                calendarStyle: const CalendarStyle(
                  selectedDecoration: BoxDecoration(color: TColor.buttonGreen, shape: BoxShape.circle),
                  todayDecoration: BoxDecoration(color: TColor.lightGreen, shape: BoxShape.circle),
                ),
                headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
              ),
            ),
            const SizedBox(height: 32),
            // 월간 리포트 이동 버튼
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: TColor.buttonGreen,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MonthlyReportView()),
                );
              },
              child: const Text("이달의 월간 리포트", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}