import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/schedule_parser.dart';
import 'campus_auth.dart';
import 'session_bridge.dart';

class OfficialJwxtPage extends StatefulWidget {
  const OfficialJwxtPage({super.key});
  @override
  State<OfficialJwxtPage> createState() => _OfficialJwxtPageState();
}
class _OfficialJwxtPageState extends State<OfficialJwxtPage> {
  late final WebViewController controller;
  bool loading = true, reading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(onPageStarted: (_) {
        if (mounted) setState(() { loading = true; error = null; });
      }, onPageFinished: (_) { if (mounted) setState(() => loading = false); },
        onWebResourceError: (e) { if (mounted && e.isForMainFrame == true) setState(() { loading = false; error = e.description; }); }))
;
    _openSession();
  }
  Future<void> _openSession() async {
    try {
      final kind = await CampusSessionBridge.restoreToWebView();
      if (!mounted) return;
      final uri = kind == 'graduate' ? Uri.parse('https://gms.ncist.edu.cn/grzxgl/') : Uri.parse('https://jw.cidp.edu.cn/LoginHandler.ashx');
      await controller.loadRequest(uri, headers: {'Referer': '${CampusAuthService.portalOrigin}/'});
    } catch (_) {
      if (mounted) setState(() { loading = false; error = '登录会话恢复失败，请重新登录'; });
    }
  }
  Future<void> read() async {
    setState(() => reading = true);
    try {
      final url = Uri.tryParse(await controller.currentUrl() ?? '');
      final host = url?.host ?? '';
      if (!(host == 'ncist.edu.cn' || host.endsWith('.ncist.edu.cn') || host == 'cidp.edu.cn' || host.endsWith('.cidp.edu.cn'))) {
        throw const FormatException('请打开学校域名下的个人课表页面');
      }
      final raw = await controller.runJavaScriptReturningResult(_extractTables);
      var decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is String) decoded = jsonDecode(decoded);
      final courses = ScheduleParser.parseCells(decoded as List);
      if (!mounted) return;
      if (courses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('当前页面未识别到周课表，请进入个人课表。也可使用 JSON 导入。原缓存已保留。')));
        return;
      }
      final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: Text('读取到 ${courses.length} 条课程'), content: SizedBox(width: 440, height: 280,
          child: ListView(children: [const Text('请核对名称、节次和周次，确认后保存到本机。'),
            ...courses.map((c) => ListTile(title: Text(c.name), subtitle: Text('周${'一二三四五六日'[c.weekday - 1]} ${c.period}\n${c.weekLabel}')))])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存课表'))]));
      if (confirmed == true && mounted) Navigator.of(context).pop(jsonEncode(courses.map((c) => c.toJson()).toList()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('读取失败：$e')));
    } finally { if (mounted) setState(() => reading = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('教务课表同步'), actions: [IconButton(tooltip: '刷新网页', onPressed: controller.reload, icon: const Icon(Icons.refresh))]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        const Expanded(child: Text('在教务系统进入个人课表，再读取当前页面。', style: TextStyle(fontSize: 12))), const SizedBox(width: 8),
        FilledButton(onPressed: reading || loading ? null : read, child: Text(reading ? '读取中…' : '读取课表')),
      ])),
      if (loading) const LinearProgressIndicator(),
      if (error != null) MaterialBanner(content: Text('网页加载失败：$error'), actions: [TextButton(onPressed: controller.reload, child: const Text('重试'))]),
      Expanded(child: WebViewWidget(controller: controller)),
    ]));
}

// Read only visible same-origin table cells. No API guessing or credential access.
const _extractTables = r'''
(() => {
 const documents = [document];
 function frames(doc) {
  for (const frame of doc.querySelectorAll('iframe,frame')) {
   try { if (frame.contentDocument) { documents.push(frame.contentDocument); frames(frame.contentDocument); } } catch (_) {}
  }
 }
 frames(document);
 const output = [];
 for (const doc of documents) for (const table of doc.querySelectorAll('table')) {
  const grid = [], anchors = [];
  for (let r=0; r<table.rows.length; r++) {
   grid[r] ||= []; let col=0;
   for (const cell of table.rows[r].cells) {
    while (grid[r][col]) col++;
    const item = {text: cell.innerText.trim(), row:r, col, span:cell.rowSpan};
    anchors.push(item);
    for (let y=0; y<cell.rowSpan; y++) for (let x=0; x<cell.colSpan; x++) {
     grid[r+y] ||= []; grid[r+y][col+x] = item;
    }
    col += cell.colSpan;
   }
  }
  const header = grid.find(row => row.filter(cell => /(?:星期|周)[一二三四五六日天]/.test(cell?.text || '')).length >= 5);
  if (!header) continue;
  const days = {};
  header.forEach((cell, col) => {
   const m=cell?.text.match(/(?:星期|周)([一二三四五六日天])/);
   if (m) days[col] = Math.min(7,'一二三四五六日天'.indexOf(m[1])+1);
  });
  for (const item of anchors) {
   if (!days[item.col] || !item.text || header.includes(item)) continue;
   const row=grid[item.row];
   const label=row.find((cell,col) => !days[col] && /(?:第\s*)?\d+\s*(?:[-–]\s*\d+\s*)?节/.test(cell?.text || ''));
   if (!label) continue;
   const nums = label.text.match(/(?:第\s*)?(\d+)\s*(?:[-–]\s*(\d+)\s*)?节/);
   const start=Number(nums[1]), end=nums[2] ? Number(nums[2]) : start + item.span - 1;
   output.push({text:item.text, weekday:days[item.col], startPeriod:start, endPeriod:end});
  }
 }
 return JSON.stringify(output);
})();
''';
