import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../features/settings_pages.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.state, required this.onSchedule, required this.onMap, super.key});
  final CampusState state;
  final VoidCallback onSchedule, onMap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 30, 18, 32), children: [
      Text('应大通', style: Theme.of(context).textTheme.displaySmall),
      const SizedBox(height: 6), Text('教务信息，一处查看', style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 30),
      Row(children: [const Expanded(child: Text('开发组公告', style: TextStyle(fontWeight: FontWeight.w700))),
        const SizedBox(width: 12), Flexible(child: Text('点击查看完整公告', textAlign: TextAlign.end,
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)))]),
      const SizedBox(height: 12),
      Card(color: colors.primary, child: InkWell(borderRadius: BorderRadius.circular(24),
        onTap: () => showModalBottomSheet<void>(context: context, showDragHandle: true,
          builder: (_) => const Padding(padding: EdgeInsets.fromLTRB(24, 4, 24, 40),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('应大通 · 0.4.0', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 16), Text('新版增加课前提醒、早报、API 通知、校园快捷方式和高德地图。默认蓝色配色，支持动态取色开关。\n\n通过日历页刷新入口打开学校教务网页，进入课表后尝试读取页面；也可导入课程 JSON。学校网页格式的兼容性仍需真实账号验证。'),
            ]))),
        child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
          Icon(Icons.campaign_outlined, color: colors.onPrimary), const SizedBox(width: 16),
          Expanded(child: Text('公告 · 0.4.0 更新', style: TextStyle(color: colors.onPrimary, fontWeight: FontWeight.w700, fontSize: 17))),
          Icon(Icons.expand_more, color: colors.onPrimary),
        ])))),
      const SizedBox(height: 26), _section(context, '教务'), const SizedBox(height: 12),
      _card(context, '我的课表', state.syncedAt == null ? '查看本地课表，按需同步教务系统' : '已缓存 ${state.courses.length} 门课程 · 第 ${state.currentWeek} 周', '进入课表', onSchedule),
      const SizedBox(height: 24), _section(context, '校园'), const SizedBox(height: 12),
      _card(context, '校园地图', '高德校园地图，支持地图软件打开', '打开地图', onMap),
      const SizedBox(height: 24), Row(children: [const Expanded(child: Text('校园快捷方式')), TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ShortcutsPage(state: state))), child: const Text('管理'))]),
      Wrap(spacing: 8, runSpacing: 8, children: state.shortcuts.map((s) => ActionChip(avatar: const Icon(Icons.open_in_new, size: 18), label: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 140), child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis)), onPressed: () => launchShortcut(context, s))).toList()),
      if (state.storageError != null) ...[const SizedBox(height: 20), Text(state.storageError!)],
      const SizedBox(height: 30), Center(child: Text('theTable 0.4.0', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant))),
    ]);
  }
  Widget _section(BuildContext context, String text) => Text(text,
    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700));
  Widget _card(BuildContext context, String title, String subtitle, String action, VoidCallback onTap) => Card(
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge), const SizedBox(height: 12),
        Text('$action ›', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 17)),
      ]))));
}
