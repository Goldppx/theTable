import 'package:flutter_test/flutter_test.dart';
import 'package:the_table/models/course.dart';
import 'package:the_table/models/course_layout.dart';

Course course(int start, int end, {int day = 1}) => Course(
  name: '课程',
  teacher: '',
  room: '',
  weekday: day,
  startPeriod: start,
  endPeriod: end,
  weeks: const [1],
  colorIndex: 0,
);

void main() {
  test(
    'chained conflicts retain stable lanes without covering one another',
    () {
      final courses = [
        course(1, 2),
        course(2, 3),
        course(3, 4),
        course(5, 6),
        course(1, 2, day: 2),
      ];
      final layout = layoutCourses(courses);
      expect(layout.take(3).map((v) => v.lanes), everyElement(2));
      expect(layout[0].lane, layout[2].lane);
      expect(layout[0].lane, isNot(layout[1].lane));
      expect(layout[3].lanes, 1);
      expect(layout[4].lanes, 1);
    },
  );
  test('identical records and contained courses get distinct lanes', () {
    final same = course(1, 8);
    final layout = layoutCourses([same, same, course(2, 3), course(4, 5)]);
    expect(layout.map((v) => v.lanes), everyElement(3));
    expect(layout.take(3).map((v) => v.lane).toSet().length, 3);
    expect(layout[2].lane, layout[3].lane);
  });
}
