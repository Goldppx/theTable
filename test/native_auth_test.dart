import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_table/auth/campus_auth.dart';
import 'package:the_table/auth/campus_http.dart';
import 'package:the_table/auth/cas_protocol.dart';
import 'package:the_table/auth/native_auth.dart';

const fixture = '''<script>var captchaSwitch = "2";</script>
<form id="pwdFromId" action="/authserver/login"><input id="pwdEncryptSalt" value="1234567890abcdef">
<input name="execution" value="e1s1"><input name="lt" value=""></form>''';
class FakeCampus implements CampusTransport {
  FakeCampus({this.needCaptcha = false, this.ticket = true, this.businessSession = true, this.graduate = false});
  final bool needCaptcha, ticket, businessSession, graduate;
  final jar = CookieJar();
  final calls = <Map<String, Object?>>[];
  @override
  Future<List<Cookie>> cookies(Uri uri) => jar.loadForRequest(uri);
  @override
  Future<CampusResponse> request(Uri uri, {String method = 'GET', Map<String, String> headers = const {}, String? body}) async {
    calls.add({'uri': uri, 'method': method, 'headers': headers, 'body': body});
    if (uri.host == 'auth.ncist.edu.cn' && uri.path == '/authserver/login') {
      if (method == 'POST') {
        return CampusResponse(uri, 302, '', location: 'https://my1.ncist.edu.cn/login${ticket ? '?ticket=ST-test' : ''}');
      }
      if (uri.queryParameters['service'] == 'https://gms.ncist.edu.cn/') {
        return CampusResponse(uri, 302, '', location: 'https://gms.ncist.edu.cn/');
      }
      await jar.saveFromResponse(uri, [Cookie('JSESSIONID', 'cas')..path = '/authserver'..httpOnly = true..secure = true]);
      return CampusResponse(uri, 200, fixture);
    }
    if (uri.path.endsWith('checkNeedCaptcha.htl')) return CampusResponse(uri, 200, jsonEncode({'isNeed': needCaptcha}));
    if (uri.path.endsWith('toSliderCaptcha.htl')) return CampusResponse(uri, 200, 'slider');
    if (uri.path.endsWith('openSliderCaptcha.htl')) return CampusResponse(uri, 200, jsonEncode({'bigImage': base64Encode([1, 2, 3]), 'smallImage': base64Encode(utf8.encode('png1234567890abcdef')), 'tagWidth': 90}));
    if (uri.path.endsWith('verifySliderCaptcha.htl')) return CampusResponse(uri, 200, '{"errorCode":1}');
    if (uri.host == 'my1.ncist.edu.cn' && uri.path == '/login') {
      await jar.saveFromResponse(uri, [Cookie('PORTAL', 'portal')..path = '/'..httpOnly = true..secure = true]);
      return CampusResponse(uri, 302, '', location: '/xs/index.html#/');
    }
    if (uri.path == '/getLoginUser') return CampusResponse(uri, 200, jsonEncode({'errcode': 0, 'data': {'userNo': '202500000001', 'userName': '测试学生', 'categoryName': graduate ? '研究生' : '本科生'}}));
    if (uri.host == 'jw.cidp.edu.cn' && businessSession) {
      await jar.saveFromResponse(uri, [Cookie('EXESAC.SAAS.SessionId', 'jw-session')..path = '/'..httpOnly = true..secure = true]);
    }
    if (uri.host == 'gms.ncist.edu.cn' && businessSession) {
      await jar.saveFromResponse(uri, [Cookie('JSESSIONID', 'gms')..path = '/', Cookie('SSO_LOGIN', 'gms-sso')..path = '/']);
    }
    return CampusResponse(uri, 200, 'business');
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('CAS page selects password form rather than other login methods', () {
    final page = CasPage.parse('<form><input name="execution" value="wrong"></form>$fixture');
    expect(page.execution, 'e1s1'); expect(page.lt, ''); expect(page.captchaSwitch, '2');
    expect(() => CasPage.parse('<html>maintenance</html>'), throwsFormatException);
  });
  test('live mobile template selects password form among duplicate IDs', () {
    final mobile = '<form id="loginFromId"><input name="cllt" value="dynamicLogin"><input name="execution" value="wrong"></form>'
        '<form id="loginFromId"><input name="cllt" value="userNameLogin"><input id="pwdEncryptSalt" value="1234567890abcdef"><input name="execution" value="e1s1"></form>';
    expect(CasPage.parse(mobile).execution, 'e1s1');
  });
  test('AES CBC matches independent Python cryptography vector', () {
    expect(CasCrypto.encrypt('test-password', '1234567890abcdef', prefix: 'A' * 64, iv: 'abcdefghijklmnop'),
      'omsif+RTzQ4iexPULRJF313OyxPVfv2rxJqU8+dJhMlT9Afc249jsarEhEbnegTqambD8laPAeeOChP9D8bAWxSScQ4BZnvgzYW3ctf1mzg=');
    expect(() => CasCrypto.encrypt('test', 'bad'), throwsFormatException);
  });
  test('slider signature uses final 16 image bytes and actual track JSON', () {
    final payload = {'canvasLength': 280, 'moveLength': 100, 'tracks': [{'a': 0, 'b': 0, 'c': 0}, {'a': 100, 'b': 1, 'c': 600}]};
    expect(CasCrypto.sliderSign(payload, base64Encode(utf8.encode('image1234567890abcdef')), prefix: 'A' * 64, iv: 'abcdefghijklmnop'),
      'omsif+RTzQ4iexPULRJF313OyxPVfv2rxJqU8+dJhMlT9Afc249jsarEhEbnegTqambD8laPAeeOChP9D8bAW1GOPPP6re9aWDxRY8I3CzGaNRGSC7MuklCIOgVww1QO+EQF/w2gbqUcqgLd4YmTBtVQUNB6rCT0xbZyJe+qvPf0PusXttG6gKkyxL2mo55/eAP/Bf8KuVabObKkngW7Xw==');
  });
  test('native login completes CAS portal and undergraduate session', () async {
    final http = FakeCampus(); final native = NativeCampusAuth(auth: CampusAuthService(), http: http);
    await native.prepare('202500000001');
    final profile = await native.submit('202500000001', 'test-password');
    expect(profile.name, '测试学生');
    final post = http.calls.firstWhere((call) => call['method'] == 'POST');
    final body = Uri.splitQueryString(post['body'] as String);
    expect(body['username'], '202500000001'); expect(body['password'], isNot('test-password'));
    expect(body['cllt'], 'userNameLogin'); expect(body['execution'], 'e1s1');
    expect(http.calls.any((call) => (call['uri'] as Uri).path == '/LoginHandler.ashx'), isTrue);
  });
  test('slider must be verified before posting credentials', () async {
    final http = FakeCampus(needCaptcha: true); final native = NativeCampusAuth(auth: CampusAuthService(), http: http);
    await native.prepare('202500000001');
    await expectLater(native.submit('202500000001', 'test-password'), throwsFormatException);
    expect(http.calls.where((call) => call['method'] == 'POST'), isEmpty);
    expect(await native.verifySlider({'canvasLength': 280, 'moveLength': 100, 'tracks': [{'a': 0, 'b': 0, 'c': 0}, {'a': 100, 'b': 1, 'c': 600}]}), isTrue);
    await native.submit('202500000001', 'test-password');
  });
  test('CAS ticket and business cookie are required for login success', () async {
    for (final http in [FakeCampus(ticket: false), FakeCampus(businessSession: false)]) {
      final native = NativeCampusAuth(auth: CampusAuthService(), http: http);
      await native.prepare('202500000001');
      await expectLater(native.submit('202500000001', 'test-password'), throwsFormatException);
    }
  });
  test('graduate flow establishes its own authenticated service', () async {
    final http = FakeCampus(graduate: true); final native = NativeCampusAuth(auth: CampusAuthService(), http: http);
    await native.prepare('202500000001'); await native.submit('202500000001', 'test-password');
    expect(http.calls.any((call) => (call['uri'] as Uri).host == 'gms.ncist.edu.cn'), isTrue);
    expect(NativeCampusAuth.studentKind({'data': {'categoryWid': '2000002'}}), 'graduate');
  });
  test('trusted redirects upgrade original HTTP CAS and reject foreign hosts', () {
    expect(CampusHttp.trusted(Uri.parse('http://auth.ncist.edu.cn/authserver/login')).scheme, 'https');
    for (final url in ['https://example.com/', 'http://my1.ncist.edu.cn/', 'https://auth.ncist.edu.cn:444/', 'https://user:pass@auth.ncist.edu.cn/']) {
      expect(() => CampusHttp.trusted(Uri.parse(url)), throwsFormatException);
    }
  });
  test('cookie matching preserves scope expiration and HttpOnly', () async {
    final jar = CookieJar(); final uri = Uri.parse('https://auth.ncist.edu.cn/authserver/login');
    await jar.saveFromResponse(uri, [Cookie('JSESSIONID', 'fixture')..path = '/authserver'..secure = true..httpOnly = true]);
    expect((await jar.loadForRequest(uri)).single.httpOnly, isTrue);
    expect(await jar.loadForRequest(Uri.parse('https://my1.ncist.edu.cn/')), isEmpty);
    expect(await jar.loadForRequest(Uri.parse('https://auth.ncist.edu.cn/other')), isEmpty);
    await jar.saveFromResponse(uri, [Cookie('JSESSIONID', 'expired')..path = '/authserver'..maxAge = 0]);
    expect(await jar.loadForRequest(uri), isEmpty);
  });
}
