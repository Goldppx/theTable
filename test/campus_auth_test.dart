import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_table/auth/campus_auth.dart';

void main() {
  final auth = CampusAuthService();
  test('CAS service contains portal callback and student target', () {
    final portal = Uri.parse(auth.loginUri.queryParameters['service']!);
    expect(portal.host, 'my1.ncist.edu.cn');
    expect(portal.path, '/login');
    expect(portal.queryParameters['portalService'], 'https://my1.ncist.edu.cn/xs/index.html#/');
  });
  test('portal userName is display name, userNo is student number', () {
    final profile = auth.parsePortalIdentity(jsonEncode({'errcode': 0, 'data': {
      'userNo': '202500000001', 'userName': '测试学生', 'categoryName': '本科生',
      'deptName': '计算机学院/软件工程', 'className': '软件B252',
    }}));
    expect(profile.studentNumber, '202500000001');
    expect(profile.name, '测试学生');
    expect(profile.major, '软件工程');
    expect(profile.education, '本科生');
    expect(profile.college, '计算机学院/软件工程');
  });
  test('missing student number falls back to submitted username', () {
    final profile = auth.parsePortalIdentity(jsonEncode({'errcode': '0', 'data': {
      'userName': '测试研究生', 'categoryName': '硕士研究生',
    }}), username: '202600000001');
    expect(profile.studentNumber, '202600000001');
    expect(profile.name, '测试研究生');
  });
  test('unauthenticated response and malformed identity are rejected', () {
    for (final raw in ['<html>login</html>', '{}', '{"errcode":1,"data":{"userNo":"1","name":"test"}}', '{"data":{"userName":"测试学生"}}']) {
      expect(() => auth.parsePortalIdentity(raw), throwsFormatException);
    }
  });
  test('stored profile remains compatible', () {
    final profile = CampusProfile.fromJson({'studentNumber': '202500000001', 'name': '测试学生'});
    expect(CampusProfile.fromJson(profile.toJson()).studentNumber, profile.studentNumber);
  });
}
