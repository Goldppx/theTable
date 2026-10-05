import 'package:flutter/material.dart';

class Course {
  const Course({required this.name, required this.teacher, required this.room,
    required this.weekday, required this.startPeriod, required this.endPeriod,
    this.weeks = const [], this.colorIndex = 0});
  final String name, teacher, room;
  final int weekday, startPeriod, endPeriod, colorIndex;
  /// Empty means every week. Values are explicit, including odd/even weeks.
  final List<int> weeks;
  bool occursIn(int week) => weeks.isEmpty || weeks.contains(week);
  String get period => '第 $startPeriod–$endPeriod 节';
  String get location => room;
  String get weekLabel => weeks.isEmpty ? '每周' : '${weeks.join('、')} 周';
  static const palette = [Color(0xff4033ac), Color(0xffa72e70),
    Color(0xff258e6b), Color(0xff4da52a), Color(0xff9c299e),
    Color(0xff278492), Color(0xffac3036), Color(0xff94ad2f)];
  Color get color => palette[colorIndex.abs() % palette.length];
  Map<String, dynamic> toJson() => {'name': name, 'teacher': teacher,
    'room': room, 'weekday': weekday, 'startPeriod': startPeriod,
    'endPeriod': endPeriod, 'weeks': weeks, 'colorIndex': colorIndex};
  factory Course.fromJson(Map<String, dynamic> data) {
    int number(String key) => int.tryParse('${data[key]}') ?? 0;
    final day = number('weekday'), start = number('startPeriod'), end = number('endPeriod');
    final name = '${data['name'] ?? ''}'.trim();
    final rawWeeks = data['weeks'];
    if (name.isEmpty || day < 1 || day > 7 || start < 1 || end < start || end > 10 ||
        (rawWeeks != null && rawWeeks is! List)) {
      throw const FormatException('课程需包含名称、星期 1–7、节次 1–10 和周次列表');
    }
    final weeks = rawWeeks == null ? <int>[] : (rawWeeks as List).map((w) {
      final value = int.tryParse('$w');
      if (value == null || value < 1 || value > 30) {
        throw const FormatException('周次范围为 1–30');
      }
      return value;
    }).toSet().toList()..sort();
    return Course(name: name, teacher: '${data['teacher'] ?? ''}',
      room: '${data['room'] ?? ''}', weekday: day, startPeriod: start,
      endPeriod: end, weeks: weeks, colorIndex: number('colorIndex'));
  }
}
