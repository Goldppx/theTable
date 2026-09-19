class Course {
  const Course({
    required this.name,
    required this.teacher,
    required this.room,
    required this.weekday,
    required this.startPeriod,
    required this.endPeriod,
  });

  final String name;
  final String teacher;
  final String room;
  final int weekday;
  final int startPeriod;
  final int endPeriod;
}
