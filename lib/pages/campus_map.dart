import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/app_state.dart';

class CampusMapPage extends StatefulWidget {
  const CampusMapPage({required this.state, super.key});
  final CampusState state;
  @override
  State<CampusMapPage> createState() => _CampusMapPageState();
}
class _CampusMapPageState extends State<CampusMapPage> {
  final controller = MapController();
  static const campus = LatLng(39.95655, 116.79699);
  bool satellite = false, locating = false, tileError = false;
  LatLng? position;
  String locationStatus = '长按地图添加地点';
  Future<void> locate() async {
    setState(() { locating = true; locationStatus = '正在定位…'; });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw StateError('请开启设备定位服务');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw StateError('请在系统设置中允许定位权限');
      }
      final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)));
      if (!mounted) return;
      position = LatLng(p.latitude, p.longitude);
      controller.move(position!, 17);
      setState(() => locationStatus = '已定位 · 精度约 ${p.accuracy.round()} 米');
    } catch (e) { if (mounted) setState(() => locationStatus = '定位失败：$e'); }
    finally { if (mounted) setState(() => locating = false); }
  }
  Future<void> add(LatLng point) async {
    final text = TextEditingController();
    final name = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: const Text('新增地图标签'),
      content: TextField(controller: text, autofocus: true, maxLength: 30,
        decoration: const InputDecoration(labelText: '地点名称', hintText: '图书馆、食堂、教学楼…')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () { if (text.text.trim().isNotEmpty) Navigator.pop(ctx, text.text.trim()); }, child: const Text('保存'))]));
    if (name != null) {
      await widget.state.savePlaces([...widget.state.places,
        {'name': name, 'latitude': point.latitude, 'longitude': point.longitude}]);
    }
  }
  void manage() => showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => ListenableBuilder(
    listenable: widget.state, builder: (ctx, _) => SafeArea(child: ListView(shrinkWrap: true, children: [
      const ListTile(title: Text('管理地图标签', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
      if (widget.state.places.isEmpty) const ListTile(title: Text('长按地图添加你的校园地点')),
      ...widget.state.places.asMap().entries.map((entry) => ListTile(title: Text('${entry.value['name']}'),
        onTap: () { controller.move(LatLng((entry.value['latitude'] as num).toDouble(), (entry.value['longitude'] as num).toDouble()), 18); Navigator.pop(ctx); },
        trailing: IconButton(tooltip: '删除标签', icon: const Icon(Icons.delete_outline), onPressed: () async {
          final updated = [...widget.state.places]..removeAt(entry.key);
          await widget.state.savePlaces(updated);
        }))),
    ]))));
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(18, 24, 18, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('校园地图', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 6),
        Text('查看当前位置，可切换平面与卫星图', style: Theme.of(context).textTheme.bodyLarge), const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: SegmentedButton<bool>(showSelectedIcon: false,
          segments: const [ButtonSegment(value: false, label: Text('平面')), ButtonSegment(value: true, label: Text('卫星'))],
          selected: {satellite}, onSelectionChanged: (v) => setState(() { satellite = v.first; tileError = false; }))),
        Row(children: [Expanded(child: Text('长按地图可新增标签', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant))),
          TextButton.icon(onPressed: manage, icon: const Icon(Icons.tune, size: 18), label: Text('管理（${widget.state.places.length}）'))]),
        if (widget.state.places.isNotEmpty) SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal,
          children: widget.state.places.map((p) => Padding(padding: const EdgeInsets.only(right: 6),
            child: ActionChip(label: Text('${p['name']}'), onPressed: () => controller.move(
              LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble()), 18)))).toList())),
      ])),
      Expanded(child: Stack(children: [
        FlutterMap(mapController: controller, options: MapOptions(initialCenter: campus, initialZoom: 16,
          maxZoom: 19, onLongPress: (_, point) => add(point)), children: [
          TileLayer(key: ValueKey(satellite),
            urlTemplate: satellite ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'cn.edu.ncist.it.the_table', maxNativeZoom: satellite ? 18 : 19,
            errorTileCallback: (tile, error, stackTrace) { if (!tileError && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => tileError = true); });
            }}),
          MarkerLayer(markers: [
            Marker(point: campus, width: 130, height: 54, child: Column(children: [
              const Icon(Icons.school, color: Colors.blue, size: 28),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), color: Colors.white,
                child: const Text('华北科技学院', style: TextStyle(color: Colors.black, fontSize: 11))),
            ])),
            ...widget.state.places.map((p) => Marker(
              point: LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble()),
              width: 130, height: 64, child: Column(children: [
                const Icon(Icons.location_on, color: Color(0xff3894ef), size: 38),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), color: Colors.white,
                  child: Text('${p['name']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black, fontSize: 11))),
              ]))),
            if (position != null) Marker(point: position!, width: 28, height: 28,
              child: Container(decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3)))),
          ]),
        ]),
        if (tileError) Positioned(top: 8, left: 12, right: 12, child: Card(child: Padding(
          padding: const EdgeInsets.all(10), child: Text('地图加载失败，请检查网络或切换图层', style: TextStyle(color: colors.error))))),
        Positioned(left: 12, bottom: 30, right: 76, child: Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xff191e23), borderRadius: BorderRadius.circular(14)),
          child: Text(locationStatus, style: const TextStyle(color: Colors.white, fontSize: 12)))),
        Positioned(right: 14, bottom: 34, child: FloatingActionButton.small(heroTag: 'location', onPressed: locating ? null : locate,
          tooltip: '定位当前位置', child: locating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location))),
        Positioned(right: 14, top: 12, child: IconButton.filled(tooltip: '回到校园', onPressed: () => controller.move(campus, 16), icon: const Icon(Icons.school_outlined))),
        Positioned(bottom: 0, left: 0, right: 0, child: Container(color: Colors.white.withValues(alpha: .9), padding: const EdgeInsets.all(4),
          child: Text(satellite ? 'Imagery © Esri, Maxar, Earthstar Geographics' : '© OpenStreetMap contributors',
            style: const TextStyle(color: Colors.black, fontSize: 10)))),
      ])),
    ]);
  }
}
