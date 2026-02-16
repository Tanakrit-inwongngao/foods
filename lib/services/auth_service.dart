import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // ===============================
  // PHP AUTH API
  // ===============================
  static const String _basePath = '/api';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  static String get _host {
    // Android Emulator => เครื่องคอม
    if (Platform.isAndroid) return '10.0.2.2';
    return 'localhost';
  }

  static Uri _uri(String endpoint) => Uri.parse('http://$_host$_basePath$endpoint');

  /// Login กับ PHP: /api/auth/login.php
  /// Server จะส่ง token = session_id()
  static Future<bool> login(String account, String password) async {
    final url = _uri('/auth/login.php');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'account': account, 'password': password}),
    );

    if (res.statusCode != 200) return false;

    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      return false;
    }

    if (decoded is! Map) return false;
    final m = decoded.cast<String, dynamic>();

    // รองรับทั้ง {ok:true, data:{token}} และ {token:...}
    final data = m['data'];
    String token = '';
    Map<String, dynamic> user = {'account': account};

    if (data is Map) {
      final dm = data.cast<String, dynamic>();
      token = (dm['token'] ?? '').toString();
      user = {
        'user_id': dm['user_id'],
        'account': dm['account'],
        'email': dm['email'],
        'role': dm['role'],
      };
    } else {
      token = (m['token'] ?? '').toString();
    }

    if (token.trim().isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    // เก็บคีย์หลัก
    await prefs.setString(_tokenKey, token);
    // เก็บคีย์สำรอง เผื่อหน้าอื่นอ่าน 'token'
    await prefs.setString('token', token);
    await prefs.setString(_userKey, jsonEncode(user));
    return true;
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final t = (prefs.getString(_tokenKey) ?? prefs.getString('token') ?? '').trim();
    return t.isEmpty ? null : t;
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      if (j is Map) return j.cast<String, dynamic>();
    } catch (_) {}
    return null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove('token');
    await prefs.remove(_userKey);
  }
}
