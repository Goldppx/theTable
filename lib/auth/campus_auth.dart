import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'session_bridge.dart';

class CampusProfile {
  const CampusProfile({
    required this.studentNumber,
    required this.name,
    this.major,
    this.education,
    this.className,
    this.college,
  });

  final String studentNumber;
  final String name;
  final String? major, education, className, college;

  Map<String, String?> toJson() => {
        'studentNumber': studentNumber,
        'name': name,
        'major': major,
        'education': education,
        'className': className,
        'college': college,
      };

  factory CampusProfile.fromJson(Map<String, dynamic> json) {
    String read(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return '';
    }

    final major = read(const ['major', 'zy', '专业']);
    return CampusProfile(
      studentNumber: read(const ['studentNumber', 'studentNo', 'xh', 'userNo', 'loginName', 'username']),
      name: read(const ['name', 'realName', 'userName', 'xm']),
      major: major.isEmpty ? null : major,
      education: read(const ['education', 'educationLevel', '培养层次']),
      className: read(const ['className', 'bjmc', '班级']),
      college: read(const ['college', 'organization', 'deptName', 'departmentName', 'orgName', '学院']),
    );
  }
}

/// Official CAS service route and secure profile storage shared by native login.
class CampusAuthService {
  CampusAuthService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const authOrigin = 'https://auth.ncist.edu.cn';
  static const portalOrigin = 'https://my1.ncist.edu.cn';
  static const _profileKey = 'campus_profile_v1';

  final FlutterSecureStorage _storage;

  Uri get loginUri {
    final portalTarget = Uri.parse('$portalOrigin/xs/index.html#/');
    final portalLogin = Uri(
      scheme: 'https',
      host: 'my1.ncist.edu.cn',
      path: '/login',
      queryParameters: {'portalService': portalTarget.toString()},
    );
    return Uri(
      scheme: 'https',
      host: 'auth.ncist.edu.cn',
      path: '/authserver/login',
      queryParameters: {'service': portalLogin.toString()},
    );
  }

  Future<CampusProfile?> restoreProfile() async {
    final value = await _storage.read(key: _profileKey);
    if (value == null) return null;
    try {
      return CampusProfile.fromJson(
        Map<String, dynamic>.from(jsonDecode(value) as Map),
      );
    } catch (_) {
      await _storage.delete(key: _profileKey);
      return null;
    }
  }

  Future<void> saveProfile(CampusProfile profile) =>
      _storage.write(key: _profileKey, value: jsonEncode(profile.toJson()));

  Future<void> clearProfile() async {
    await CampusSessionBridge.clear();
    await _storage.delete(key: _profileKey);
  }

  CampusProfile parsePortalIdentity(String raw, {String? username}) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('门户未返回身份信息');
    }

    final root = Map<String, dynamic>.from(decoded);
    if ((root['errcode'] ?? '0').toString() != '0') {
      throw const FormatException('门户会话尚未建立，请完成统一认证');
    }
    final nested = root['data'];
    if (nested is! Map) {
      throw const FormatException('门户没有返回有效的用户身份');
    }
    final payload = Map<String, dynamic>.from(nested);
    final department = (payload['deptName'] ?? payload['departmentName'] ?? '').toString();
    final parts = department.split('/').where((part) => part.trim().isNotEmpty).toList();
    if (payload['major'] == null && parts.isNotEmpty) payload['major'] = parts.last.trim();
    if (payload['education'] == null) payload['education'] = payload['categoryName'];
    var profile = CampusProfile.fromJson(payload);
    if (profile.studentNumber.isEmpty && username != null && username.trim().isNotEmpty) {
      profile = CampusProfile.fromJson({...payload, 'studentNumber': username.trim()});
    }
    if (profile.studentNumber.isEmpty || profile.name.isEmpty) {
      throw const FormatException('门户身份缺少学号或姓名，请重新检测登录');
    }
    return profile;
  }
}

