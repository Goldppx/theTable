import '../models/course.dart';

/// 校园系统适配层。账户认证和课程解析集中在这里，界面层不会接触密码。
/// 当前返回演示数据；接入学校授权接口后替换 [loadCourses] 即可。
abstract class CampusGateway {
  Future<List<Course>> loadCourses();
}

class DemoCampusGateway implements CampusGateway {
  @override
  Future<List<Course>> loadCourses() async => const [
        Course(name: '数据结构', teacher: '张老师', room: '主楼 A302', weekday: 1, startPeriod: 1, endPeriod: 2),
        Course(name: '操作系统', teacher: '李老师', room: '实验楼 205', weekday: 2, startPeriod: 3, endPeriod: 4),
        Course(name: '移动应用开发', teacher: '王老师', room: '主楼 B201', weekday: 3, startPeriod: 6, endPeriod: 7),
      ];
}
