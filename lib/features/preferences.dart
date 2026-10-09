class Shortcut {
  const Shortcut({required this.name, required this.kind, required this.target});
  final String name, kind, target;
  Map<String, String> toJson() => {'name': name, 'kind': kind, 'target': target};
  factory Shortcut.fromJson(Map<String, dynamic> value) {
    final name = '${value['name'] ?? ''}'.trim();
    final kind = '${value['kind'] ?? ''}';
    final target = '${value['target'] ?? ''}'.trim();
    if (name.isEmpty || !['package', 'link'].contains(kind)) throw const FormatException('快捷方式信息不完整');
    if (kind == 'package' && !RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$').hasMatch(target)) throw const FormatException('请输入有效 Android 包名');
    if (kind == 'link') {
      final uri = Uri.tryParse(target);
      if (uri == null || !['https', 'weixin'].contains(uri.scheme) || (uri.scheme == 'https' && uri.host.isEmpty)) throw const FormatException('使用 HTTPS 小程序链接或 weixin:// 链接');
    }
    return Shortcut(name: name, kind: kind, target: target);
  }
  static const defaults = [
    Shortcut(name: '学习通', kind: 'package', target: 'com.chaoxing.mobile'),
    Shortcut(name: '雨课堂', kind: 'link', target: 'https://www.yuketang.cn/'),
    Shortcut(name: '钉钉', kind: 'package', target: 'com.alibaba.android.rimet'),
    Shortcut(name: '企业微信', kind: 'package', target: 'com.tencent.wework'),
  ];
}
class NotificationPreferences {
  const NotificationPreferences({this.nextClass = false, this.morning = false, this.api = false,
    this.leadMinutes = 15, this.morningHour = 7, this.morningMinute = 0, this.apiUrl = '', this.token = '', this.sse = false});
  final bool nextClass, morning, api, sse;
  final int leadMinutes, morningHour, morningMinute;
  final String apiUrl, token;
  Map<String, dynamic> toJson() => {'nextClass': nextClass, 'morning': morning, 'api': api,
    'leadMinutes': leadMinutes, 'morningHour': morningHour, 'morningMinute': morningMinute, 'apiUrl': apiUrl, 'token': token, 'sse': sse};
  factory NotificationPreferences.fromJson(Map<String, dynamic> value) => NotificationPreferences(
    nextClass: value['nextClass'] == true, morning: value['morning'] == true, api: value['api'] == true,
    leadMinutes: (int.tryParse('${value['leadMinutes']}') ?? 15).clamp(1, 120),
    morningHour: (int.tryParse('${value['morningHour']}') ?? 7).clamp(0, 23), morningMinute: (int.tryParse('${value['morningMinute']}') ?? 0).clamp(0, 59),
    apiUrl: '${value['apiUrl'] ?? ''}', token: '${value['token'] ?? ''}', sse: value['sse'] == true);
}
