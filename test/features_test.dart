import 'package:flutter_test/flutter_test.dart';
import 'package:the_table/features/notification_plan.dart';
import 'package:the_table/features/preferences.dart';
import 'package:the_table/features/platform_tools.dart';
import 'package:the_table/models/course.dart';
import 'package:the_table/services/app_state.dart';

void main() {
  const course = Course(name: '软件工程', teacher: '老师', room: '博观楼', weekday: 1, startPeriod: 3, endPeriod: 4, weeks: [2]);
  test('提醒尊重周次、提前量和过去时间', () {
    final plan = NotificationPlan.build([course], DateTime(2026, 9, 7), 3, const NotificationPreferences(nextClass: true, leadMinutes: 15), DateTime(2026, 9, 7));
    expect(plan.length, 1); expect(plan.single.time, DateTime(2026, 9, 14, 9, 55));
    expect(NotificationPlan.build([course], DateTime(2026, 9, 7), 3, const NotificationPreferences(nextClass: true), DateTime(2026, 9, 14, 10)).isEmpty, true);
  });
  test('早报覆盖无课日并在学期结束后停止', () {
    final plan = NotificationPlan.build([], DateTime(2026, 9, 7), 1, const NotificationPreferences(morning: true, morningHour: 7, morningMinute: 30), DateTime(2026, 9, 7, 8));
    expect(plan.length, 6); expect(plan.first.time, DateTime(2026, 9, 8, 7, 30)); expect(plan.first.body, contains('没有课程'));
    expect(NotificationPlan.build([], DateTime(2026, 9, 7), 1, const NotificationPreferences(morning: true), DateTime(2026, 9, 14)), isEmpty);
  });
  test('关闭两个本地通知开关不安排任务', () { expect(NotificationPlan.build([course], DateTime(2026, 9, 7), 20, const NotificationPreferences(), DateTime(2026, 9, 7)), isEmpty); });
  test('拒绝危险快捷链接和错误包名', () {
    for (final target in ['file:///etc/passwd', 'javascript:alert(1)', 'http://example.com']) { expect(() => Shortcut.fromJson({'name': '测试', 'kind': 'link', 'target': target}), throwsFormatException); }
    expect(() => Shortcut.fromJson({'name': '测试', 'kind': 'package', 'target': 'bad/package'}), throwsFormatException);
    expect(Shortcut.fromJson({'name': '微信', 'kind': 'link', 'target': 'weixin://test'}).kind, 'link');
  });
  test('地图明确声明 GPS 坐标并以经纬度顺序传递', () {
    final uri = Uri.parse(PlatformTools.amapUri(39.95, 116.79, '校园地图'));
    expect(uri.host, 'uri.amap.com'); expect(uri.queryParameters['position'], '116.79,39.95'); expect(uri.queryParameters['coordinate'], 'wgs84'); expect(uri.queryParameters['name'], '校园地图');
  });
  test('默认配色及快捷入口可修改', () async {
    final state = CampusState(persist: false); expect(state.dynamicColor, false); expect(state.shortcuts.length, 4);
    await state.saveFeatures(entries: []); expect(state.shortcuts, isEmpty); state.dispose();
  });
}
