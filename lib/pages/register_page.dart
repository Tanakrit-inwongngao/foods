import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;


const Color kBrandOrange = Color(0xFFFF9800);

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // ✅ endpoint ของคุณอยู่ที่ /api/auth/register.php
  static const String _basePath = '/api';

  static String get _host {
    if (Platform.isAndroid) return '10.0.2.2';
    return 'localhost';
  }

  static Uri _uri(String endpoint) => Uri.parse('http://$_host$_basePath$endpoint');

  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String _error = '';

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    final username = _usernameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (username.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'กรุณากรอกข้อมูลให้ครบ');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final url = _uri('/auth/register.php');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'username': username, 'email': email, 'password': pass}),
      );

      // ignore: avoid_print
      print('REGISTER URL => $url');
      // ignore: avoid_print
      print('REGISTER STATUS => ${res.statusCode}');
      // ignore: avoid_print
      print('REGISTER BODY => ${res.body}');

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final ok = json['ok'] == true;

      if (!ok) {
        setState(() => _error = (json['message'] ?? json['error'] ?? 'สมัครไม่สำเร็จ').toString());
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('สมัครสมาชิกสำเร็จ!')),
      );
      Navigator.pop(context); // กลับไปหน้า login
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
          title: const Text('สมัครสมาชิก')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'ชื่อผู้ใช้',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'อีเมล',
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
                onPressed: _loading ? null : _onRegister,
                child: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('สมัครสมาชิก'),
              ),
            ),
            const SizedBox(height: 10),
            Text(apiText, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
