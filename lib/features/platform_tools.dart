import 'package:flutter/services.dart';
import 'preferences.dart';

class PlatformTools {
  static const channel = MethodChannel('the_table/tools');
  static Future<void> open(Shortcut shortcut) => channel.invokeMethod<void>('open', shortcut.toJson());
  static Future<List<Map<String, dynamic>>> installedApps() async {
    final list = await channel.invokeListMethod<dynamic>('apps') ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  static Future<void> openMap(double lat, double lon, String name, String provider) => channel.invokeMethod<void>('map', {'lat': lat, 'lon': lon, 'name': name, 'provider': provider});
  static String amapUri(double lat, double lon, String name) => Uri.https('uri.amap.com', '/marker', {
    'position': '$lon,$lat', 'name': name, 'coordinate': 'wgs84', 'src': 'theTable', 'callnative': '0',
  }).toString();
}
