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

  @override
  void initState() {
    super.initState();
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
            _readPortalIdentity(url);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame && mounted) {
              setState(() => _error = '页面加载失败：' + error.description);
            }
          },
        ),
      )
      ..loadRequest(widget.auth.loginUri);
  }

  Future<void> _readPortalIdentity(String url) async {
    final uri = Uri.tryParse(url);
    if (_readingProfile || uri?.host != 'my1.ncist.edu.cn') return;

    _readingProfile = true;
    await _controller.runJavaScript('''
      fetch('/getLoginUser?_t=' + Date.now(), { credentials: 'include' })
        .then((response) =>
          response.ok ? response.text() : Promise.reject(response.status))
        .then((body) => CampusAuth.postMessage(body))
        .catch(() => CampusAuth.postMessage(''));
    ''');
  }

  Future<void> _complete(String raw) async {
    try {
      final profile = widget.auth.parsePortalIdentity(raw);
      await widget.auth.saveProfile(profile);
      if (mounted) Navigator.of(context).pop(profile);
    } on FormatException {
      if (mounted) {
        setState(() {
          _readingProfile = false;
          _error = '认证尚未完成。请在学校登录页完成账号、密码和验证码验证。';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('校园账号认证')),
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
