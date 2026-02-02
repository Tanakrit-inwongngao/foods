import 'dart:convert';
import 'package:http/http.dart' as http;

class IngredientService {
  static const String baseUrl = 'http://10.0.2.2/api';

  static Future<String> getNameTH(String yoloName) async {
    final res = await http.get(
      Uri.parse('$baseUrl/ingredients/get.php?yolo_name=$yoloName'),
    );

    final json = jsonDecode(res.body);
    return json['name_th'] ?? yoloName;
  }
}
