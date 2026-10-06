import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/app_state.dart';
import '../features/platform_tools.dart';

class CampusMapPage extends StatefulWidget {
  const CampusMapPage({required this.state, super.key});
  final CampusState state;
  @override
  State<CampusMapPage> createState() => _CampusMapPageState();
}
class _CampusMapPageState extends State<CampusMapPage> {
  late final WebViewController controller;
  double lat = 39.95655, lon = 116.79699;
  String name = '应急管理大学（华北科技学院）';
  int progress = 0; String? error;
  @override
  void initState() {
    super.initState();
    controller = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted)..setNavigationDelegate(NavigationDelegate(
      onProgress: (value) { if (mounted) setState(() => progress = value); },
      onWebResourceError: (e) { if (e.isForMainFrame == true && mounted) setState(() => error = '地图加载失败，请检查网络后重试'); },
      onNavigationRequest: (request) => Uri.tryParse(request.url)?.scheme == 'https' ? NavigationDecision.navigate : NavigationDecision.prevent,
    ));
    load();
  }
  void load() { setState(() { error = null; progress = 0; }); controller.loadRequest(Uri.parse(PlatformTools.amapUri(lat, lon, name))); }
  Future<void> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw const FormatException('请开启系统定位');
      var p = await Geolocator.checkPermission(); if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) throw const FormatException('请允许定位权限');
      final point = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)));
      if (!mounted) return;
      lat = point.latitude; lon = point.longitude; name = '当前位置'; load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }
  Future<void> add() async {
    final label = TextEditingController(), latitude = TextEditingController(text: '$lat'), longitude = TextEditingController(text: '$lon'); String? error;
    final point = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(title: const Text('添加地图标签'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: label, decoration: const InputDecoration(labelText: '名称')),
      TextField(controller: latitude, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'WGS84 纬度')),
      TextField(controller: longitude, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: InputDecoration(labelText: 'WGS84 经度', errorText: error)),
      const Text('默认使用当前查看位置，也可填写 GPS 坐标。'),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')), FilledButton(onPressed: () {
      final a = double.tryParse(latitude.text), b = double.tryParse(longitude.text);
      if (label.text.trim().isEmpty || a == null || b == null || !a.isFinite || !b.isFinite || a.abs() > 90 || b.abs() > 180) { set(() => error = '请填写名称和有效坐标'); return; }
      Navigator.pop(ctx, {'name': label.text.trim(), 'lat': a, 'lng': b});
    }, child: const Text('保存'))])));
    if (point != null) await widget.state.savePlaces([...widget.state.places, point]);
  }
  void external() => showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
    for (final entry in {'amap': '高德地图', 'baidu': '百度地图', 'system': '选择地图软件（含腾讯地图）'}.entries) ListTile(leading: const Icon(Icons.map_outlined), title: Text(entry.value), onTap: () async {
      Navigator.pop(ctx);
      try { await PlatformTools.openMap(lat, lon, name, entry.key); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('打开失败：$e'))); }
    }),
  ])));
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(18, 20, 18, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('校园地图', style: Theme.of(context).textTheme.headlineMedium), const Text('高德官方地图 · GPS 坐标自动转换'),
      Wrap(spacing: 8, children: [TextButton.icon(onPressed: locate, icon: const Icon(Icons.my_location), label: const Text('定位')), TextButton.icon(onPressed: external, icon: const Icon(Icons.open_in_new), label: const Text('用地图软件打开')), TextButton.icon(onPressed: add, icon: const Icon(Icons.add_location_alt_outlined), label: const Text('添加标签'))]),
    ])),
    ListenableBuilder(listenable: widget.state, builder: (context, _) => SizedBox(height: 50, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 18), children: [
      ActionChip(label: const Text('校园'), onPressed: () { lat = 39.95655; lon = 116.79699; name = '应急管理大学（华北科技学院）'; load(); }), const SizedBox(width: 8),
      ...widget.state.places.asMap().entries.map((entry) => Padding(padding: const EdgeInsets.only(right: 8), child: InputChip(label: Text('${entry.value['name']}'), onPressed: () {
        lat = (entry.value['lat'] as num).toDouble(); lon = ((entry.value['lng'] ?? entry.value['lon']) as num).toDouble(); name = '${entry.value['name']}'; load();
      }, onDeleted: () => widget.state.savePlaces(List.of(widget.state.places)..removeAt(entry.key))))),
    ]))),
    if (progress < 100) LinearProgressIndicator(value: progress / 100),
    if (error != null) ListTile(title: Text(error!), trailing: IconButton(onPressed: load, icon: const Icon(Icons.refresh))),
    Expanded(child: WebViewWidget(controller: controller)),
  ]);
}
