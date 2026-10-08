import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CampusResponse {
  const CampusResponse(this.uri, this.status, this.body, {this.location});
  final Uri uri;
  final int status;
  final String body;
  final String? location;
  bool get ok => status >= 200 && status < 300;
  bool get isRedirect => const [301, 302, 303, 307, 308].contains(status);
}

abstract class CampusTransport {
  Future<CampusResponse> request(Uri uri, {String method = 'GET', Map<String, String> headers = const {}, String? body});
  Future<List<Cookie>> cookies(Uri uri);
}

/// Same-origin cookie matching, including HttpOnly, Secure, path and expiration.
class CampusHttp implements CampusTransport {
  CampusHttp({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();
  static const sessionKey = 'campus_native_session_v1';
  static const hosts = {'auth.ncist.edu.cn', 'my1.ncist.edu.cn', 'jw.cidp.edu.cn', 'gms.ncist.edu.cn'};
  final FlutterSecureStorage _storage;
  final CookieJar _jar = CookieJar();
  final HttpClient _client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  final Map<String, Map<String, String>> _records = {};

  static Uri trusted(Uri uri) {
    if (uri.host == 'auth.ncist.edu.cn' && uri.scheme == 'http') uri = uri.replace(scheme: 'https');
    if (uri.scheme != 'https' || !hosts.contains(uri.host) || uri.userInfo.isNotEmpty || uri.port != 443) {
      throw const FormatException('学校认证返回了无法接受的跳转');
    }
    return uri;
  }
  @override
  Future<List<Cookie>> cookies(Uri uri) => _jar.loadForRequest(trusted(uri));

  @override
  Future<CampusResponse> request(Uri uri, {String method = 'GET', Map<String, String> headers = const {}, String? body}) async {
    uri = trusted(uri);
    final request = await _client.openUrl(method, uri).timeout(const Duration(seconds: 20));
    request.followRedirects = false;
    request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36');
    headers.forEach((name, value) => request.headers.set(name, value));
    request.cookies.addAll(await cookies(uri));
    if (body != null) request.add(utf8.encode(body));
    final response = await request.close().timeout(const Duration(seconds: 20));
    await _jar.saveFromResponse(uri, response.cookies);
    for (final original in response.cookies) {
      final cookie = Cookie.fromSetCookieValue(original.toString());
      if (cookie.maxAge != null) {
        cookie.expires = DateTime.now().toUtc().add(Duration(seconds: cookie.maxAge!));
        cookie.maxAge = null;
      }
      final domain = cookie.domain ?? uri.host;
      final path = cookie.path ?? '/';
      _records['$domain|$path|${cookie.name}'] = {'uri': uri.toString(), 'cookie': cookie.toString()};
    }
    final text = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 20));
    return CampusResponse(uri, response.statusCode, text, location: response.headers.value(HttpHeaders.locationHeader));
  }
  Future<void> resetTransientCookies() async {
    await _jar.deleteAll();
    _records.clear();
  }
  Future<void> persist(String studentNumber, String studentKind) => _storage.write(key: sessionKey,
      value: jsonEncode({'studentNumber': studentNumber, 'studentKind': studentKind, 'cookies': _records.values.toList()}));

  Future<String?> restore() async {
    final raw = await _storage.read(key: sessionKey);
    if (raw == null) return null;
    final root = jsonDecode(raw) as Map;
    for (final item in root['cookies'] as List) {
      final uri = trusted(Uri.parse(item['uri'] as String));
      final cookie = Cookie.fromSetCookieValue(item['cookie'] as String);
      if (cookie.maxAge != null && cookie.maxAge! <= 0) continue;
      if (cookie.expires != null && !cookie.expires!.isAfter(DateTime.now())) continue;
      await _jar.saveFromResponse(uri, [cookie]);
      _records['${cookie.domain ?? uri.host}|${cookie.path ?? '/'}|${cookie.name}'] = {'uri': uri.toString(), 'cookie': cookie.toString()};
    }
    return root['studentKind'] as String?;
  }
  /// Export only records restored as live cookies, never saved deletion headers.
  List<Map<String, String>> get webViewCookies =>
      _records.values.map((record) => Map<String, String>.from(record)).toList();

  static Future<void> clearSession() => const FlutterSecureStorage().delete(key: sessionKey);
  void close() => _client.close(force: true);
}
