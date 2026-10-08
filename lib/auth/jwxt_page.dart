import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/schedule_parser.dart';
import 'campus_auth.dart';
import 'session_bridge.dart';
import 'login_page.dart';

class OfficialJwxtPage extends StatefulWidget {
  const OfficialJwxtPage({this.onAuthenticated, super.key});
  final Future<void> Function(CampusProfile)? onAuthenticated;
  @override
  State<OfficialJwxtPage> createState() => _OfficialJwxtPageState();
}
class _OfficialJwxtPageState extends State<OfficialJwxtPage> {
  late final WebViewController controller;
  bool loading = true, reading = false;
  String? error;
  bool pageReady = false, openingSession = false;
  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(onPageStarted: (_) {
        if (mounted) setState(() { loading = true; pageReady = false; error = null; });
      }, onPageFinished: (url) {
        if (!mounted) return;
        final host = Uri.tryParse(url)?.host;
        setState(() {
          loading = false;
          pageReady = host == 'jw.cidp.edu.cn' || host == 'gms.ncist.edu.cn';
          if (host == 'auth.ncist.edu.cn') error = '学校会话已过期，请重新认证';
        });
      },
        onWebResourceError: (e) { if (mounted && e.isForMainFrame == true) setState(() { loading = false; pageReady = false; error = e.description; }); }))
;
    _openSession();
  }
  Future<void> _openSession() async {
    if (openingSession) return;
    setState(() { openingSession = true; loading = true; pageReady = false; error = null; });
    try {
      final kind = await CampusSessionBridge.restoreToWebView();
      if (!mounted) return;
      final uri = kind == 'graduate' ? Uri.parse('https://gms.ncist.edu.cn/grzxgl/') : Uri.parse('https://jw.cidp.edu.cn/LoginHandler.ashx');
      await controller.loadRequest(uri, headers: {'Referer': '${CampusAuthService.portalOrigin}/'});
    } on FormatException catch (e) {
      _sessionError(e.message.toString());
    } on PlatformException catch (e) {
      _sessionError(e.code == 'COOKIE_REJECTED'
          ? '学校网页会话写入失败，请重新认证'
          : '登录会话恢复失败（${e.code}），请重新认证');
    } on TimeoutException {
      _sessionError('恢复学校网页会话超时，请重试');
    } catch (_) {
      _sessionError('登录会话读取失败，请重新认证');
    } finally {
      if (mounted) setState(() => openingSession = false);
    }
  }
  void _sessionError(String message) {
    if (mounted) setState(() { loading = false; pageReady = false; error = message; });
  }
  Future<void> _retry() async {
    if (openingSession) return;
    if (error != null || !pageReady) {
      await _openSession();
    } else {
      await controller.reload();
    }
  }
  Future<void> _reauthenticate() async {
    final profile = await Navigator.of(context).push<CampusProfile>(MaterialPageRoute(
      builder: (_) => CampusLoginPage(auth: CampusAuthService())));
    if (!mounted || profile == null) return;
    if (widget.onAuthenticated != null) await widget.onAuthenticated!(profile);
    if (mounted) await _openSession();
  }
  Future<void> read() async {
    if (!pageReady || loading || error != null || openingSession || reading) return;
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
    appBar: AppBar(title: const Text('教务课表同步'), actions: [IconButton(tooltip: '刷新网页', onPressed: openingSession ? null : _retry, icon: const Icon(Icons.refresh))]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        const Expanded(child: Text('在教务系统进入个人课表，再读取当前页面。', style: TextStyle(fontSize: 12))), const SizedBox(width: 8),
        FilledButton(onPressed: reading || loading || openingSession || !pageReady || error != null ? null : read, child: Text(reading ? '读取中…' : '读取课表')),
      ])),
      if (loading) const LinearProgressIndicator(),
      if (error != null) MaterialBanner(content: Text('网页加载失败：$error'), actions: [
        TextButton(onPressed: openingSession ? null : _retry, child: const Text('重试')),
        TextButton(onPressed: openingSession ? null : _reauthenticate, child: const Text('重新认证')),
      ]),
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
