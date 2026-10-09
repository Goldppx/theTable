import 'package:flutter/material.dart';

import '../auth/jwxt_page.dart';
import '../models/course.dart';
import '../models/course_layout.dart';
import '../ui/app_style.dart';
import '../ui/import_schedule_dialog.dart';
import '../models/period_times.dart';
import '../services/app_state.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({required this.state, super.key});
  final CampusState state;
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late int week;
  bool compact = true;
  bool listMode = false;
  @override
  void initState() {
    super.initState();
    week = widget.state.currentWeek;
  }

  Future<void> sync() async {
    final imported = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            OfficialJwxtPage(onAuthenticated: widget.state.setProfile),
      ),
    );
    if (imported != null) {
      try {
        await widget.state.importSchedule(imported);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('导入失败：$e')));
        }
      }
      if (mounted) setState(() => week = widget.state.currentWeek);
    }
  }

  Future<void> import() async {
    final raw = await showDialog<String>(
      context: context,
      builder: (_) => const ImportScheduleDialog(),
    );
    if (raw == null) return;
    try {
      await widget.state.importSchedule(raw);
      if (mounted) setState(() => week = widget.state.currentWeek);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('格式有误：$e')));
      }
    }
  }

  void detail(Course course) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(course.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            Text('教师：${course.teacher.isEmpty ? '待提供' : course.teacher}'),
            const SizedBox(height: 10),
            Text('地点：${course.room.isEmpty ? '待提供' : course.room}'),
            const SizedBox(height: 10),
            Text('星期${'一二三四五六日'[course.weekday - 1]} · ${course.period}'),
            const SizedBox(height: 10),
            Text(course.weekLabel),
          ],
        ),
      ),
    ),
  );
  void rooms() {
    final courses = widget.state.courses
        .where((c) => c.occursIn(week))
        .toList();
    final rooms =
        courses.map((c) => c.room).where((r) => r.isNotEmpty).toSet().toList()
          ..sort();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            const Text(
              '本周教室',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text('仅显示个人课表中的教室占用；全校空教室数据需教务接口提供。'),
            if (rooms.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('当前课表暂无教室'),
              ),
            ...rooms.map(
              (room) => ListTile(
                leading: const Icon(Icons.meeting_room_outlined),
                title: Text(room),
                subtitle: Text(
                  courses
                      .where((c) => c.room == room)
                      .map((c) => '周${'一二三四五六日'[c.weekday - 1]} ${c.period}')
                      .join(' · '),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    week = week.clamp(1, state.totalWeeks);
    final colors = Theme.of(context).colorScheme;
    final monday = state.semesterStart.add(Duration(days: (week - 1) * 7));
    final sunday = monday.add(const Duration(days: 6));
    final visible = state.courses.where((c) => c.occursIn(week)).toList();
    final lanes = layoutCourses(visible);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final rowHeight = (compact ? 64.0 : 86.0) * scale;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${monday.month}月${monday.day}日–${sunday.month == monday.month ? '' : '${sunday.month}月'}${sunday.day}日',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '课表设置',
                    onSelected: (value) {
                      if (value == 'import') import();
                      if (value == 'view') setState(() => listMode = !listMode);
                      if (value == 'size') setState(() => compact = !compact);
                      if (value == 'today') {
                        setState(() => week = state.currentWeek);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'view',
                        child: Text(listMode ? '周课表视图' : '课程列表视图'),
                      ),
                      const PopupMenuItem(
                        value: 'import',
                        child: Text('导入课表 JSON'),
                      ),
                      const PopupMenuItem(value: 'today', child: Text('回到本周')),
                      PopupMenuItem(
                        value: 'size',
                        child: Text(compact ? '展开节次高度' : '紧凑节次高度'),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: week,
                      underline: const SizedBox.shrink(),
                      items: List.generate(
                        state.totalWeeks,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('第 ${i + 1} 周'),
                        ),
                      ),
                      onChanged: (value) {
                        if (value != null) setState(() => week = value);
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: '本周教室',
                    onPressed: rooms,
                    icon: const Icon(Icons.meeting_room_outlined),
                  ),
                  IconButton(
                    tooltip: '刷新：打开教务系统读取课表',
                    onPressed: sync,
                    icon: const Icon(Icons.sync),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (state.courses.isEmpty) {
                return SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.calendar_month_outlined,
                    title: '开始安排你的学期',
                    message: '连接教务系统同步课表，也可从菜单导入已有课程。',
                    action: FilledButton.icon(
                      onPressed: sync,
                      icon: const Icon(Icons.sync),
                      label: const Text('同步课表'),
                    ),
                  ),
                );
              }
              if (lanes.any((lane) => lane.lanes > 2) ||
                  listMode ||
                  scale > 1.3 ||
                  constraints.maxWidth < 360 ||
                  constraints.maxHeight < 220) {
                final sorted = List<Course>.of(visible)
                  ..sort((a, b) {
                    final day = a.weekday.compareTo(b.weekday);
                    return day == 0
                        ? a.startPeriod.compareTo(b.startPeriod)
                        : day;
                  });
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    if (sorted.isEmpty)
                      EmptyState(
                        icon: Icons.event_available,
                        title: '第 $week 周暂无课程',
                        message: '可切换周次查看其他安排。',
                      ),
                    for (final course in sorted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(course.name),
                            subtitle: Text(
                              '周${'一二三四五六日'[course.weekday - 1]} · ${course.period}\n${course.room.isEmpty ? '地点待提供' : course.room}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => detail(course),
                          ),
                        ),
                      ),
                  ],
                );
              }
              // Horizontal scrolling keeps text legible on narrow phones and enlarged fonts.
              final minimumWidth = 390.0 * scale;
              final width = constraints.maxWidth < minimumWidth
                  ? minimumWidth
                  : constraints.maxWidth;
              final gutter = 38.0 * scale;
              final dayWidth = (width - gutter) / 7;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 52 * scale,
                        child: Row(
                          children: [
                            SizedBox(
                              width: gutter,
                              child: const Center(
                                child: Text(
                                  '节',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            ...List.generate(7, (day) {
                              final date = monday.add(Duration(days: day));
                              final now = DateTime.now();
                              final today =
                                  date.year == now.year &&
                                  date.month == now.month &&
                                  date.day == now.day;
                              return SizedBox(
                                width: dayWidth,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: today
                                        ? colors.primaryContainer
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '周${'一二三四五六日'[day]}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${date.month}/${date.day}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: today
                                              ? colors.onPrimaryContainer
                                              : colors.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: SizedBox(
                            height: rowHeight * 10,
                            child: Stack(
                              children: [
                                Column(
                                  children: List.generate(
                                    10,
                                    (period) => Container(
                                      height: rowHeight,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .cardTheme
                                            .color,
                                        border: Border(
                                          top: BorderSide(
                                            color: colors.outlineVariant,
                                            width: period.isEven ? 1.4 : .5,
                                          ),
                                        ),
                                      ),
                                      child: Align(
                                        alignment: Alignment.topLeft,
                                        child: SizedBox(
                                          width: gutter,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 10,
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  '${period + 1}',
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                Text(
                                                  periodTimes[period][0],
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color:
                                                        colors.onSurfaceVariant,
                                                  ),
                                                ),
                                                Text(
                                                  periodTimes[period][1],
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color:
                                                        colors.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                ...visible.asMap().entries.map((entry) {
                                  final course = entry.value;
                                  final foreground = colors.onSurface;
                                  final slot = lanes[entry.key].lane;
                                  final cellWidth =
                                      dayWidth / lanes[entry.key].lanes;
                                  return Positioned(
                                    left:
                                        gutter +
                                        (course.weekday - 1) * dayWidth +
                                        slot * cellWidth +
                                        2,
                                    top:
                                        (course.startPeriod - 1) * rowHeight +
                                        2,
                                    width: cellWidth - 4,
                                    height:
                                        (course.endPeriod -
                                                course.startPeriod +
                                                1) *
                                            rowHeight -
                                        4,
                                    child: Material(
                                      color: Color.alphaBlend(
                                        course.color.withValues(alpha: .24),
                                        colors.surface,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      clipBehavior: Clip.antiAlias,
                                      child: InkWell(
                                        onTap: () => detail(course),
                                        child: Padding(
                                          padding: const EdgeInsets.all(5),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                course.name,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: foreground,
                                                  fontSize: 11,
                                                  height: 1.1,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Expanded(
                                                child: Text(
                                                  compact
                                                      ? course.room
                                                      : '${course.teacher}\n${course.room}\n${course.weekLabel}',
                                                  overflow: TextOverflow.fade,
                                                  style: TextStyle(
                                                    color: foreground,
                                                    fontSize: 9,
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                if (state.courses.isNotEmpty && visible.isEmpty)
                                  Positioned(
                                    top: 16,
                                    left: gutter + 16,
                                    right: 16,
                                    child: Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text('第 $week 周暂无课程'),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
