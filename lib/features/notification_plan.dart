import '../models/course.dart';
import '../models/period_times.dart';
import 'preferences.dart';

class PlannedNotification {
  const PlannedNotification(this.time, this.title, this.body, this.kind);
  final DateTime time;
  final String title, body, kind;
}
class NotificationPlan {
  static List<PlannedNotification> build(List<Course> courses, DateTime semesterStart, int totalWeeks, NotificationPreferences prefs, DateTime now) {
    final output = <PlannedNotification>[];
    // The complete current semester is scheduled; account/cache changes rebuild it.
    final monday = DateTime(semesterStart.year, semesterStart.month, semesterStart.day).subtract(Duration(days: semesterStart.weekday - 1));
    final todayDate = DateTime(now.year, now.month, now.day);
    for (var day = todayDate.isBefore(monday) ? monday : todayDate; day.isBefore(monday.add(Duration(days: totalWeeks * 7))); day = day.add(const Duration(days: 1))) {
      final week = day.difference(monday).inDays ~/ 7 + 1;
      if (day.isBefore(monday) || week > totalWeeks) continue;
      final today = courses.where((c) => c.weekday == day.weekday && c.occursIn(week)).toList()..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));
      if (prefs.morning) {
        final time = DateTime(day.year, day.month, day.day, prefs.morningHour, prefs.morningMinute);
        if (time.isAfter(now)) output.add(PlannedNotification(time, '今日早报 · 第 $week 周', today.isEmpty ? '今天没有课程，安排好自己的时间。' : today.map((c) => '${periodTimes[c.startPeriod - 1][0]} ${c.name} · ${c.room}').join('\n'), 'morning'));
      }
      if (prefs.nextClass) {
        for (final c in today) {
        final clock = periodTimes[c.startPeriod - 1][0].split(':').map(int.parse).toList();
        final time = DateTime(day.year, day.month, day.day, clock[0], clock[1]).subtract(Duration(minutes: prefs.leadMinutes));
        if (time.isAfter(now)) output.add(PlannedNotification(time, '${c.name}即将开始', '${prefs.leadMinutes} 分钟后 · ${c.period} · ${c.room}', 'course'));
        }
      }
    }
    output.sort((a, b) => a.time.compareTo(b.time));
    return output;
  }
}
