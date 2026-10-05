import 'package:flutter/material.dart';
import '../auth/jwxt_page.dart';
import '../models/course.dart';
import '../services/app_state.dart';

const periodTimes = [
  ['08:00', '08:45'], ['08:55', '09:40'], ['10:10', '10:55'], ['11:05', '11:50'],
  ['14:30', '15:15'], ['15:25', '16:10'], ['16:40', '17:25'], ['17:35', '18:20'],
  ['19:20', '20:05'], ['20:15', '21:00'],
];
class SchedulePage extends StatefulWidget {
  const SchedulePage({required this.state, super.key});
  final CampusState state;
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}
class _SchedulePageState extends State<SchedulePage> {
  late int week;
  bool compact = true;
  @override
  void initState() { super.initState(); week = widget.state.currentWeek; }
  Future<void> sync() async {
    final imported = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const OfficialJwxtPage()));
    if (imported != null) {
      try { await widget.state.importSchedule(imported); }
      catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败：$e'))); }
      if (mounted) setState(() => week = widget.state.currentWeek);
    }
  }
  Future<void> import() async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('导入课表'), content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('粘贴课程 JSON。先校验全部课程，再更新本地缓存。格式示例见仓库 README。'),
        const SizedBox(height: 12), TextField(controller: controller, minLines: 4, maxLines: 8,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '[{"name":"课程", "weekday":1, ...}]')),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('导入'))]));
    // Keep the controller alive until the dialog's closing animation completes.
    if (raw == null) return;
    try {
      await widget.state.importSchedule(raw);
      if (mounted) setState(() => week = widget.state.currentWeek);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('格式有误：$e')));
    }
  }
  void detail(Course course) => showModalBottomSheet<void>(context: context, showDragHandle: true,
    builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(course.name, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 20),
        Text('教师：${course.teacher.isEmpty ? '待提供' : course.teacher}'), const SizedBox(height: 10),
        Text('地点：${course.room.isEmpty ? '待提供' : course.room}'), const SizedBox(height: 10),
        Text('星期${'一二三四五六日'[course.weekday - 1]} · ${course.period}'), const SizedBox(height: 10),
        Text(course.weekLabel),
      ]))));
  void rooms() {
    final courses = widget.state.courses.where((c) => c.occursIn(week)).toList();
    final rooms = courses.map((c) => c.room).where((r) => r.isNotEmpty).toSet().toList()..sort();
    showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => SafeArea(child: ListView(
      shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        const Text('本周教室', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10), const Text('仅显示个人课表中的教室占用；全校空教室数据需教务接口提供。'),
        if (rooms.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('当前课表暂无教室')),
        ...rooms.map((room) => ListTile(leading: const Icon(Icons.meeting_room_outlined), title: Text(room),
          subtitle: Text(courses.where((c) => c.room == room).map((c) => '周${'一二三四五六日'[c.weekday - 1]} ${c.period}').join(' · ')))),
      ])));
  }
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final colors = Theme.of(context).colorScheme;
    final monday = state.semesterStart.add(Duration(days: (week - 1) * 7));
    final sunday = monday.add(const Duration(days: 6));
    final visible = state.courses.where((c) => c.occursIn(week)).toList();
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final rowHeight = (compact ? 64.0 : 86.0) * scale;
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 12, 12), child: Wrap(
        spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${monday.month}月${monday.day}日–${sunday.month == monday.month ? '' : '${sunday.month}月'}${sunday.day}日',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text('${monday.year} 年', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
          ]),
          TextButton.icon(onPressed: rooms, icon: const Icon(Icons.apartment, size: 18), label: const Text('教室')),
          DropdownButton<int>(value: week.clamp(1, state.totalWeeks), underline: const SizedBox.shrink(),
            items: List.generate(state.totalWeeks, (i) => DropdownMenuItem(value: i + 1, child: Text('第 ${i + 1} 周'))),
            onChanged: (value) { if (value != null) setState(() => week = value); }),
          IconButton(tooltip: '刷新：打开教务系统读取课表', onPressed: sync, icon: const Icon(Icons.refresh)),
          PopupMenuButton<String>(tooltip: '课表设置', onSelected: (value) {
            if (value == 'import') import();
            if (value == 'size') setState(() => compact = !compact);
            if (value == 'today') setState(() => week = state.currentWeek);
          }, itemBuilder: (_) => [const PopupMenuItem(value: 'import', child: Text('导入课表 JSON')),
            const PopupMenuItem(value: 'today', child: Text('回到本周')),
            PopupMenuItem(value: 'size', child: Text(compact ? '展开节次高度' : '紧凑节次高度'))]),
        ])),
      if (state.courses.isEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Row(children: [Expanded(child: Text('课表等待导入，点击刷新或导入 JSON',
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant))),
          TextButton(onPressed: import, child: const Text('导入'))])),
      Expanded(child: LayoutBuilder(builder: (context, constraints) {
        // Horizontal scrolling keeps text legible on narrow phones and enlarged fonts.
        final minimumWidth = 390.0 * scale;
        final width = constraints.maxWidth < minimumWidth ? minimumWidth : constraints.maxWidth;
        final gutter = 38.0 * scale;
        final dayWidth = (width - gutter) / 7;
        return SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: width, child: Column(children: [
          SizedBox(height: 52 * scale, child: Row(children: [SizedBox(width: gutter, child: const Center(child: Text('节', style: TextStyle(fontSize: 12)))),
            ...List.generate(7, (day) {
              final date = monday.add(Duration(days: day));
              final now = DateTime.now();
              final today = date.year == now.year && date.month == now.month && date.day == now.day;
              return SizedBox(width: dayWidth, child: Container(
                decoration: BoxDecoration(color: today ? colors.primaryContainer : null),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('周${'一二三四五六日'[day]}', style: const TextStyle(fontSize: 12)), const SizedBox(height: 3),
                  Text('${date.month}/${date.day}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: today ? colors.onPrimaryContainer : colors.onSurface)),
                ])));
            }),
          ])),
          Expanded(child: SingleChildScrollView(child: SizedBox(height: rowHeight * 10, child: Stack(children: [
            Column(children: List.generate(10, (period) => Container(height: rowHeight,
              decoration: BoxDecoration(color: Theme.of(context).cardTheme.color,
                border: Border(top: BorderSide(color: colors.outlineVariant, width: period.isEven ? 1.4 : .5))),
              child: Align(alignment: Alignment.topLeft, child: SizedBox(width: gutter, child: Padding(
                padding: const EdgeInsets.only(top: 10), child: Column(children: [
                  Text('${period + 1}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  Text(periodTimes[period][0], style: TextStyle(fontSize: 9, color: colors.onSurfaceVariant)),
                  Text(periodTimes[period][1], style: TextStyle(fontSize: 9, color: colors.onSurfaceVariant)),
                ]))))))),
            ...visible.map((course) {
              // Conflicting courses share a column; both remain tappable.
              final overlaps = visible.where((c) => c.weekday == course.weekday &&
                c.startPeriod <= course.endPeriod && c.endPeriod >= course.startPeriod).toList();
              final slot = overlaps.indexOf(course);
              final cellWidth = dayWidth / overlaps.length;
              return Positioned(left: gutter + (course.weekday - 1) * dayWidth + slot * cellWidth + 2,
                top: (course.startPeriod - 1) * rowHeight + 2, width: cellWidth - 4,
                height: (course.endPeriod - course.startPeriod + 1) * rowHeight - 4,
                child: Material(color: course.color, borderRadius: BorderRadius.circular(14), clipBehavior: Clip.antiAlias,
                  child: InkWell(onTap: () => detail(course), child: Padding(padding: const EdgeInsets.all(5),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(course.name, maxLines: 3, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.1, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3), Expanded(child: Text('${course.teacher}\n${course.room}\n${course.weekLabel}',
                        overflow: TextOverflow.fade, style: const TextStyle(color: Colors.white, fontSize: 9, height: 1.3))),
                    ])))));
            }),
            if (state.courses.isNotEmpty && visible.isEmpty) Positioned(top: 16, left: gutter + 16, right: 16,
              child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('第 $week 周暂无课程')))),
          ])))),
        ])));
      })),
    ]);
  }
}
