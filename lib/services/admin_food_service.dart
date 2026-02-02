import 'dart:convert';
import 'package:http/http.dart' as http;

class AdminFoodService {
  static const baseUrl = "http://10.0.2.2/api";

  static Future<bool> createFood({
    required String token,
    required String nameTh,
    required String nameEn,
    required String yoloName,
    required int calories,
    required int protein,
    required int fat,
    required int carbs,
    required String ingredients,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/foods/create_food.php"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "name_th": nameTh,
        "name_en": nameEn,
        "yolo_name": yoloName,
        "nutrition": calories,
        "protein_g": protein,
        "fat_g": fat,
        "carbs_g": carbs,
        "ingredients": ingredients,
      }),
    );

    final json = jsonDecode(res.body);
    return json["ok"] == true;
  }
}
