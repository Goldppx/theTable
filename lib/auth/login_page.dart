import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'campus_auth.dart';

class CampusLoginPage extends StatefulWidget {
  const CampusLoginPage({required this.auth, super.key});

  final CampusAuthService auth;

  @override
  State<CampusLoginPage> createState() => _CampusLoginPageState();
}

class _CampusLoginPageState extends State<CampusLoginPage> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _readingProfile = false;
  String? _error;
  String? _username;
  Timer? _poll;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!_completed) _readPortalIdentity(await _controller.currentUrl() ?? '');
    });
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'CampusAuth',
        onMessageReceived: (message) => _complete(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _loading = false);
            if (Uri.tryParse(url)?.host == 'auth.ncist.edu.cn') {
              _controller.runJavaScript(r''' 
                (() => {
                  if (window.__campusUsernameWatch) return;
                  window.__campusUsernameWatch = true;
                  function report() {
                    const input = document.querySelector('input[name="username"]');
                    if (input && input.value.trim()) CampusAuth.postMessage(JSON.stringify({username: input.value.trim()}));
                  }
                  document.addEventListener('input', report);
                  document.addEventListener('submit', report, true);
                  report();
                })();
              ''');
            }
            _readPortalIdentity(url);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() => _error = '页面加载失败：${error.description}');
            }
          },
        ),
      )
      ..loadRequest(widget.auth.loginUri);
  }

  Future<void> _readPortalIdentity(String url) async {
    final uri = Uri.tryParse(url);
    if (_completed || _readingProfile || uri?.scheme != 'https' || uri?.host != 'my1.ncist.edu.cn') return;

    _readingProfile = true;
    try {
    await _controller.runJavaScript('''
      Promise.race([fetch('/getLoginUser?_t=' + Date.now(), { credentials: 'include', headers: {Accept: 'application/json, text/plain, */*'} }), new Promise((_, reject) => setTimeout(() => reject('timeout'), 8000))])
        .then((response) =>
          response.ok ? response.text() : Promise.reject(response.status))
        .then((body) => CampusAuth.postMessage(body))
        .catch(() => CampusAuth.postMessage(''));
    ''');
    } catch (_) { _readingProfile = false; }
  }

  Future<void> _complete(String raw) async {
    final current = Uri.tryParse(await _controller.currentUrl() ?? '');
    if (_completed || !mounted) return;
    if (current?.scheme != 'https') { _readingProfile = false; return; }
    if (current?.host == 'auth.ncist.edu.cn') {
      try {
        final message = jsonDecode(raw);
        if (message is Map && message['username'] is String) _username = message['username'] as String;
      } catch (_) { /* Ignore non-identity messages. */ }
      return;
    }
    if (current?.host != 'my1.ncist.edu.cn') { _readingProfile = false; return; }
    try {
      final profile = widget.auth.parsePortalIdentity(raw, username: _username);
      await widget.auth.saveProfile(profile);
      _completed = true;
      _poll?.cancel();
      if (mounted) Navigator.of(context).pop(profile);
    } catch (error) {
      if (mounted) {
        setState(() {
          _readingProfile = false;
          _error = error is FormatException ? error.message.toString() : '身份保存失败，请重试。';
        });
      }
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('校园账号认证'), actions: [
        IconButton(tooltip: '检测登录', icon: const Icon(Icons.verified_user_outlined), onPressed: () async {
          _readingProfile = false;
          await _readPortalIdentity(await _controller.currentUrl() ?? '');
        }),
        IconButton(tooltip: '重新加载认证', icon: const Icon(Icons.refresh), onPressed: () {
          _readingProfile = false;
          setState(() => _error = null);
          _controller.loadRequest(widget.auth.loginUri);
        }),
      ]),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: MaterialBanner(
                content: Text(_error!),
                actions: [
                  TextButton(
                    onPressed: () => setState(() => _error = null),
                    child: const Text('知道了'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

