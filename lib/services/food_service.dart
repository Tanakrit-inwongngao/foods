import 'dart:convert';
import 'package:http/http.dart' as http;

class FoodService {
  /// Flask endpoint สำหรับดึงอาหารทั้งหมด
  static const String baseUrl = "http://10.0.2.2:5000/foods";

  static Future<List<dynamic>> getFoods() async {
    final res = await http.get(Uri.parse(baseUrl));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    } else {
      throw Exception("โหลดข้อมูลอาหารไม่สำเร็จ");
    }
  }
}
