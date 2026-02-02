import 'package:flutter/material.dart';

class NutritionPage extends StatelessWidget {
  final List items;
  const NutritionPage({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    double kcal = 0, protein = 0, fat = 0, carbs = 0;

    for (final item in items) {
      final food = item['food'];
      kcal += (food['nutrition'] as num).toDouble();
      protein += (food['protein_g'] as num).toDouble();
      fat += (food['fat_g'] as num).toDouble();
      carbs += (food['carbs_g'] as num).toDouble();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 โภชนาการทั้งจาน'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🍽 สรุปรวมทั้งจาน',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('🔥 พลังงานรวม: ${kcal.toStringAsFixed(0)} kcal'),
                Text('🥩 โปรตีนรวม: ${protein.toStringAsFixed(1)} g'),
                Text('🧈 ไขมันรวม: ${fat.toStringAsFixed(1)} g'),
                Text('🍚 คาร์บรวม: ${carbs.toStringAsFixed(1)} g'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
