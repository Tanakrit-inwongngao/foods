import 'package:flutter/material.dart';

class ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const ItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final food = item['food'];
    final List<dynamic> dangerAllergens =
        item['danger_allergens'] ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ===============================
            // NAME
            // ===============================
            Text(
              food['name_th'],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            // ===============================
            // NUTRITION
            // ===============================
            Text("🔥 ${food['nutrition']} kcal"),
            Text("🥩 โปรตีน ${food['protein_g']} g"),
            Text("🧈 ไขมัน ${food['fat_g']} g"),
            Text("🍚 คาร์บ ${food['carbs_g']} g"),

            // ===============================
            // ⚠️ ALLERGEN WARNING
            // ===============================
            if (dangerAllergens.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red),
                        SizedBox(width: 6),
                        Text(
                          "อาหารที่คุณแพ้",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: dangerAllergens.map((a) {
                        return Chip(
                          label: Text(a.toString()),
                          backgroundColor: Colors.red.shade100,
                          labelStyle: const TextStyle(color: Colors.red),
                        );
                      }).toList(),
                    )
                  ],
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
