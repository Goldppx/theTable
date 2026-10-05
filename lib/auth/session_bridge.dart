import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'campus_http.dart';

/// Android native CookieManager preserves Secure/HttpOnly/Path attributes.
class CampusSessionBridge {
  static const _channel = MethodChannel('the_table/campus_session');
  static Future<String?> restoreToWebView() async {
    final client = CampusHttp();
    try {
      final kind = await client.restore();
      final raw = await const FlutterSecureStorage().read(key: CampusHttp.sessionKey);
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map;
      await _channel.invokeMethod<void>('setCookies', data['cookies']);
      return kind;
    } finally { client.close(); }
  }
  static Future<void> clear() async {
    await CampusHttp.clearSession();
    await _channel.invokeMethod<void>('clearCookies');
  }
}
