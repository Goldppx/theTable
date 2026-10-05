import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'campus_auth.dart';
import 'campus_http.dart';
import 'native_auth.dart';
import 'slider_captcha.dart';

class CampusLoginPage extends StatefulWidget {
  const CampusLoginPage({required this.auth, super.key});
  final CampusAuthService auth;
  @override
  State<CampusLoginPage> createState() => _CampusLoginPageState();
}
class _CampusLoginPageState extends State<CampusLoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  late final CampusHttp _http;
  late final NativeCampusAuth _native;
  bool _busy = false, _obscure = true, _prepared = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _http = CampusHttp();
    _native = NativeCampusAuth(auth: widget.auth, http: _http);
  }
  Future<void> _run(Future<void> Function() action) async {
    setState(() { _busy = true; _message = null; });
    try { await action(); }
    on FormatException catch (error) { if (mounted) setState(() => _message = error.message.toString()); }
    on SocketException { if (mounted) setState(() => _message = '连接学校服务失败，请检查网络并重试'); }
    on TimeoutException { if (mounted) setState(() => _message = '学校服务响应超时，请重试'); }
    catch (_) { if (mounted) setState(() => _message = '认证数据读取失败，请重新准备登录'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _submit() => _run(() async {
    final username = _username.text.trim();
    if (username.isEmpty || _password.text.isEmpty) throw const FormatException('请输入校园账号和密码');
    if (!_prepared) {
      await _native.prepare(username);
      if (!mounted) return;
      setState(() => _prepared = true);
      if (_native.captchaRequired) { setState(() => _message = '请拖动下方滑块完成验证'); return; }
    }
    try {
      final profile = await _native.submit(username, _password.text);
      _password.clear();
      if (mounted) Navigator.of(context).pop(profile);
    } catch (_) {
      if (mounted) setState(() => _prepared = false);
      rethrow;
    }
  });
  Future<void> _verify(Map<String, dynamic> payload) => _run(() async {
    if (await _native.verifySlider(payload)) {
      if (mounted) setState(() => _message = '验证通过，点击登录');
    } else {
      await _native.refreshSlider();
      if (mounted) setState(() => _message = '拼图验证未通过，请重新拖动');
    }
  });
  @override
  void dispose() { _username.dispose(); _password.dispose(); _http.close(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('校园账号登录')),
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 24),
        Text('统一身份认证', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('使用校园账号登录，验证通过后连接门户和教务系统。'),
        const SizedBox(height: 28),
        TextField(controller: _username, enabled: !_busy, autofillHints: const [AutofillHints.username],
          textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: '学号 / 校园账号', prefixIcon: Icon(Icons.person_outline)),
          onChanged: (_) => setState(() { _prepared = false; _native.challenge = null; })),
        const SizedBox(height: 16),
        TextField(controller: _password, enabled: !_busy, obscureText: _obscure, autocorrect: false, enableSuggestions: false,
          autofillHints: const [AutofillHints.password], textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: '密码', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(
            tooltip: _obscure ? '显示密码' : '隐藏密码', onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
          onSubmitted: (_) { if (!_busy) _submit(); }),
        if (_native.challenge != null && _prepared) ...[
          const SizedBox(height: 24),
          Center(child: CampusSliderCaptcha(challenge: _native.challenge!, disabled: _busy || _native.sliderVerified, onComplete: _verify)),
          TextButton.icon(onPressed: _busy ? null : () => _run(_native.refreshSlider), icon: const Icon(Icons.refresh), label: const Text('更换验证图片')),
        ],
        if (_message != null) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(_message!, semanticsLabel: _message)),
        const SizedBox(height: 24),
        FilledButton(onPressed: _busy ? null : _submit, child: Padding(padding: const EdgeInsets.all(12), child: Text(_busy ? '正在连接校园系统…' : '登录'))),
        const SizedBox(height: 16),
        const Text('密码仅用于本次认证。登录会话加密保存在本机。', style: TextStyle(fontSize: 12)),
      ]),
    )))),
  );
}
