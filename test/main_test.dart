import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_table/main.dart';
import 'package:the_table/pages/profile.dart';
import 'package:the_table/models/course.dart';
import 'package:the_table/services/app_state.dart';
import 'package:the_table/services/schedule_parser.dart';

const course = Course(
  name: '数据结构',
  teacher: '张老师',
  room: '明德楼 30504',
  weekday: 1,
  startPeriod: 3,
  endPeriod: 4,
  weeks: [1, 3, 5],
  colorIndex: 0,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final fontPath = File(
      '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    );
    if (fontPath.existsSync()) {
      final loader = FontLoader('Roboto')
        ..addFont(
          Future.value(ByteData.sublistView(fontPath.readAsBytesSync())),
        );
      await loader.load();
    }
  });
  test('course week filtering and field validation', () {
    expect(course.occursIn(3), isTrue);
    expect(course.occursIn(2), isFalse);
    expect(Course.fromJson(course.toJson()).endPeriod, 4);
    expect(
      () => Course.fromJson({...course.toJson(), 'weekday': 8}),
      throwsFormatException,
    );
    expect(
      () => Course.fromJson({...course.toJson(), 'endPeriod': 11}),
      throwsFormatException,
    );
  });
  test('week expressions preserve odd/even and discrete weeks', () {
    expect(ScheduleParser.parseWeeks('1-8周(单)'), [1, 3, 5, 7]);
    expect(ScheduleParser.parseWeeks('2-8周（双）'), [2, 4, 6, 8]);
    expect(ScheduleParser.parseWeeks('1-3,5,7周'), [1, 2, 3, 5, 7]);
  });
  test('visible timetable parser rejects non-course rows', () {
    final courses = ScheduleParser.parseCells([
      {
        'text': '数据结构\n教师：张老师\n教室：明德楼 30504\n1-8周(单)',
        'weekday': 1,
        'startPeriod': 3,
        'endPeriod': 4,
      },
      {'text': '请输入账号和密码', 'weekday': 2, 'startPeriod': 1, 'endPeriod': 2},
    ]);
    expect(courses.length, 1);
    expect(courses.first.teacher, '张老师');
    expect(courses.first.room, '明德楼 30504');
    expect(courses.first.weeks, [1, 3, 5, 7]);
  });
  test('invalid import preserves existing schedule', () async {
    final state = CampusState(persist: false);
    await state.importSchedule(jsonEncode([course.toJson()]));
    await expectLater(
      state.importSchedule(
        jsonEncode([
          course.toJson(),
          {...course.toJson(), 'startPeriod': 0},
        ]),
      ),
      throwsFormatException,
    );
    expect(state.courses.length, 1);
    expect(state.courses.first.name, '数据结构');
    state.dispose();
  });
  testWidgets('home, weekly timetable, course detail and appearance flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = CampusState(persist: false)..ready = true;
    await state.importSchedule(
      jsonEncode({
        'courses': [
          course.toJson(),
          const Course(
            name: '操作系统',
            teacher: '李老师',
            room: '博观楼 10405',
            weekday: 2,
            startPeriod: 3,
            endPeriod: 4,
            weeks: [1],
            colorIndex: 2,
          ).toJson(),
          const Course(
            name: '大学英语',
            teacher: '王老师',
            room: '明德楼 30707',
            weekday: 5,
            startPeriod: 3,
            endPeriod: 4,
            weeks: [1],
            colorIndex: 3,
          ).toJson(),
          const Course(
            name: '概率论',
            teacher: '陈老师',
            room: '致远楼 20603',
            weekday: 1,
            startPeriod: 5,
            endPeriod: 6,
            weeks: [1],
            colorIndex: 4,
          ).toJson(),
          const Course(
            name: '物理实验',
            teacher: '赵老师',
            room: '实验楼 618',
            weekday: 3,
            startPeriod: 7,
            endPeriod: 8,
            weeks: [1],
            colorIndex: 7,
          ).toJson(),
        ],
        'semesterStart': DateTime.now()
            .subtract(Duration(days: DateTime.now().weekday - 1))
            .toIso8601String(),
        'totalWeeks': 20,
      }),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('preview'),
        child: TheTableApp(state: state),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('应大通'), findsOneWidget);
    await snapshot(tester, 'home');
    await tester.tap(find.text('进入课表 ›'));
    await tester.pumpAndSettle();
    expect(find.text('数据结构'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await snapshot(tester, 'schedule');
    await tester.tap(find.text('数据结构'));
    await tester.pumpAndSettle();
    expect(find.text('教师：张老师'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('登录校园账号'), findsOneWidget);
    await snapshot(tester, 'profile');
    await tester.scrollUntilVisible(
      find.text('外观'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ProfilePage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();
    expect(state.themeMode, ThemeMode.light);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'landscape uses rail and large-text appearance stays scrollable',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final state = CampusState(persist: false)..ready = true;
      await tester.pumpWidget(TheTableApp(state: state));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('外观'),
        160,
        scrollable: find
            .descendant(
              of: find.byType(ProfilePage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('外观'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('浅色'));
      await tester.pumpAndSettle();
      expect(state.themeMode, ThemeMode.light);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('narrow phone and large text keep weekly courses usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final state = CampusState(persist: false)..ready = true;
    await state.importSchedule(
      jsonEncode({
        'courses': [course.toJson()],
        'semesterStart': DateTime.now()
            .subtract(Duration(days: DateTime.now().weekday - 1))
            .toIso8601String(),
      }),
    );
    await tester.pumpWidget(TheTableApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();
    expect(find.text('数据结构'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> snapshot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('preview')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/previews')..createSync(recursive: true);
    File('${directory.path}/$name.png')
        .writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}
