import 'package:flutter/material.dart';

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

  String get period => '第 $startPeriod–$endPeriod 节';
  String get location => room;

  Color get color => switch (weekday) {
        1 => Colors.blue,
        2 => Colors.teal,
        3 => Colors.deepPurple,
        4 => Colors.orange,
        5 => Colors.pink,
        _ => Colors.indigo,
      };
}
