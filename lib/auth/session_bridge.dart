import 'package:flutter/services.dart';
import 'campus_http.dart';

/// Android native CookieManager preserves Secure/HttpOnly/Path attributes.
class CampusSessionBridge {
  static const _channel = MethodChannel('the_table/campus_session');
  static Future<String?> restoreToWebView() async {
    final client = CampusHttp();
    try {
      final kind = await client.restore();
      if (kind == null || client.webViewCookies.isEmpty) {
        throw const FormatException('校园会话已过期，请重新认证');
      }
      await _channel.invokeMethod<void>('setCookies', client.webViewCookies)
          .timeout(const Duration(seconds: 20));
      return kind;
    } finally { client.close(); }
  }
  static Future<void> clear() async {
    await CampusHttp.clearSession();
    await _channel.invokeMethod<void>('clearCookies');
  }
}
