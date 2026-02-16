import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/history_store.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  Uint8List? _tryDecodeImage(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    try {
      return base64Decode(base64Str);
    } catch (_) {
      return null;
    }
  }

  String _ingredientsToText(dynamic ingredients) {
    if (ingredients == null) return '-';
    if (ingredients is String) return ingredients;
    if (ingredients is List) return ingredients.map((e) => e.toString()).join(', ');
    return ingredients.toString();
  }

  @override
  Widget build(BuildContext context) {
    final history = HistoryStore.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติ'),
      ),
      body: history.isEmpty
          ? const Center(child: Text('ยังไม่มีประวัติ'))
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: history.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = history[index];

          final String title = (item['title'] ??
              item['food_name_th'] ??
              item['food_name_en'] ??
              'รายการอาหาร')
              .toString();

          final calories = item['calories'];
          final confidence = item['confidence'];
          final ingredientsText = _ingredientsToText(item['ingredients']);

          final imgBytes = _tryDecodeImage(
            (item['imageBase64'] ?? item['image_base64'])?.toString(),
          );

          return Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imgBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        imgBytes,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.black12,
                      ),
                      child: const Icon(Icons.image_not_supported),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            if (calories != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_fire_department, size: 16),
                                  const SizedBox(width: 4),
                                  Text('${calories.toString()} kcal'),
                                ],
                              ),
                            if (confidence != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified, size: 16),
                                  const SizedBox(width: 4),
                                  Text('Confidence: ${confidence.toString()}%'),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ส่วนประกอบ: $ingredientsText',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
