import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/user_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Uint8List? _imageBytes;
  bool _loading = false;
  List<dynamic> _items = [];

  final ImagePicker _picker = ImagePicker();

  // ===============================
  // PICK IMAGE
  // ===============================
  Future<void> _pickImage() async {
    final XFile? file =
    await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _items = [];
    });
  }

  // ===============================
  // ANALYZE
  // ===============================
  Future<void> _analyze() async {
    if (_imageBytes == null) return;

    setState(() => _loading = true);

    try {
      final response = await ApiService.analyze(_imageBytes!);
      final List items = (response['items'] as List?) ?? [];

      setState(() => _items = items);

      // save history (safe)
      for (final item in items) {
        final food = item['food'];
        if (food == null) continue;

        await UserService.addHistory({
          'food_name_th': food['name_th'],
          'food_name_en': food['name_en'],
          'calories': food['nutrition'],
          'protein_g': food['protein_g'],
          'fat_g': food['fat_g'],
          'carbs_g': food['carbs_g'],
          'ingredients': food['ingredients'],
          'image_base64': base64Encode(_imageBytes!),
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ วิเคราะห์ไม่สำเร็จ: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  // ===============================
  // HELPERS
  // ===============================
  List<String> _parseIngredients(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _prettyLabel(String? raw) {
    if (raw == null) return 'ไม่ทราบชนิด';
    switch (raw) {
      case 'fried_egg':
        return '🍳 ไข่ดาว';
      case 'minced_pork':
        return '🥩 หมูสับ';
      case 'rice':
        return '🍚 ข้าว';
      default:
        return raw;
    }
  }

  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      appBar: AppBar(
        title: const Text('🍜 Thai Food Detector'),
        centerTitle: true,
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _items.isEmpty ? _buildImageCard() : _buildImageWithBoxes(),
            const SizedBox(height: 20),
            _buildActionButtons(),
            const SizedBox(height: 20),
            if (_loading) const CircularProgressIndicator(),
            if (_items.isNotEmpty) _buildResultList(),
          ],
        ),
      ),
    );
  }

  // ===============================
  // IMAGE CARD
  // ===============================
  Widget _buildImageCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: 220,
        child: _imageBytes == null
            ? const Center(
          child: Text('ยังไม่ได้เลือกรูป',
              style: TextStyle(color: Colors.grey)),
        )
            : ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(_imageBytes!, fit: BoxFit.cover),
        ),
      ),
    );
  }

  // ===============================
  // IMAGE + BOUNDING BOX
  // ===============================
  Widget _buildImageWithBoxes() {
    if (_imageBytes == null) return const SizedBox();

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const h = 220.0;

        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                ),
              ),

              // boxes
              ..._items.map((item) {
                final bbox = item['bbox'];
                if (bbox == null) return const SizedBox();

                final double? x1 = (bbox['x1'] as num?)?.toDouble();
                final double? y1 = (bbox['y1'] as num?)?.toDouble();
                final double? x2 = (bbox['x2'] as num?)?.toDouble();
                final double? y2 = (bbox['y2'] as num?)?.toDouble();

                if ([x1, y1, x2, y2].contains(null)) {
                  return const SizedBox();
                }

                return Positioned(
                  left: x1! * w,
                  top: y1! * h,
                  width: (x2! - x1) * w,
                  height: (y2! - y1) * h,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.orange, width: 2),
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        color: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        child: Text(
                          _prettyLabel(item['label']?.toString()),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  // ===============================
  // BUTTONS
  // ===============================
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo),
            label: const Text('เลือกรูป'),
            style:
            ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _analyze,
            icon: const Icon(Icons.analytics),
            label: const Text('วิเคราะห์'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
        ),
      ],
    );
  }

  // ===============================
  // RESULT LIST
  // ===============================
  Widget _buildResultList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          '📋 ผลลัพธ์การวิเคราะห์',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        ..._items.map((item) {
          final food = item['food'];
          if (food == null) return const SizedBox();

          final double conf =
              (item['confidence'] as num?)?.toDouble() ?? 0;

          final List<String> allergens =
              (item['allergens'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
                  [];

          final List<String> dangerAllergens =
              (item['danger_allergens'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
                  [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${food['name_th']} (${food['name_en']})',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '🔥 ${food['nutrition']} kcal',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.deepOrange),
                      ),
                      Text(
                          '🎯 Confidence ${(conf * 100).toStringAsFixed(1)}%'),
                    ],
                  ),
                ),
              ),

              _buildIngredientSection(food['ingredients']),
              _buildNutritionSection(food),
              _buildAllergenSection(allergens, dangerAllergens),
            ],
          );
        }).toList(),
      ],
    );
  }

  // ===============================
  // INGREDIENTS
  // ===============================
  Widget _buildIngredientSection(String? raw) {
    final ingredients = _parseIngredients(raw);
    if (ingredients.isEmpty) return const SizedBox();

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: ingredients
              .map((i) => Chip(
            label: Text(i),
            backgroundColor: Colors.green.shade50,
          ))
              .toList(),
        ),
      ),
    );
  }

  // ===============================
  // NUTRITION
  // ===============================
  Widget _buildNutritionSection(Map<String, dynamic> food) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📊 คุณค่าโภชนาการ',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text('🔥 ${food['nutrition']} kcal'),
            Text('🥩 โปรตีน ${food['protein_g']} g'),
            Text('🧈 ไขมัน ${food['fat_g']} g'),
            Text('🍚 คาร์บ ${food['carbs_g']} g'),
          ],
        ),
      ),
    );
  }

  // ===============================
  // ALLERGEN
  // ===============================
  Widget _buildAllergenSection(
      List<String> allergens, List<String> dangerAllergens) {
    if (allergens.isEmpty) return const SizedBox();

    final hasDanger = dangerAllergens.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: hasDanger ? Colors.red.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hasDanger ? '⚠️ สารก่อภูมิแพ้' : 'ℹ️ สารก่อภูมิแพ้',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: hasDanger ? Colors.red : Colors.orange)),
            Text('พบ: ${allergens.join(', ')}'),
            if (hasDanger)
              Text('❌ ผู้ใช้แพ้: ${dangerAllergens.join(', ')}',
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
