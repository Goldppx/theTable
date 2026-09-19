import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// The official teaching system shares the CAS session created during login.
/// This page deliberately renders the school's own schedule data and controls.
class OfficialJwxtPage extends StatefulWidget {
  const OfficialJwxtPage({super.key});

  @override
  State<OfficialJwxtPage> createState() => _OfficialJwxtPageState();
}

class _OfficialJwxtPageState extends State<OfficialJwxtPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse('https://jw.cidp.edu.cn/'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的课表'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _controller.reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
