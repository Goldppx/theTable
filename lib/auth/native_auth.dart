import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'campus_auth.dart';
import 'campus_http.dart';
import 'cas_protocol.dart';

class NativeCampusAuth {
  NativeCampusAuth({required this.auth, required this.http});
  final CampusAuthService auth;
  final CampusTransport http;
  CasPage? page;
  bool captchaRequired = false, sliderVerified = false;
  SliderChallenge? challenge;
  String? _preparedUsername;
  final _jsonHeaders = <String, String>{'Accept': 'application/json, text/plain, */*', 'X-Requested-With': 'XMLHttpRequest'};

  Future<CampusResponse> _follow(CampusResponse response, {bool requireTicket = false}) async {
    var ticket = false;
    for (var count = 0; response.isRedirect; count++) {
      if (count >= 12) throw const FormatException('认证跳转次数过多');
      if (response.location == null) throw const FormatException('认证跳转缺少地址');
      final next = CampusHttp.trusted(response.uri.resolve(response.location!));
      if ((next.queryParameters['ticket'] ?? '').startsWith('ST-')) ticket = true;
      response = await http.request(next, headers: {'Accept': 'text/html,application/xhtml+xml', 'Referer': response.uri.toString()});
    }
    if (requireTicket && !ticket) throw const FormatException('统一认证缺少 CAS 票据，请重新登录');
    return response;
  }
  Map<String, dynamic> _json(CampusResponse response) {
    if (!response.ok) throw FormatException('学校服务返回 HTTP ${response.status}，请稍后重试');
    final value = jsonDecode(response.body);
    if (value is! Map) throw const FormatException('学校服务返回的数据格式异常');
    return Map<String, dynamic>.from(value);
  }
  Future<void> prepare(String username) async {
    _preparedUsername = null;
    page = null; challenge = null; sliderVerified = false;
    final response = await _follow(await http.request(auth.loginUri, headers: {'Accept': 'text/html,application/xhtml+xml'}));
    if (!response.ok || response.uri.host != 'auth.ncist.edu.cn') throw const FormatException('无法取得统一认证登录会话');
    page = CasPage.parse(response.body);
    final result = _json(await http.request(Uri.parse('${CampusAuthService.authOrigin}/authserver/checkNeedCaptcha.htl').replace(queryParameters: {'username': username}),
      headers: {..._jsonHeaders, 'Referer': auth.loginUri.toString()}));
    captchaRequired = result['isNeed'] == true || result['isNeed'] == 'true';
    if (captchaRequired) {
      if (page!.captchaSwitch != '2') throw const FormatException('学校启用了其他验证码类型，请稍后重试');
      await refreshSlider();
    }
    _preparedUsername = username;
  }
  Future<void> refreshSlider() async {
    sliderVerified = false;
    final headers = {..._jsonHeaders, 'Referer': auth.loginUri.toString()};
    final component = await http.request(Uri.parse('${CampusAuthService.authOrigin}/authserver/common/toSliderCaptcha.htl'), headers: headers);
    if (!component.ok) throw const FormatException('滑块组件暂时不可用');
    challenge = SliderChallenge.fromJson(_json(await http.request(Uri.parse('${CampusAuthService.authOrigin}/authserver/common/openSliderCaptcha.htl'), headers: headers)));
  }
  Future<bool> verifySlider(Map<String, dynamic> payload) async {
    final current = challenge;
    if (current == null) throw const FormatException('请先获取滑块');
    final response = await http.request(Uri.parse('${CampusAuthService.authOrigin}/authserver/common/verifySliderCaptcha.htl'), method: 'POST',
      headers: {..._jsonHeaders, 'Referer': auth.loginUri.toString(), 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'},
      body: formBody({'sign': CasCrypto.sliderSign(payload, current.smallImage)}));
    final result = _json(response);
    sliderVerified = result['errorCode'] == 1 || result['errorCode'] == '1';
    return sliderVerified;
  }
  Future<CampusProfile> submit(String username, String password) async {
    if (_preparedUsername != username || page == null) throw const FormatException('请重新准备登录会话');
    if (captchaRequired && !sliderVerified) throw const FormatException('请拖动滑块完成验证');
    final current = page!;
    final response = await http.request(auth.loginUri, method: 'POST', headers: {
      'Accept': 'text/html,application/xhtml+xml', 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      'Origin': CampusAuthService.authOrigin, 'Referer': auth.loginUri.toString(),
    }, body: formBody({'username': username, 'password': CasCrypto.encrypt(password, current.salt), 'captcha': '',
      '_eventId': 'submit', 'cllt': 'userNameLogin', 'dllt': 'generalLogin', 'lt': current.lt, 'execution': current.execution}));
    sliderVerified = false;
    if (!response.isRedirect) {
      final document = html.parse(response.body);
      final messages = document.querySelectorAll('#showErrorTip, .form-error').map((e) => e.text.trim()).where((e) => e.isNotEmpty).toList();
      throw FormatException(messages.isEmpty ? '统一认证未接受本次登录，请重新输入账号、密码并验证滑块' : messages.first);
    }
    final portal = await _follow(response, requireTicket: true);
    if (!portal.ok || portal.uri.host != 'my1.ncist.edu.cn' || (await http.cookies(Uri.parse(CampusAuthService.portalOrigin))).isEmpty) {
      throw const FormatException('统一认证完成，门户会话建立失败，请重新登录');
    }
    final identity = _json(await http.request(Uri.parse('${CampusAuthService.portalOrigin}/getLoginUser').replace(queryParameters: {'_t': '${DateTime.now().millisecondsSinceEpoch}'}), headers: {'Accept': _jsonHeaders['Accept']!}));
    final profile = auth.parsePortalIdentity(jsonEncode(identity), username: username);
    final kind = studentKind(identity);
    if (kind == 'unknown') throw const FormatException('当前账号身份尚未支持，请使用学生账号');
    if (kind == 'undergraduate') {
      final uri = Uri.parse('https://jw.cidp.edu.cn/LoginHandler.ashx');
      final business = await _follow(await http.request(uri, headers: {'Referer': '${CampusAuthService.portalOrigin}/'}));
      final cookies = await http.cookies(Uri.parse('https://jw.cidp.edu.cn/'));
      if (!business.ok || business.uri.host != uri.host || !cookies.any((c) => c.name == 'EXESAC.SAAS.SessionId' && c.value.isNotEmpty)) {
        throw const FormatException('校园认证成功，教务会话建立失败，请重新登录');
      }
    } else {
      final uri = Uri.parse('${CampusAuthService.authOrigin}/authserver/login').replace(queryParameters: {'service': 'https://gms.ncist.edu.cn/'});
      final business = await _follow(await http.request(uri, headers: {'Referer': '${CampusAuthService.portalOrigin}/'}));
      final names = (await http.cookies(Uri.parse('https://gms.ncist.edu.cn/grzxgl/'))).map((c) => c.name).toSet();
      if (!business.ok || !names.containsAll({'JSESSIONID', 'SSO_LOGIN'})) throw const FormatException('研究生系统会话建立失败，请重新登录');
    }
    if (http is CampusHttp) await (http as CampusHttp).persist(profile.studentNumber, kind);
    await auth.saveProfile(profile);
    return profile;
  }
  static String studentKind(Map<String, dynamic> identity) {
    final data = identity['data'] as Map;
    final category = '${data['categoryName'] ?? data['categoryname'] ?? ''}'.replaceAll(RegExp(r'\s+'), '');
    if ('${data['categoryWid'] ?? data['categoryWId']}' == '2000002' || RegExp('研究生|硕士|博士').hasMatch(category)) return 'graduate';
    if (category.contains('本科')) return 'undergraduate';
    return 'unknown';
  }
  static String formBody(Map<String, String> fields) => fields.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
}
