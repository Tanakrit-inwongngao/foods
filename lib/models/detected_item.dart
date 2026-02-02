import 'dart:convert';
import 'dart:typed_data';

class DetectedItem {
  final String nameTh;
  final String nameEn;
  final int calories;
  final double confidence;
  final Uint8List imageBytes;
  final List<String> allergens;
  final List<String> dangerAllergens;

  DetectedItem({
    required this.nameTh,
    required this.nameEn,
    required this.calories,
    required this.confidence,
    required this.imageBytes,
    required this.allergens,
    required this.dangerAllergens,
  });

  factory DetectedItem.fromJson(Map<String, dynamic> json) {
    final food = json['food'] ?? {};

    return DetectedItem(
      // ===== ชื่ออาหาร =====
      nameTh: food['name_th']?.toString()
          ?? json['label']?.toString()
          ?? 'ไม่ทราบชื่ออาหาร',

      nameEn: food['name_en']?.toString() ?? 'Unknown',

      // ===== แคลอรี =====
      calories: food['nutrition'] is int
          ? food['nutrition']
          : int.tryParse(food['nutrition']?.toString() ?? '0') ?? 0,

      // ===== confidence =====
      confidence: json['confidence'] is num
          ? (json['confidence'] as num).toDouble()
          : 0.0,

      // ===== image =====
      imageBytes: json['image'] != null
          ? base64Decode(json['image'])
          : Uint8List(0),

      // ===== allergens =====
      allergens: List<String>.from(json['allergens'] ?? []),

      // ===== danger_allergens (ผู้ใช้แพ้จริง) =====
      dangerAllergens: List<String>.from(json['danger_allergens'] ?? []),
    );
  }
}
