import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  // ===============================
  // YOLO API (Flask)
  // ===============================
  static const String yoloBaseUrl = 'http://10.0.2.2:5000';

  // ===============================
  // AUTH / DB API (PHP)
  // ===============================
  static const String apiBaseUrl = 'http://10.0.2.2/api';
  static const String authBaseUrl = '$apiBaseUrl/auth';

  // ===============================
  // ANALYZE IMAGE (YOLO + user_id)
  // ===============================
  static Future<Map<String, dynamic>> analyzeImage(
      Uint8List imageBytes, {
        int userId = 0, // ⭐ guest = 0
      }) async {
    try {
      final String base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse('$yoloBaseUrl/process_image'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image': base64Image,
          'user_id': userId, // ⭐ ส่งไป backend
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Server error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('API analyze failed: $e');
    }
  }

  // ===============================
  // ALIAS (ของเดิม ใช้ได้เหมือนเดิม)
  // ===============================
  static Future<Map<String, dynamic>> analyze(
      Uint8List imageBytes, {
        int userId = 0,
      }) {
    return analyzeImage(imageBytes, userId: userId);
  }

  // ===============================
  // LOGIN (PHP)  <-- ตรงกับ login.php ของคุณ
  // ===============================
  static Future<Map<String, dynamic>> login({
    required String account,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$authBaseUrl/login.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'account': account,
        'password': password,
      }),
    );

    final json = jsonDecode(response.body);

    // ⭐ login.php ใช้ success / data
    if (response.statusCode == 200 && json['success'] == true) {
      return json['data']; // {id, username, email, role, token}
    } else {
      throw Exception(json['message'] ?? 'Login failed');
    }
  }

  // ===============================
  // GET ALL ALLERGENS (DB)
  // ===============================
  /// ใช้กับหน้า Profile (ดึงจาก table allergens)
  static Future<List<String>> fetchAllergens() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/allergens/list.php'),
    );

    final json = jsonDecode(response.body);

    if (response.statusCode == 200 && json['success'] == true) {
      return (json['data'] as List)
          .map((e) => e['name'].toString())
          .toList();
    } else {
      throw Exception('Load allergens failed');
    }
  }
}