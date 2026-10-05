import '../models/course.dart';

/// Conservative adapter for visible weekly HTML tables. Unsupported layouts
/// produce no courses and leave the old cache untouched.
class ScheduleParser {
  static List<Course> parseCells(List<dynamic> cells) {
    final result = <Course>[];
    for (final raw in cells) {
      if (raw is! Map) continue;
      final day = int.tryParse('${raw['weekday']}') ?? 0;
      final start = int.tryParse('${raw['startPeriod']}') ?? 0;
      final end = int.tryParse('${raw['endPeriod']}') ?? 0;
      if (day < 1 || day > 7 || start < 1 || end < start || end > 10) continue;
      final text = '${raw['text'] ?? ''}'.replaceAll('\r', '').trim();
      for (final block in text.split(RegExp(r'\n\s*\n|[-—]{3,}'))) {
        final lines = block.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        if (lines.isEmpty || !RegExp(r'\d.*周').hasMatch(block)) continue;
        final weeks = parseWeeks(block);
        if (weeks.isEmpty) continue;
        final name = lines.first.replaceFirst(RegExp(r'^课程[：:]\s*'), '');
        if (name.length > 80 || RegExp(r'^(星期|周[一二三四五六日天]|第\d+节)').hasMatch(name)) continue;
        String labeled(String label) {
          final match = RegExp('(?:$label)[：:]\\s*([^\\n]+)').firstMatch(block);
          return match?.group(1)?.trim() ?? '';
        }
        final teacher = labeled('教师|老师|任课教师');
        final room = labeled('教室|地点|上课地点');
        result.add(Course(name: name, teacher: teacher, room: room, weekday: day,
          startPeriod: start, endPeriod: end, weeks: weeks, colorIndex: result.length));
      }
    }
    final seen = <String>{};
    return result.where((c) => seen.add('${c.name}|${c.weekday}|${c.startPeriod}|${c.endPeriod}|${c.weeks}|${c.room}')).toList();
  }
  static List<int> parseWeeks(String text) {
    final values = <int>{};
    // A week expression is terminated by 周, never a period or room number.
    final expressions = RegExp(r'([\d\s,，、\-–~至]+)\s*周\s*(?:[（(]?([单双])(?:周)?[）)]?)?').allMatches(text);
    for (final expression in expressions) {
      final source = expression.group(1)!;
      final parity = expression.group(2);
      for (final part in source.trim().split(RegExp(r'[,，、\s]+'))) {
        if (part.isEmpty) continue;
        final range = part.split(RegExp(r'[-–~至]'));
        final start = int.tryParse(range.first);
        final end = int.tryParse(range.last);
        if (start == null || end == null || start < 1 || end > 30 || end < start) continue;
        for (var i = start; i <= end; i++) {
          if (parity == '单' && i.isEven || parity == '双' && i.isOdd) continue;
          values.add(i);
        }
      }
    }
    return values.toList()..sort();
  }
}
