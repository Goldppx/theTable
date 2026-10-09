import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_table/auth/campus_http.dart';
import 'package:the_table/auth/session_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('the_table/campus_session');
  final calls = <MethodCall>[];
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  void session(List<Map<String, String>> cookies) {
    FlutterSecureStorage.setMockInitialValues({CampusHttp.sessionKey: jsonEncode({
      'studentKind': 'undergraduate', 'studentNumber': 'fixture', 'cookies': cookies,
    })});
  }
  setUp(() {
    calls.clear();
    FlutterSecureStorage.setMockInitialValues({});
    messenger.setMockMethodCallHandler(channel, (call) async { calls.add(call); return null; });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('bridge sends live cookies and filters expiration and deletion headers', () async {
    session([
      {'uri': 'https://jw.cidp.edu.cn/LoginHandler.ashx', 'cookie': 'EXESAC.SAAS.SessionId=live; Path=/; Secure; HttpOnly'},
      {'uri': 'https://auth.ncist.edu.cn/authserver/login', 'cookie': 'OLD=expired; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT'},
      {'uri': 'https://my1.ncist.edu.cn/login', 'cookie': 'DELETED=; Path=/; Max-Age=0'},
    ]);
    expect(await CampusSessionBridge.restoreToWebView(), 'undergraduate');
    final records = calls.single.arguments as List;
    expect(records, hasLength(1));
    expect((records.single as Map)['cookie'], contains('EXESAC.SAAS.SessionId=live'));
    expect((records.single as Map)['cookie'], contains('HttpOnly'));
    expect((records.single as Map)['cookie'], contains('Secure'));
  });
  test('missing session requires authentication before native import', () async {
    await expectLater(CampusSessionBridge.restoreToWebView(), throwsFormatException);
    expect(calls, isEmpty);
  });
  test('fully expired session requires authentication before native import', () async {
    session([{'uri': 'https://jw.cidp.edu.cn/', 'cookie': 'EXESAC.SAAS.SessionId=old; Expires=Thu, 01 Jan 1970 00:00:00 GMT'}]);
    await expectLater(CampusSessionBridge.restoreToWebView(), throwsFormatException);
    expect(calls, isEmpty);
  });
  test('native cookie rejection remains actionable rather than reporting success', () async {
    session([{'uri': 'https://jw.cidp.edu.cn/', 'cookie': 'EXESAC.SAAS.SessionId=live; Path=/'}]);
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'COOKIE_REJECTED', message: 'fixture rejection');
    });
    await expectLater(CampusSessionBridge.restoreToWebView(), throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'COOKIE_REJECTED')));
  });
}
