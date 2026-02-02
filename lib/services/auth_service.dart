import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // ✅ Android Emulator → เครื่องคอม
  static const String _host = 'http://10.0.2.2:5000';

  // ================== LOGIN ==================
  // ❗ ยังไม่มี auth ใน Flask → ปล่อยผ่านชั่วคราว
  static Future<bool> login(String account, String password) async {
    // mock login
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("token", "mock-token");
    return true;
  }

  // ================== REGISTER ==================
  static Future<String?> register({
    required String username,
    required String email,
    required String password,
  }) async {
    // mock register
    return null; // สำเร็จ
  }

  // ================== ME ==================
  static Future<Map<String, dynamic>?> me() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) return null;

    // mock user profile
    return {
      "id": 1,
      "username": "66020789",
      "email": "66020789@up.ac.th",
    };
  }

  // ================== UPDATE PROFILE ==================
  static Future<bool> updateProfile({
    required String username,
    required String email,
    String? password,
    String? imageBase64,
  }) async {
    // ยังไม่รองรับ backend จริง
    return true;
  }

  // ================== LOGOUT ==================
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
  }
}
