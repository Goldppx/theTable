import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../auth/campus_auth.dart';
import '../models/course.dart';

class CampusState extends ChangeNotifier {
  CampusState({this.persist = true});
  final bool persist;
  final _storage = const FlutterSecureStorage();
  List<Course> courses = [];
  CampusProfile? profile;
  List<Map<String, dynamic>> places = [];
  DateTime semesterStart = DateTime(2026, 9, 7);
  DateTime? syncedAt;
  int totalWeeks = 20;
  ThemeMode themeMode = ThemeMode.dark;
  bool dynamicColor = true;
  bool ready = false;
  String? storageError;
  String get _key => 'schedule_v2_${profile?.studentNumber ?? 'guest'}';
  int get currentWeek => ((DateTime.now().difference(semesterStart).inDays ~/ 7) + 1).clamp(1, totalWeeks);

  Future<void> restore() async {
    try {
      if (persist) {
        profile = await CampusAuthService().restoreProfile();
        final prefs = await _storage.read(key: 'appearance_v2');
        if (prefs != null) {
          final p = jsonDecode(prefs) as Map;
          themeMode = ThemeMode.values.firstWhere((v) => v.name == p['mode'], orElse: () => ThemeMode.dark);
          dynamicColor = p['dynamic'] != false;
        }
        final pins = await _storage.read(key: 'map_places_v2');
        if (pins != null) places = (jsonDecode(pins) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        await _loadSchedule();
      }
    } catch (_) { storageError = '本地数据读取失败，请重新导入课表'; }
    ready = true;
    notifyListeners();
  }
  Future<void> _loadSchedule() async {
    courses = []; syncedAt = null;
    final raw = await _storage.read(key: _key);
    if (raw != null) {
      final data = jsonDecode(raw) as Map;
      courses = (data['courses'] as List).map((e) => Course.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      semesterStart = DateTime.parse(data['semesterStart'] as String);
      totalWeeks = (data['totalWeeks'] as int).clamp(1, 30);
      syncedAt = DateTime.tryParse('${data['syncedAt']}');
    }
  }
  Future<void> setProfile(CampusProfile value) async {
    profile = value;
    if (persist) await _loadSchedule();
    notifyListeners();
  }
  Future<void> importSchedule(String raw) async {
    final decoded = jsonDecode(raw);
    final List items;
    var start = semesterStart;
    var count = totalWeeks;
    if (decoded is List) { items = decoded; }
    else if (decoded is Map && decoded['courses'] is List) {
      items = decoded['courses'] as List;
      if (decoded['semesterStart'] != null) start = DateTime.parse(decoded['semesterStart'] as String);
      if (decoded['totalWeeks'] != null) {
        count = int.tryParse('${decoded['totalWeeks']}') ?? 0;
        if (count < 1 || count > 30) throw const FormatException('学期周数范围为 1–30');
      }
    } else { throw const FormatException('请导入课程 JSON 数组或含 courses 的对象'); }
    final parsed = items.map((e) => Course.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    // Validate the complete document before replacing the existing cache.
    final stamp = DateTime.now();
    final payload = jsonEncode({'courses': parsed.map((c) => c.toJson()).toList(),
      'semesterStart': start.toIso8601String(), 'totalWeeks': count, 'syncedAt': stamp.toIso8601String()});
    if (persist) await _storage.write(key: _key, value: payload);
    courses = parsed; semesterStart = start; totalWeeks = count; syncedAt = stamp;
    notifyListeners();
  }
  Future<void> setSemester(DateTime start) async {
    await importSchedule(jsonEncode({'courses': courses.map((c) => c.toJson()).toList(),
      'semesterStart': start.toIso8601String(), 'totalWeeks': totalWeeks}));
  }
  Future<void> appearance(ThemeMode mode, bool dynamic) async {
    if (persist) await _storage.write(key: 'appearance_v2', value: jsonEncode({'mode': mode.name, 'dynamic': dynamic}));
    themeMode = mode; dynamicColor = dynamic; notifyListeners();
  }
  Future<void> clearAccount() async {
    if (persist) {
      await _storage.delete(key: _key);
      await CampusAuthService().clearProfile();
    }
    profile = null; courses = []; syncedAt = null;
    if (persist) await _loadSchedule();
    notifyListeners();
  }
  Future<void> savePlaces(List<Map<String, dynamic>> value) async {
    if (persist) await _storage.write(key: 'map_places_v2', value: jsonEncode(value));
    places = value; notifyListeners();
  }
}
