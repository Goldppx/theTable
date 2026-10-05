import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../auth/campus_auth.dart';
import '../auth/login_page.dart';
import '../services/app_state.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({required this.state, super.key});
  final CampusState state;
  Future<void> login(BuildContext context) async {
    final profile = await Navigator.of(context).push<CampusProfile>(MaterialPageRoute(
      builder: (_) => CampusLoginPage(auth: CampusAuthService())));
    if (profile != null) await state.setProfile(profile);
  }
  Future<void> remove(BuildContext context) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('移除本机账号？'), content: const Text('将清除该账号的课表缓存、个人资料与学校网页会话。'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('移除'))]));
    if (confirmed == true) {
      await WebViewCookieManager().clearCookies();
      await state.clearAccount();
    }
  }
  void appearance(BuildContext context) => showModalBottomSheet<void>(context: context, showDragHandle: true,
    builder: (ctx) => ListenableBuilder(listenable: state, builder: (context, child) => SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(title: Text('外观', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
        SegmentedButton<ThemeMode>(segments: const [
          ButtonSegment(value: ThemeMode.light, label: Text('浅色'), icon: Icon(Icons.light_mode_outlined)),
          ButtonSegment(value: ThemeMode.dark, label: Text('深色'), icon: Icon(Icons.dark_mode_outlined)),
          ButtonSegment(value: ThemeMode.system, label: Text('系统'), icon: Icon(Icons.brightness_auto_outlined)),
        ], selected: {state.themeMode}, onSelectionChanged: (v) => state.appearance(v.first, state.dynamicColor)),
        SwitchListTile(title: const Text('壁纸动态取色'), subtitle: const Text('Android 12 及以上跟随系统色彩'),
          value: state.dynamicColor, onChanged: (v) => state.appearance(state.themeMode, v)),
      ])))));
  void settings(BuildContext context) => showModalBottomSheet<void>(context: context, showDragHandle: true,
    builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(title: Text('设置', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
        ListTile(title: const Text('学期第一周开始日期'), subtitle: Text('${state.semesterStart.year}/${state.semesterStart.month}/${state.semesterStart.day}'),
          trailing: const Icon(Icons.chevron_right), onTap: () async {
            final value = await showDatePicker(context: ctx, initialDate: state.semesterStart,
              firstDate: DateTime(2020), lastDate: DateTime(2040));
            if (value != null) await state.setSemester(value.subtract(Duration(days: value.weekday - 1)));
          }),
        const ListTile(title: Text('本地数据'), subtitle: Text('课程缓存按学号存储；账号密码由学校登录网页处理。地图标记保存在本机。')),
      ]))));
  @override
  Widget build(BuildContext context) {
    final p = state.profile, colors = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 30, 18, 32), children: [
      Text('我的', style: Theme.of(context).textTheme.displaySmall), const SizedBox(height: 26),
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p == null ? '连接校园账号' : (p.name.isEmpty ? '校园用户' : p.name), style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6), Text(p?.studentNumber ?? '登录后读取学校门户资料', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 20),
        _info(context, '培养层次', _value(p?.education)), const SizedBox(height: 12),
        _info(context, '专业', _value(p?.major)), const SizedBox(height: 12),
        _info(context, '班级', _value(p?.className)), const SizedBox(height: 12),
        _info(context, '学院', _value(p?.college)), const SizedBox(height: 12),
        _info(context, '认证状态', p == null ? '等待登录' : '已保存身份'),
      ]))), const SizedBox(height: 18),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('本机账号', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 6),
        Text('课表缓存随当前学号保存', style: Theme.of(context).textTheme.bodyLarge), const SizedBox(height: 14),
        if (p != null) Container(decoration: BoxDecoration(color: colors.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(18)),
          child: ListTile(leading: _icon(context, Icons.person),
            title: Text(p.name.isEmpty ? '校园用户' : p.name), subtitle: Text(p.studentNumber),
            trailing: IconButton(tooltip: '移除账号', icon: Icon(Icons.delete_outline, color: colors.error), onPressed: () => remove(context)))),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => login(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
          child: Row(children: [const Icon(Icons.add), const SizedBox(width: 14),
            Expanded(child: Text(p == null ? '添加账号' : '重新认证')), const Icon(Icons.chevron_right)])),
      ]))), const SizedBox(height: 18),
      _tile(context, Icons.settings_outlined, '设置', () => settings(context)), const SizedBox(height: 10),
      _tile(context, Icons.palette_outlined, '外观', () => appearance(context)), const SizedBox(height: 10),
      _tile(context, Icons.info_outline, '关于', () => showAboutDialog(context: context, applicationName: '应大通', applicationVersion: '0.2.0',
        children: const [Text('Flutter / Material 3\n地图：© OpenStreetMap contributors · Esri\n真实课程网页解析待账号验证。')])),
    ]);
  }
  String _value(String? value) => value == null || value.isEmpty ? '待学校门户提供' : value;
  Widget _info(BuildContext context, String label, String value) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: Theme.of(context).textTheme.bodyLarge), const SizedBox(width: 24),
    Expanded(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontSize: 16))),
  ]);
  Widget _icon(BuildContext context, IconData icon) => Container(width: 42, height: 42,
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
    child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer));
  Widget _tile(BuildContext context, IconData icon, String title, VoidCallback action) => Card(child: ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), leading: _icon(context, icon),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), trailing: const Icon(Icons.chevron_right), onTap: action));
}
