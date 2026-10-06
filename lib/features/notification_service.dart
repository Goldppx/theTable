import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/course.dart';
import 'notification_plan.dart';
import 'preferences.dart';
import 'platform_tools.dart';

class NotificationService with WidgetsBindingObserver {
  final plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false, _active = true;
  NotificationPreferences _prefs = const NotificationPreferences();
  HttpClient? _stream;
  Timer? _timer;
  int _generation = 0;
  Future<void> initialize() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    final zone = await PlatformTools.channel.invokeMethod<String>('timezone') ?? 'Asia/Shanghai';
    tz.setLocalLocation(tz.getLocation(zone));
    await plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('@drawable/notification_icon')));
    WidgetsBinding.instance.addObserver(this);
    _ready = true;
  }
  Future<bool> permission() async {
    await initialize();
    return await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission() ?? false;
  }
  Future<void> synchronize(List<Course> courses, DateTime start, int weeks, NotificationPreferences prefs) async {
    await initialize();
    _prefs = prefs;
    await plugin.cancelAll();
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final exact = await android?.canScheduleExactNotifications() ?? false;
    var id = 1000;
    for (final item in NotificationPlan.build(courses, start, weeks, prefs, DateTime.now())) {
      await plugin.zonedSchedule(id++, item.title, item.body, tz.TZDateTime.from(item.time, tz.local),
        NotificationDetails(android: AndroidNotificationDetails(item.kind == 'course' ? 'course_reminders' : 'morning_brief', item.kind == 'course' ? '课前提醒' : '每日早报',
          channelDescription: '根据本机课表安排', importance: Importance.high, priority: Priority.high, styleInformation: BigTextStyleInformation(item.body))),
        androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle);
    }
    await PlatformTools.channel.invokeMethod<void>('apiConfig', {'enabled': prefs.api, 'url': prefs.apiUrl, 'token': prefs.token, 'sse': prefs.sse});
    _restartForeground();
  }
  Future<void> exactPermission() async { await initialize(); await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestExactAlarmsPermission(); }
  Future<void> test() async { await initialize(); await plugin.show(99, '通知测试', '校园通知已准备好', const NotificationDetails(android: AndroidNotificationDetails('test', '通知测试', importance: Importance.high))); }
  void _restartForeground() {
    _generation++; _stream?.close(force: true); _stream = null; _timer?.cancel(); _timer = null;
    if (!_prefs.api || !_active || _prefs.apiUrl.isEmpty) return;
    if (_prefs.sse) { _listen(_generation); }
    else {
      _check(); _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
    }
  }
  Future<void> _check() async { try { await PlatformTools.channel.invokeMethod<void>('apiCheck'); } catch (_) { /* Background retry remains enabled. */ } }
  Future<void> checkNow() => PlatformTools.channel.invokeMethod<void>('apiCheck');
  Future<void> _listen(int generation) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 15); _stream = client;
      final uri = Uri.parse(_prefs.apiUrl);
      if (uri.scheme != 'https') return;
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      request.headers.set('Accept', 'text/event-stream');
      if (_prefs.token.isNotEmpty) request.headers.set('Authorization', 'Bearer ${_prefs.token}');
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw const FormatException('SSE unavailable');
      final data = <String>[];
      await for (final line in response.transform(utf8.decoder).transform(const LineSplitter())) {
        if (generation != _generation) break;
        if (line.startsWith('data:')) data.add(line.substring(5).trimLeft());
        if (line.isEmpty && data.isNotEmpty) {
          final body = data.join('\n'); data.clear();
          try {
            final message = jsonDecode(body);
            if (message is Map) await PlatformTools.channel.invokeMethod<void>('apiMessage', Map<String, dynamic>.from(message));
          } catch (_) { /* Ignore malformed events. */ }
        }
      }
    } catch (_) { /* Reconnect below. */ }
    finally {
      client?.close(force: true);
      if (generation == _generation && _active && _prefs.api) _timer = Timer(const Duration(seconds: 10), () => _listen(generation));
    }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { _active = state == AppLifecycleState.resumed; _restartForeground(); }
  void dispose() { if (_ready) WidgetsBinding.instance.removeObserver(this); _generation++; _stream?.close(force: true); _timer?.cancel(); }
}
