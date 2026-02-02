import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  // ================== KEYS ==================
  static const _keyLoggedIn = 'logged_in';
  static const _keyUserName = 'user_name';
  static const _keyUserEmail = 'user_email';
  static const _keyUserPassword = 'user_password';
  static const _keyUserImage = 'user_image';

  static const _keyHistory = 'detection_history';
  static const _keyUserAllergens = 'user_allergens'; // ⭐ ใหม่

  // ================== AUTH (LOCAL) ==================
  static Future<void> register(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserPassword, password);
  }

  static Future<bool> login(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final storedEmail = prefs.getString(_keyUserEmail);
    final storedPassword = prefs.getString(_keyUserPassword);

    if (storedEmail == email && storedPassword == password) {
      await prefs.setBool(_keyLoggedIn, true);
      return true;
    }
    return false;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, false);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLoggedIn) ?? false;
  }

  // ================== PROFILE ==================
  static Future<void> saveProfile({
    String? name,
    String? email,
    String? base64Image,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) await prefs.setString(_keyUserName, name);
    if (email != null) await prefs.setString(_keyUserEmail, email);
    if (base64Image != null) {
      await prefs.setString(_keyUserImage, base64Image);
    }
  }

  static Future<Map<String, String>> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_keyUserName) ?? '',
      'email': prefs.getString(_keyUserEmail) ?? '',
      'image': prefs.getString(_keyUserImage) ?? '',
    };
  }

  // ================== USER ALLERGENS ==================
  /// บันทึกสารก่อภูมิแพ้ที่ผู้ใช้แพ้
  static Future<void> saveUserAllergens(List<String> allergens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyUserAllergens, allergens);
  }

  /// โหลดสารก่อภูมิแพ้ที่ผู้ใช้แพ้
  static Future<List<String>> loadUserAllergens() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyUserAllergens) ?? [];
  }

  // ================== HISTORY ==================
  /// item ที่ควรส่งเข้า (รองรับ allergen แล้ว):
  /// {
  ///   food_name_th,
  ///   food_name_en,
  ///   calories,
  ///   protein_g,
  ///   fat_g,
  ///   carbs_g,
  ///   ingredients,
  ///   allergens: List<String>,
  ///   danger_allergens: List<String>,
  ///   image_base64
  /// }
  static Future<void> addHistory(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();

    final List<String> list =
        prefs.getStringList(_keyHistory) ?? [];

    final record = {
      ...item,
      'created_at': DateTime.now().toIso8601String(),
    };

    // เพิ่มไว้บนสุด (ล่าสุดก่อน)
    list.insert(0, jsonEncode(record));

    await prefs.setStringList(_keyHistory, list);
  }

  static Future<List<Map<String, dynamic>>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list =
        prefs.getStringList(_keyHistory) ?? [];

    return list
        .map((s) => Map<String, dynamic>.from(jsonDecode(s)))
        .toList();
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHistory);
  }
}
