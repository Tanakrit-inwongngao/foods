import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'register_page.dart';
import 'home_page.dart';


const Color kBrandOrange = Color(0xFFFF9800);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ✅ จาก curl ของคุณ endpoint อยู่ที่ /api/auth/...
  static const String _basePath = '/api';

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  static String get _host {
    // Android emulator ต้องใช้ 10.0.2.2
    if (Platform.isAndroid) return '10.0.2.2';
    // iOS simulator / desktop dev
    return 'localhost';
  }

  static Uri _uri(String endpoint) => Uri.parse('http://$_host$_basePath$endpoint');

  final _accountCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String _error = '';

  @override
  void dispose() {
    _accountCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    final account = _accountCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (account.isEmpty || pass.isEmpty) {
      setState(() => _error = 'กรุณากรอกบัญชีและรหัสผ่าน');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final url = _uri('/auth/login.php');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'account': account, 'password': pass}),
      );

      // ช่วย debug ถ้ายังมีปัญหา
      // ignore: avoid_print
      print('LOGIN URL => $url');
      // ignore: avoid_print
      print('LOGIN STATUS => ${res.statusCode}');
      // ignore: avoid_print
      print('LOGIN BODY => ${res.body}');

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final ok = json['ok'] == true;

      if (!ok) {
        setState(() => _error = (json['message'] ?? json['error'] ?? 'เข้าสู่ระบบไม่สำเร็จ').toString());
        return;
      }

      final data = (json['data'] as Map).cast<String, dynamic>();
      final token = (data['token'] ?? '').toString();
      if (token.isEmpty) {
        setState(() => _error = 'ไม่พบ token จากเซิร์ฟเวอร์');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString('token', token); // key สำรอง (บางหน้าจะอ่าน 'token')
      await prefs.setString(
        _userKey,
        jsonEncode({
          'id': data['id'],
          'username': data['username'],
          'email': data['email'],
          'role': data['role'],
        }),
      );

      if (!mounted) return;

      // ไปหน้าตั้งค่าผู้ใช้ (หรือหน้า main ของคุณ)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage(token: token)),

      );
    } catch (_) {
      setState(() => _error = 'เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ (ตรวจสอบ basePath/host และ cleartext http)');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiText = 'API: http://$_host$_basePath';

    return Scaffold(
      appBar: AppBar(
          backgroundColor: kBrandOrange,
          foregroundColor: Colors.white,
          title: const Text('เข้าสู่ระบบ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _accountCtrl,
              decoration: const InputDecoration(
                labelText: 'ชื่อผู้ใช้หรืออีเมล',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'รหัสผ่าน',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_error.isNotEmpty)
              Text(
                _error,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBrandOrange,
                  foregroundColor: Colors.white,
                ),
                onPressed: _loading ? null : _onLogin,
                child: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('เข้าสู่ระบบ'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _loading
                  ? null
                  : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterPage()),
                );
              },
              child: const Text('ยังไม่มีบัญชี? สมัครสมาชิก'),
            ),
            const SizedBox(height: 10),
            Text(apiText, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}