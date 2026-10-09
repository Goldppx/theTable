import 'course.dart';

/// Assign stable lanes across each connected group of overlapping courses.
/// Input indices are retained so identical course records remain independent.
List<({int lane, int lanes})> layoutCourses(List<Course> courses) {
  final result = List.generate(courses.length, (_) => (lane: 0, lanes: 1));
  for (var day = 1; day <= 7; day++) {
    final indices =
        List.generate(
          courses.length,
          (i) => i,
        ).where((i) => courses[i].weekday == day).toList()..sort((a, b) {
          final start = courses[a].startPeriod.compareTo(
            courses[b].startPeriod,
          );
          return start == 0 ? a.compareTo(b) : start;
        });
    var cursor = 0;
    while (cursor < indices.length) {
      final group = <int>[];
      var end = courses[indices[cursor]].endPeriod;
      while (cursor < indices.length &&
          courses[indices[cursor]].startPeriod <= end) {
        final index = indices[cursor++];
        group.add(index);
        if (courses[index].endPeriod > end) end = courses[index].endPeriod;
      }
      final laneEnds = <int>[];
      for (final index in group) {
        var lane = laneEnds.indexWhere(
          (end) => end < courses[index].startPeriod,
        );
        if (lane < 0) {
          lane = laneEnds.length;
          laneEnds.add(courses[index].endPeriod);
        } else {
          laneEnds[lane] = courses[index].endPeriod;
        }
        result[index] = (lane: lane, lanes: 1);
      }
      for (final index in group) {
        result[index] = (lane: result[index].lane, lanes: laneEnds.length);
      }
    }
  }
  return result;
}
