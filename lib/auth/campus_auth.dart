import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CampusProfile {
  const CampusProfile({
    required this.studentNumber,
    required this.name,
    this.major,
  });

  final String studentNumber;
  final String name;
  final String? major;

  Map<String, String?> toJson() => {
        'studentNumber': studentNumber,
        'name': name,
        'major': major,
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
      studentNumber: read(const ['studentNumber', 'userName', 'username']),
      name: read(const ['name', 'realName', 'xm']),
      major: major.isEmpty ? null : major,
    );
  }
}

/// Uses the same official CAS → portal redirect route observed in UEM Connect.
///
/// Password encryption and slider/CAPTCHA handling stay in the university's
/// own login page, so this app never receives or stores a password.
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

  Future<void> clearProfile() => _storage.delete(key: _profileKey);

  CampusProfile parsePortalIdentity(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('门户未返回身份信息');
    }

    final root = Map<String, dynamic>.from(decoded);
    final nested = root['data'];
    final payload = nested is Map
        ? Map<String, dynamic>.from(nested)
        : root;
    final profile = CampusProfile.fromJson(payload);
    if (profile.studentNumber.isEmpty) {
      throw const FormatException('未能从门户读取学号');
    }
    return profile;
  }
}
