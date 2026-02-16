import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'login_page.dart';


const Color kBrandOrange = Color(0xFFFF9800);

class LogoutPage extends StatelessWidget {
  const LogoutPage({super.key});

  // ✅ ต้องให้ตรงกับ LoginPage
  static const String _basePath = '/crud/api';

  static const String _tokenKey = 'auth_token';

  String _host() {
    if (Platform.isAndroid) return '10.0.2.2';
    return 'localhost';
  }

  Uri _apiUri(String endpoint) {
    return Uri.parse('http://${_host()}$_basePath$endpoint');
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey) ?? '';

    // เรียก API logout ก่อน (ถ้า token มี)
    if (token.isNotEmpty) {
      try {
        await http.post(
          _apiUri('/auth/logout.php'),
          headers: {'Authorization': 'Bearer $token'},
        );
      } catch (_) {
        // ถ้าเรียกไม่ได้ก็ยังเคลียร์ local ต่อได้
      }
    }

    // ล้างข้อมูล login ในเครื่อง
    await prefs.clear();

    // กลับไปหน้า Login และล้าง stack
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: kBrandOrange,
          foregroundColor: Colors.white,
          title: const Text("ออกจากระบบ")),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kBrandOrange,
            foregroundColor: Colors.white,
          ),
          onPressed: () => _logout(context),
          child: const Text("ออกจากระบบ"),
        ),
      ),
    );
  }
}
