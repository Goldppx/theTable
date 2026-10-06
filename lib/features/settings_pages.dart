import 'package:flutter/material.dart';
import '../services/app_state.dart';
import 'preferences.dart';
import 'platform_tools.dart';

Future<void> launchShortcut(BuildContext context, Shortcut item) async {
  try { await PlatformTools.open(item); }
  catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('打开失败：$e'))); }
}
class ShortcutsPage extends StatelessWidget {
  const ShortcutsPage({required this.state, super.key});
  final CampusState state;
  Future<void> edit(BuildContext context, [int? index]) async {
    final old = index == null ? null : state.shortcuts[index];
    final name = TextEditingController(text: old?.name), target = TextEditingController(text: old?.target);
    var kind = old?.kind ?? 'package'; String? error;
    final item = await showDialog<Shortcut>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      title: Text(index == null ? '添加快捷方式' : '编辑快捷方式'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, maxLength: 24, decoration: const InputDecoration(labelText: '名称')),
        DropdownButtonFormField<String>(initialValue: kind, items: const [DropdownMenuItem(value: 'package', child: Text('Android 应用')), DropdownMenuItem(value: 'link', child: Text('小程序 / 网页链接'))], onChanged: (v) => set(() { kind = v!; target.clear(); })),
        TextField(controller: target, decoration: InputDecoration(labelText: kind == 'package' ? '应用包名' : 'HTTPS 或 weixin:// 链接', errorText: error)),
        if (kind == 'package') TextButton.icon(icon: const Icon(Icons.apps), label: const Text('选择已安装应用'), onPressed: () async {
          try {
            final apps = await PlatformTools.installedApps();
            if (!ctx.mounted) return;
            final selected = await showModalBottomSheet<Map<String, dynamic>>(context: ctx, showDragHandle: true, builder: (sheet) => ListView(children: apps.map((a) => ListTile(title: Text('${a['name']}'), subtitle: Text('${a['package']}'), onTap: () => Navigator.pop(sheet, a))).toList()));
            if (selected != null) { name.text = '${selected['name']}'; target.text = '${selected['package']}'; }
          } catch (_) { set(() => error = '应用列表读取失败，可手动输入包名'); }
        }),
        if (kind == 'link') const Padding(padding: EdgeInsets.only(top: 12), child: Text('粘贴小程序提供的有效 URL Link 或 weixin:// 链接。雨课堂默认打开官网，可替换成你的微信小程序链接。')),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')), FilledButton(onPressed: () {
        try { Navigator.pop(ctx, Shortcut.fromJson({'name': name.text, 'kind': kind, 'target': target.text})); } catch (e) { set(() => error = '$e'); }
      }, child: const Text('保存'))])));
    if (item != null) { final list = List<Shortcut>.of(state.shortcuts); if (index == null) { list.add(item); } else { list[index] = item; } await state.saveFeatures(entries: list); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('校园快捷方式')), floatingActionButton: FloatingActionButton(onPressed: () => edit(context), child: const Icon(Icons.add)),
    body: ListenableBuilder(listenable: state, builder: (context, _) => ListView(padding: const EdgeInsets.all(16), children: [
      const Text('点击入口打开；编辑可修改包名或小程序链接。'), const SizedBox(height: 12),
      ...state.shortcuts.asMap().entries.map((entry) => Card(child: ListTile(title: Text(entry.value.name), subtitle: Text(entry.value.target, maxLines: 2, overflow: TextOverflow.ellipsis), onTap: () => launchShortcut(context, entry.value),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(tooltip: '编辑', onPressed: () => edit(context, entry.key), icon: const Icon(Icons.edit_outlined)), IconButton(tooltip: '删除', onPressed: () => state.saveFeatures(entries: List.of(state.shortcuts)..removeAt(entry.key)), icon: const Icon(Icons.delete_outline))]))),
      TextButton(onPressed: () => state.saveFeatures(entries: List.of(Shortcut.defaults)), child: const Text('恢复默认入口')), const SizedBox(height: 80),
    ])));
}
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({required this.state, super.key});
  final CampusState state;
  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}
