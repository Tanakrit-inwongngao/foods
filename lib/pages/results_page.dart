import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/detected_item.dart';

class ResultsPage extends StatelessWidget {
  final List<DetectedItem> items;

  const ResultsPage({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ผลลัพธ์การวิเคราะห์'),
        backgroundColor: Colors.orange,
      ),
      body: items.isEmpty
          ? const Center(
        child: Text(
          'ไม่พบวัตถุอาหารในภาพ',
          style: TextStyle(fontSize: 16),
        ),
      )
          : GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];

          final hasDanger =
              item.dangerAllergens.isNotEmpty;

          return Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: hasDanger
                    ? Colors.red
                    : Colors.green,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== IMAGE =====
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: item.imageBytes.isNotEmpty
                        ? Image.memory(
                      item.imageBytes,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.image_not_supported,
                      ),
                    ),
                  ),
                ),

                // ===== INFO =====
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ชื่ออาหาร
                      Text(
                        item.nameTh,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // calories
                      Text('🔥 ${item.calories} kcal',
                          style:
                          const TextStyle(fontSize: 12)),

                      const SizedBox(height: 4),

                      // confidence
                      Text(
                        '📊 ${(item.confidence * 100).toStringAsFixed(1)}%',
                        style:
                        const TextStyle(fontSize: 11),
                      ),

                      const SizedBox(height: 6),

                      // ===== DANGER ALLERGENS =====
                      if (hasDanger) ...[
                        const Text(
                          '⚠️ ผู้ใช้แพ้',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          item.dangerAllergens.join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                          ),
                        ),
                      ] else if (item.allergens.isNotEmpty) ...[
                        const Text(
                          'ℹ️ สารก่อภูมิแพ้',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          item.allergens.join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                          const TextStyle(fontSize: 11),
                        ),
                      ] else
                        const Text(
                          '✔ ไม่มีสารก่อภูมิแพ้',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