class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  late final url = TextEditingController(text: widget.state.notifications.apiUrl);
  late final token = TextEditingController(text: widget.state.notifications.token);
  bool busy = false;
  Future<void> update(Map<String, dynamic> changes, {bool permission = false}) async {
    setState(() => busy = true);
    try {
      if (permission && widget.state.persist && !await widget.state.notificationService.permission()) throw const FormatException('请先在系统设置中允许通知');
      final next = NotificationPreferences.fromJson({...widget.state.notifications.toJson(), ...changes});
      if (next.api) { final uri = Uri.tryParse(next.apiUrl); if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) throw const FormatException('API 地址须为 HTTPS，不包含账号密码'); }
      await widget.state.saveFeatures(prefs: next);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  void dispose() { url.dispose(); token.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('通知')), body: ListenableBuilder(listenable: widget.state, builder: (context, _) {
    final p = widget.state.notifications;
    return ListView(padding: const EdgeInsets.all(18), children: [
      SwitchListTile(title: const Text('下节课提前通知'), subtitle: const Text('按当前账号课表、周次和上课时间提醒'), value: p.nextClass, onChanged: busy ? null : (v) => update({'nextClass': v}, permission: v)),
      DropdownButtonFormField<int>(initialValue: p.leadMinutes, decoration: const InputDecoration(labelText: '提前分钟数'), items: {5,10,15,30,60,p.leadMinutes}.toList().map((n) => DropdownMenuItem(value: n, child: Text('$n 分钟'))).toList(), onChanged: busy ? null : (v) => update({'leadMinutes': v})),
      SwitchListTile(title: const Text('每日早报'), subtitle: const Text('学期内每天显示当天课程，包括无课日'), value: p.morning, onChanged: busy ? null : (v) => update({'morning': v}, permission: v)),
      ListTile(title: const Text('早报时间'), trailing: Text('${p.morningHour.toString().padLeft(2, '0')}:${p.morningMinute.toString().padLeft(2, '0')}'), onTap: () async { final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: p.morningHour, minute: p.morningMinute)); if (time != null) await update({'morningHour': time.hour, 'morningMinute': time.minute}); }),
      const Divider(), const Text('校园消息 API', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
      TextField(controller: url, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'HTTPS API 地址')),
      TextField(controller: token, obscureText: true, decoration: const InputDecoration(labelText: 'Bearer 令牌（可选）')),
      SwitchListTile(title: const Text('前台 SSE 实时连接'), subtitle: const Text('服务器须同时支持 JSON 快照用于后台检查'), value: p.sse, onChanged: busy ? null : (v) => update({'sse': v})),
      FilledButton(onPressed: busy ? null : () => update({'apiUrl': url.text.trim(), 'token': token.text.trim()}), child: const Text('保存 API 配置')),
      SwitchListTile(title: const Text('接收 API 通知'), value: p.api, onChanged: busy ? null : (v) => update({'api': v, 'apiUrl': url.text.trim(), 'token': token.text.trim()}, permission: v)),
      const Text('前台：SSE 实时接收或每 30 秒检查。后台：系统定期检查，最短 15 分钟，可能延迟；强制停止后需重新打开。服务端返回消息 id、title、body，可选 HTTPS url。接口格式见仓库 docs/notifications.md。'),
      const SizedBox(height: 18), OutlinedButton(onPressed: busy ? null : () async { try { await widget.state.notificationService.checkNow(); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API 检查完成'))); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } }, child: const Text('立即检查 API')),
      OutlinedButton(onPressed: () async { await widget.state.notificationService.exactPermission(); await widget.state.reschedule(); }, child: const Text('允许准时课前提醒')),
      const Text('未授予精确闹钟权限时，系统可能延迟课前提醒。'),
      TextButton(onPressed: () async { if (await widget.state.notificationService.permission()) await widget.state.notificationService.test(); }, child: const Text('发送测试通知')),
    ]);
  }));
}
